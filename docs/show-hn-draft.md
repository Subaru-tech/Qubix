**Title:** Show HN: Qubix – Self-hosted AI agent command center, open source

**Body:**

I built Qubix because I was tired of using Telegram to manage my AI agents.

**The problem:** BotFather usernames are taken. The UI feels wrong for developers. Code blocks look bad. No offline support. Your conversation data lives on Telegram's servers.

**Qubix is different:**
- Self-hosted backend (one `docker compose up`)
- Native Flutter app (iOS + Android)
- Connect OpenAI, Gemini, webhooks, or build your own connector
- Real-time streaming responses
- Offline message queue
- 3 developer themes (Dark Dev, Light, Synthwave)
- Fully open source (MIT)

**Tech stack:** Fastify + PostgreSQL + Redis + BullMQ + Flutter + Riverpod

**Repo:** https://github.com/Subaru-tech/Qubix
**APK:** [link to GitHub releases or direct download]

**Demo:** [30-second screen recording GIF]

**What I'd love feedback on:**
- Connector framework design — how easy is it to add a new provider?
- Self-hosting experience — did `make dev` work first try?
- Mobile UX — does the offline queue feel right?

---

> **Coming in v1.1:** Pipeline Builder — chain agents: "Draft with GPT-4 → Review with Claude → Post to webhook"
