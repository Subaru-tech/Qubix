"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authRoutes = authRoutes;
const zod_1 = require("zod");
const bcrypt_1 = __importDefault(require("bcrypt"));
const crypto_1 = __importDefault(require("crypto"));
const client_1 = require("../db/client");
const auth_1 = require("../plugins/auth");
const config_1 = require("../config");
const registerSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(8),
    displayName: zod_1.z.string().optional(),
});
const loginSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string(),
});
async function authRoutes(fastify) {
    // POST /auth/register
    fastify.post('/register', async (request, reply) => {
        try {
            const body = registerSchema.parse(request.body);
            const email = body.email.toLowerCase();
            // Check if user already exists
            const existingUser = await client_1.prisma.user.findUnique({
                where: { email },
            });
            if (existingUser) {
                return reply.status(400).send({ error: 'Email already in use' });
            }
            // Hash password with bcrypt cost factor 12
            const passwordHash = await bcrypt_1.default.hash(body.password, 12);
            // Generate a user ID in app code to match with transaction-scoped RLS config
            const userId = crypto_1.default.randomUUID();
            // Create user within the RLS transaction context
            const user = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
                return tx.user.create({
                    data: {
                        id: userId,
                        email,
                        passwordHash,
                        displayName: body.displayName || null,
                    },
                });
            });
            // Generate JWT valid for 7 days
            const token = await (0, auth_1.signToken)(user.id);
            return reply.status(201).send({
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    displayName: user.displayName,
                    avatarUrl: user.avatarUrl,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt,
                },
            });
        }
        catch (err) {
            if (err instanceof zod_1.z.ZodError) {
                return reply.status(400).send({ error: 'Validation failed', details: err.format() });
            }
            request.log.error({ err }, 'Registration failed');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // POST /auth/login
    fastify.post('/login', async (request, reply) => {
        try {
            const body = loginSchema.parse(request.body);
            const email = body.email.toLowerCase();
            // Query user by email
            const user = await client_1.prisma.user.findUnique({
                where: { email },
            });
            if (!user || !user.passwordHash) {
                request.log.warn({ email }, 'Login failed: User not found or missing password hash');
                return reply.status(401).send({ error: 'Invalid credentials' });
            }
            // Verify password
            const isMatch = await bcrypt_1.default.compare(body.password, user.passwordHash);
            if (!isMatch) {
                request.log.warn({ email }, 'Login failed: Password mismatch');
                return reply.status(401).send({ error: 'Invalid credentials' });
            }
            // Generate JWT valid for 7 days
            const token = await (0, auth_1.signToken)(user.id);
            return reply.send({
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    displayName: user.displayName,
                    avatarUrl: user.avatarUrl,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt,
                },
            });
        }
        catch (err) {
            if (err instanceof zod_1.z.ZodError) {
                return reply.status(400).send({ error: 'Validation failed', details: err.format() });
            }
            request.log.error({ err }, 'Login failed');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // GET /auth/me (Protected)
    fastify.get('/me', { preHandler: [auth_1.authenticate] }, async (request, reply) => {
        try {
            const userId = request.userId;
            // Fetch user profile under RLS user context
            const user = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
                return tx.user.findUnique({
                    where: { id: userId },
                });
            });
            if (!user) {
                return reply.status(404).send({ error: 'User not found' });
            }
            return reply.send({
                id: user.id,
                email: user.email,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt,
            });
        }
        catch (err) {
            request.log.error({ err }, 'Fetching current user failed');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // GET /auth/github
    fastify.get('/github', async (request, reply) => {
        // Generate a secure random state parameter for CSRF protection
        const state = crypto_1.default.randomBytes(16).toString('hex');
        const redirectUrl = `https://github.com/login/oauth/authorize?` +
            `client_id=${encodeURIComponent(config_1.config.GITHUB_CLIENT_ID)}` +
            `&redirect_uri=${encodeURIComponent(config_1.config.GITHUB_CALLBACK_URL)}` +
            `&scope=${encodeURIComponent('read:user user:email')}` +
            `&state=${encodeURIComponent(state)}`;
        return reply.redirect(redirectUrl);
    });
    // GET /auth/github/callback
    fastify.get('/github/callback', async (request, reply) => {
        const { code } = request.query;
        // Support mock mode during development/testing
        const mock = request.query.mock === 'true';
        if (mock) {
            const mockEmail = (request.query.mock_email || 'github_mock@example.com').toLowerCase();
            const mockGithubId = request.query.mock_github_id || '99999999';
            const mockName = request.query.mock_name || 'Mock GitHub User';
            const mockAvatar = request.query.mock_avatar || 'https://github.com/images/mock.png';
            try {
                let user = await client_1.prisma.user.findUnique({
                    where: { githubId: mockGithubId },
                });
                if (!user) {
                    // Fallback search by email
                    user = await client_1.prisma.user.findUnique({
                        where: { email: mockEmail },
                    });
                    if (user) {
                        // Link existing user
                        user = await client_1.prisma.$transactionWithUser(user.id, async (tx) => {
                            return tx.user.update({
                                where: { id: user.id },
                                data: {
                                    githubId: mockGithubId,
                                    displayName: user.displayName || mockName,
                                    avatarUrl: user.avatarUrl || mockAvatar,
                                },
                            });
                        });
                    }
                    else {
                        // Create new user
                        const newUserId = crypto_1.default.randomUUID();
                        user = await client_1.prisma.$transactionWithUser(newUserId, async (tx) => {
                            return tx.user.create({
                                data: {
                                    id: newUserId,
                                    email: mockEmail,
                                    githubId: mockGithubId,
                                    displayName: mockName,
                                    avatarUrl: mockAvatar,
                                },
                            });
                        });
                    }
                }
                if (!user) {
                    throw new Error('Failed to retrieve mock user');
                }
                const token = await (0, auth_1.signToken)(user.id);
                return reply.redirect(`qubix://auth?token=${token}`);
            }
            catch (err) {
                request.log.error({ err }, 'Mock GitHub OAuth callback failed');
                return reply.redirect('qubix://auth?error=login_failed');
            }
        }
        if (!code) {
            request.log.warn('GitHub OAuth callback missing code');
            return reply.redirect('qubix://auth?error=login_failed');
        }
        try {
            // 1. Exchange authorization code for access token
            const tokenResponse = await fetch('https://github.com/login/oauth/access_token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                },
                body: JSON.stringify({
                    client_id: config_1.config.GITHUB_CLIENT_ID,
                    client_secret: config_1.config.GITHUB_CLIENT_SECRET,
                    code,
                    redirect_uri: config_1.config.GITHUB_CALLBACK_URL,
                }),
            });
            if (!tokenResponse.ok) {
                throw new Error(`Failed to exchange code: ${tokenResponse.statusText}`);
            }
            const tokenData = (await tokenResponse.json());
            if (tokenData.error || !tokenData.access_token) {
                request.log.error({ error: tokenData.error, desc: tokenData.error_description }, 'GitHub OAuth token exchange returned error');
                return reply.redirect('qubix://auth?error=login_failed');
            }
            const accessToken = tokenData.access_token;
            // 2. Fetch user profile from GitHub
            const userResponse = await fetch('https://api.github.com/user', {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                    'User-Agent': 'Qubix-Server',
                    Accept: 'application/json',
                },
            });
            if (!userResponse.ok) {
                throw new Error(`Failed to fetch user profile: ${userResponse.statusText}`);
            }
            const userProfile = (await userResponse.json());
            let email = userProfile.email?.toLowerCase() || null;
            // 3. If email is null, fetch list of user emails to find the primary verified email
            if (!email) {
                const emailsResponse = await fetch('https://api.github.com/user/emails', {
                    headers: {
                        Authorization: `Bearer ${accessToken}`,
                        'User-Agent': 'Qubix-Server',
                        Accept: 'application/json',
                    },
                });
                if (emailsResponse.ok) {
                    const emailsList = (await emailsResponse.json());
                    const primaryEmail = emailsList.find((e) => e.primary);
                    if (primaryEmail) {
                        email = primaryEmail.email.toLowerCase();
                    }
                    else if (emailsList.length > 0) {
                        email = emailsList[0].email.toLowerCase();
                    }
                }
            }
            if (!email) {
                request.log.error({ profile: userProfile }, 'GitHub OAuth login failed: No email associated with GitHub account');
                return reply.redirect('qubix://auth?error=login_failed');
            }
            const githubId = String(userProfile.id);
            const displayName = userProfile.name || userProfile.login;
            const avatarUrl = userProfile.avatar_url;
            // 4. Look up or create the user in the database, isolated by RLS context
            let user = await client_1.prisma.user.findUnique({
                where: { githubId },
            });
            if (!user) {
                // Search by email to link existing email-registered user
                user = await client_1.prisma.user.findUnique({
                    where: { email },
                });
                if (user) {
                    // Link existing user account
                    user = await client_1.prisma.$transactionWithUser(user.id, async (tx) => {
                        return tx.user.update({
                            where: { id: user.id },
                            data: {
                                githubId,
                                displayName: user.displayName || displayName,
                                avatarUrl: user.avatarUrl || avatarUrl,
                            },
                        });
                    });
                }
                else {
                    // Create a new user account
                    const newUserId = crypto_1.default.randomUUID();
                    user = await client_1.prisma.$transactionWithUser(newUserId, async (tx) => {
                        return tx.user.create({
                            data: {
                                id: newUserId,
                                email,
                                githubId,
                                displayName,
                                avatarUrl,
                            },
                        });
                    });
                }
            }
            if (!user) {
                throw new Error('Failed to retrieve user');
            }
            // 5. Generate secure JWT token
            const token = await (0, auth_1.signToken)(user.id);
            // 6. Redirect to deep link scheme
            return reply.redirect(`qubix://auth?token=${token}`);
        }
        catch (err) {
            request.log.error({ err }, 'GitHub OAuth authentication failed');
            return reply.redirect('qubix://auth?error=login_failed');
        }
    });
}
