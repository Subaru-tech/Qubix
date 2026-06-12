# Qubix Architecture & Technical Documentation

This document provides a high-level overview of the architectural decisions and data flows within the Qubix platform.

## System Architecture Overview

The system is composed of two primary layers:
1. **The Mobile Client (Flutter)**: A native UI for user interaction, state management, and local persistence.
2. **The Server Backend (Node.js)**: The core API for managing agents, routing messages, connecting to third-party APIs (OpenAI, Webhooks), and managing data persistence.

```mermaid
graph TD
    A[Flutter App] -->|REST (JWT Auth)| B[Express API]
    A -->|WebSocket| B
    B -->|Prisma| C[(PostgreSQL)]
    B -->|BullMQ| D[(Redis)]
    D -->|Worker| E[Agent Connectors]
    E --> F{External APIs}
    F -->|OpenAI API| G[OpenAI]
    F -->|HTTP Webhooks| H[External Services]
```

## Backend Architecture

### Core Components
- **Express App**: Serves the RESTful endpoints.
- **WebSocket Server (ws)**: Handles real-time two-way communication for chat streams.
- **BullMQ + Redis**: Used for asynchronous task queueing. When a user sends a message, it gets queued for processing. This prevents the server from blocking and provides a robust retry mechanism.
- **Prisma**: The ORM used to interact with the PostgreSQL database.

### The Agent Connector Pattern
Agents are designed to be plug-and-play. We use a connector factory pattern:
- `OpenAiConnector`: Supports streaming SSE from OpenAI.
- `WebhookConnector`: Sends JSON payloads to external URLs and waits for a response. Includes SSRF protection.
- `EchoConnector`: Simply echoes the message back for local testing.

### Message Flow (Backend)
1. User sends a message via WebSocket or REST.
2. The message is saved to PostgreSQL and enqueued in BullMQ.
3. The BullMQ worker picks up the job, retrieves the appropriate Agent configuration, and instantiates the specific Connector.
4. The Connector processes the prompt and returns a response (or a stream of chunks).
5. The response is saved to the database and streamed back to the client via WebSockets.

## Mobile Client Architecture

### Core Libraries
- **Riverpod**: Used for dependency injection and state management.
- **Dio**: For HTTP requests, configured with global interceptors for auth and error handling.
- **GoRouter**: For deep linking and declarative routing.
- **sqflite**: For local offline caching of messages.

### Offline Queueing
The mobile client handles offline scenarios natively:
1. A user sends a message while offline.
2. The message is stored in the local SQLite database with a `pending` status.
3. The UI reflects this with a specific style (e.g., lower opacity, clock icon).
4. A background sync mechanism (`ConnectivityNotifier`) detects when the device comes back online and flushes the queue to the backend.

### Error Handling & Resilience
- **Global Error Boundaries**: The app is wrapped in an `ErrorBoundary` widget to catch framework-level errors and present a graceful recovery UI.
- **API Interceptors**: 401 Unauthorized errors automatically trigger a logout flow and navigate the user to the login screen. Global errors are handled via a `SnackBarService`.
