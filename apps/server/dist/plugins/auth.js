"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.signToken = signToken;
exports.verifyToken = verifyToken;
exports.authenticate = authenticate;
const jose_1 = require("jose");
const config_1 = require("../config");
const JWT_SECRET_KEY = new TextEncoder().encode(config_1.config.JWT_SECRET);
async function signToken(userId) {
    return new jose_1.SignJWT({ userId })
        .setProtectedHeader({ alg: 'HS256' })
        .setIssuedAt()
        .setExpirationTime('7d')
        .sign(JWT_SECRET_KEY);
}
async function verifyToken(token) {
    const { payload } = await (0, jose_1.jwtVerify)(token, JWT_SECRET_KEY);
    if (!payload.userId || typeof payload.userId !== 'string') {
        throw new Error('Invalid token payload');
    }
    return { userId: payload.userId };
}
async function authenticate(request, reply) {
    try {
        const authHeader = request.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            request.log.warn('Authentication failed: Missing or malformed Authorization header');
            return reply.status(401).send({ error: 'Invalid credentials' });
        }
        const token = authHeader.substring(7);
        const { userId } = await verifyToken(token);
        request.userId = userId;
    }
    catch (err) {
        request.log.warn({ err }, 'Authentication failed: Invalid token');
        return reply.status(401).send({ error: 'Invalid credentials' });
    }
}
