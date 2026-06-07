import { FastifyReply, FastifyRequest } from 'fastify';
import { jwtVerify, SignJWT } from 'jose';
import { config } from '../config';

const JWT_SECRET_KEY = new TextEncoder().encode(config.JWT_SECRET);

declare module 'fastify' {
  interface FastifyRequest {
    userId?: string;
  }
}

export async function signToken(userId: string): Promise<string> {
  return new SignJWT({ userId })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(JWT_SECRET_KEY);
}

export async function verifyToken(token: string): Promise<{ userId: string }> {
  const { payload } = await jwtVerify(token, JWT_SECRET_KEY);
  if (!payload.userId || typeof payload.userId !== 'string') {
    throw new Error('Invalid token payload');
  }
  return { userId: payload.userId };
}

export async function authenticate(request: FastifyRequest, reply: FastifyReply) {
  try {
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      request.log.warn('Authentication failed: Missing or malformed Authorization header');
      return reply.status(401).send({ error: 'Invalid credentials' });
    }

    const token = authHeader.substring(7);
    const { userId } = await verifyToken(token);
    request.userId = userId;
  } catch (err) {
    request.log.warn({ err }, 'Authentication failed: Invalid token');
    return reply.status(401).send({ error: 'Invalid credentials' });
  }
}
