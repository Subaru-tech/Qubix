"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpenAIConnector = void 0;
const base_1 = require("./base");
const errors_1 = require("./errors");
function parseConfig(config) {
    const apiKey = config.apiKey;
    if (!apiKey || typeof apiKey !== 'string' || apiKey.trim() === '') {
        throw new errors_1.AuthenticationError('Connector config invalid: missing required field "apiKey"');
    }
    return {
        apiKey,
        model: config.model || 'gpt-4-turbo',
        baseUrl: config.baseUrl || 'https://api.openai.com/v1',
        temperature: typeof config.temperature === 'number' ? config.temperature : 0.7,
        maxTokens: typeof config.maxTokens === 'number' ? config.maxTokens : 2000,
    };
}
function handleErrorStatus(status, headers) {
    if (status === 401) {
        throw new errors_1.AuthenticationError();
    }
    if (status === 429) {
        const retryAfter = headers.get('retry-after');
        throw new errors_1.RateLimitError(retryAfter ? parseInt(retryAfter, 10) : null);
    }
    throw new errors_1.ProviderError(status, `OpenAI service error (HTTP ${status})`);
}
class OpenAIConnector extends base_1.BaseConnector {
    /**
     * Validates the API key by making a lightweight GET /models request.
     */
    async validateConfig(config) {
        const parsed = parseConfig(config);
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 10_000);
        try {
            const res = await fetch(`${parsed.baseUrl}/models`, {
                method: 'GET',
                headers: {
                    Authorization: `Bearer ${parsed.apiKey}`,
                },
                signal: controller.signal,
            });
            if (!res.ok) {
                handleErrorStatus(res.status, res.headers);
            }
            return true;
        }
        catch (err) {
            if (err instanceof errors_1.AuthenticationError || err instanceof errors_1.RateLimitError || err instanceof errors_1.ProviderError) {
                throw err;
            }
            throw new errors_1.ProviderError(0, `OpenAI validation failed: ${err.message}`);
        }
        finally {
            clearTimeout(timeout);
        }
    }
    /**
     * Sends a chat completion request with streaming enabled.
     * Parses SSE chunks and yields delta.content strings.
     */
    async *sendMessage(params) {
        const parsed = parseConfig(params.config);
        // Prepend system prompt if present in config
        const messages = [...params.messages];
        const systemPrompt = params.config.systemPrompt;
        if (systemPrompt && messages[0]?.role !== 'system') {
            messages.unshift({ role: 'system', content: systemPrompt });
        }
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 60_000);
        try {
            const res = await fetch(`${parsed.baseUrl}/chat/completions`, {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${parsed.apiKey}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    model: parsed.model,
                    messages: messages.slice(-20), // Last 20 messages for context window
                    stream: true,
                    temperature: parsed.temperature,
                    max_tokens: parsed.maxTokens,
                }),
                signal: controller.signal,
            });
            if (!res.ok) {
                handleErrorStatus(res.status, res.headers);
            }
            if (!res.body) {
                throw new errors_1.ProviderError(0, 'OpenAI returned empty response body');
            }
            const reader = res.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';
            while (true) {
                const { done, value } = await reader.read();
                if (done)
                    break;
                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');
                // Keep the last potentially incomplete line in the buffer
                buffer = lines.pop() || '';
                for (const line of lines) {
                    const trimmed = line.trim();
                    if (!trimmed || trimmed.startsWith(':'))
                        continue; // Skip empty lines and comments
                    if (trimmed === 'data: [DONE]') {
                        return; // Stream complete
                    }
                    if (trimmed.startsWith('data: ')) {
                        try {
                            const json = JSON.parse(trimmed.slice(6));
                            const content = json.choices?.[0]?.delta?.content;
                            if (content) {
                                yield content;
                            }
                        }
                        catch {
                            // Skip malformed JSON chunks
                        }
                    }
                }
            }
        }
        catch (err) {
            if (err instanceof errors_1.AuthenticationError || err instanceof errors_1.RateLimitError || err instanceof errors_1.ProviderError) {
                throw err;
            }
            if (err.name === 'AbortError') {
                throw new errors_1.ProviderError(0, 'OpenAI request timed out after 60s');
            }
            throw new errors_1.ProviderError(0, `OpenAI streaming failed: ${err.message}`);
        }
        finally {
            clearTimeout(timeout);
        }
    }
    /**
     * Checks if the OpenAI service is reachable with the given config.
     */
    async getStatus(config) {
        try {
            await this.validateConfig(config);
            return 'online';
        }
        catch (err) {
            if (err instanceof errors_1.AuthenticationError)
                return 'error';
            return 'offline';
        }
    }
}
exports.OpenAIConnector = OpenAIConnector;
