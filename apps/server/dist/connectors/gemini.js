"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeminiConnector = void 0;
const base_1 = require("./base");
const errors_1 = require("./errors");
function parseConfig(config) {
    const apiKey = config.apiKey;
    if (!apiKey || typeof apiKey !== 'string' || apiKey.trim() === '') {
        throw new errors_1.AuthenticationError('Connector config invalid: missing required field "apiKey"');
    }
    return {
        apiKey,
        model: config.model || 'gemini-1.5-flash',
        temperature: typeof config.temperature === 'number' ? config.temperature : 0.7,
        maxTokens: typeof config.maxTokens === 'number' ? config.maxTokens : 2000,
    };
}
function handleErrorStatus(status) {
    if (status === 401 || status === 403) {
        throw new errors_1.AuthenticationError();
    }
    if (status === 429) {
        throw new errors_1.RateLimitError(null);
    }
    throw new errors_1.ProviderError(status, `Gemini service error (HTTP ${status})`);
}
class GeminiConnector extends base_1.BaseConnector {
    baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
    /**
     * Validates the API key by making a lightweight GET request to the models endpoint.
     */
    async validateConfig(config) {
        const parsed = parseConfig(config);
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 10_000);
        try {
            const res = await fetch(`${this.baseUrl}?key=${parsed.apiKey}`, {
                method: 'GET',
                signal: controller.signal,
            });
            if (!res.ok) {
                handleErrorStatus(res.status);
            }
            return true;
        }
        catch (err) {
            if (err instanceof errors_1.AuthenticationError || err instanceof errors_1.RateLimitError || err instanceof errors_1.ProviderError) {
                throw err;
            }
            throw new errors_1.ProviderError(0, `Gemini validation failed: ${err.message}`);
        }
        finally {
            clearTimeout(timeout);
        }
    }
    /**
     * Sends a chat request to Gemini with streaming enabled.
     */
    async *sendMessage(params) {
        const parsed = parseConfig(params.config);
        // Map messages to Gemini format
        const contents = params.messages.map((msg) => ({
            role: msg.role === 'assistant' ? 'model' : 'user', // Gemini uses 'user' and 'model'
            parts: [{ text: msg.content }],
        }));
        // System instruction
        const systemPrompt = params.config.systemPrompt;
        const systemInstruction = systemPrompt
            ? {
                role: 'user',
                parts: [{ text: systemPrompt }],
            }
            : undefined;
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 60_000);
        try {
            const res = await fetch(`${this.baseUrl}/${parsed.model}:streamGenerateContent?alt=sse&key=${parsed.apiKey}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    contents,
                    ...(systemInstruction ? { systemInstruction } : {}),
                    generationConfig: {
                        temperature: parsed.temperature,
                        maxOutputTokens: parsed.maxTokens,
                    },
                }),
                signal: controller.signal,
            });
            if (!res.ok) {
                handleErrorStatus(res.status);
            }
            if (!res.body) {
                throw new errors_1.ProviderError(0, 'Gemini returned empty response body');
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
                        continue;
                    if (trimmed.startsWith('data: ')) {
                        try {
                            const json = JSON.parse(trimmed.slice(6));
                            // Gemini SSE format usually has candidates[0].content.parts[0].text
                            const parts = json?.candidates?.[0]?.content?.parts;
                            if (parts && parts.length > 0) {
                                const text = parts[0].text;
                                if (text) {
                                    yield text;
                                }
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
                throw new errors_1.ProviderError(0, 'Gemini request timed out after 60s');
            }
            throw new errors_1.ProviderError(0, `Gemini streaming failed: ${err.message}`);
        }
        finally {
            clearTimeout(timeout);
        }
    }
    /**
     * Checks if the Gemini service is reachable with the given config.
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
exports.GeminiConnector = GeminiConnector;
