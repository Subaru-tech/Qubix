# Base stage for building
FROM node:20-alpine AS builder

RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

# Copy root workspace and package files
COPY package.json ./
COPY apps/server/package.json ./apps/server/
COPY packages/shared_types/package.json ./packages/shared_types/

# Install dependencies (workspaces will be linked automatically)
RUN npm install

# Copy source code
COPY packages/shared_types ./packages/shared_types
COPY apps/server ./apps/server

# Build workspaces
RUN npx prisma generate --schema=apps/server/prisma/schema.prisma
RUN npm run build --workspace=packages/shared_types
RUN npm run build --workspace=apps/server

# Production stage
FROM node:20-alpine

RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

# Copy packages
COPY package.json ./
COPY apps/server/package.json ./apps/server/
COPY packages/shared_types/package.json ./packages/shared_types/

# Install only production dependencies
RUN npm install --omit=dev

# Copy compiled files from builder
COPY --from=builder /app/packages/shared_types/dist ./packages/shared_types/dist
COPY --from=builder /app/apps/server/dist ./apps/server/dist
COPY --from=builder /app/node_modules/.prisma /app/node_modules/.prisma

EXPOSE 3000

ENV NODE_ENV=production
ENV PORT=3000

CMD ["npm", "run", "start", "--workspace=apps/server"]
