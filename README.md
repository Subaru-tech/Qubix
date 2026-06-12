# Qubix

Qubix is a complete end-to-end platform for building, managing, and interacting with AI Agents via a Flutter mobile application and a robust Node.js backend. 

## Overview

The Qubix platform allows users to configure custom AI agents (OpenAI, Webhook, Echo) and interact with them in real-time. It features a scalable backend using Express, Prisma, BullMQ, Redis, and WebSockets, and a beautiful Flutter frontend.

### Features
- **Mobile Client**: Native Flutter app featuring deep linking, push notifications (FCM), offline queueing, and theme switching.
- **Agent Management**: Create and configure custom AI agents. Replace BotFather with a native UI.
- **Real-time Chat**: WebSocket-powered chat with SSE streaming, message queuing, and background processing.
- **Connectors**:
  - `OpenAI`: Chat completion streaming with standard models.
  - `Webhook`: Generic webhook integration with SSRF protection.
  - `Echo`: Simple echo agent for debugging and testing.
- **Offline Mode**: Local SQLite database for offline chat queues, auto-flushing on reconnection.
- **Security**: Global error boundaries, client-side validation, JWT authentication, and config masking.

## Project Structure

This project is a monorepo containing both the backend and frontend codebases.

```text
qubix/
├── apps/
│   ├── mobile/         # Flutter Mobile Application
│   └── server/         # Node.js Express Backend
├── packages/
│   └── shared/         # Shared schemas and utilities
└── infra/              # Infrastructure and Docker Compose
```

## Getting Started

### Prerequisites
- [Node.js](https://nodejs.org/) (v18+)
- [Flutter](https://flutter.dev/docs/get-started/install) (v3.22+)
- [Docker](https://www.docker.com/) & Docker Compose

### 1. Start the Backend Infrastructure

Navigate to the project root and start the Redis and PostgreSQL databases:

```bash
cd infra
docker-compose up -d
```

### 2. Setup the Backend Server

```bash
cd apps/server
npm install
npm run prisma:generate
npm run prisma:push
npm run dev
```

The server will start on `http://localhost:3000`.

### 3. Run the Flutter Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run
```

When you launch the app, configure the Server URL to your local backend (e.g., `http://10.0.2.2:3000` for Android Emulator or `http://127.0.0.1:3000` for iOS Simulator).

## Documentation

- [Architecture & Design Details](docs/architecture.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## License

This project is proprietary and confidential.
