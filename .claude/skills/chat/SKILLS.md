---
name: flutter-go-group-chat
description: "Use this skill when designing or building a group chat application with a Flutter frontend and a Go backend. Covers architectural decisions, technology choices, real-time communication patterns, state management, and persistence. Trigger on: 'group chat', 'chat app', 'real-time messaging', 'chat rooms', or any request to build messaging features in Flutter with a Go/Gin/GORM backend."
---

# Flutter + Go Group Chat Architecture

## Stack

| Layer | Choices |
|---|---|
| Real-time transport | WebSockets (`gorilla/websocket` on Go, `web_socket_channel` on Flutter) |
| Backend framework | Gin + GORM + SQLite |
| Frontend state | Riverpod (preferred) or Provider |
| Chat UI | `flutter_chat_ui` (saves significant time) or custom `ListView.builder` + `StreamBuilder` |

Avoid SSE — chat requires bidirectional communication.

---

## Core Architectural Decisions

### 1. Hub/Broadcast Pattern (Go)

Use a single Hub goroutine that owns all room/client state. Never share maps across goroutines directly.

- Each connected client gets two goroutines: one for reading, one for writing
- Clients communicate with the Hub via channels (register, unregister, broadcast)
- The Hub fans out messages to all clients in a room
- Slow or dead clients are dropped rather than blocking the broadcast

This pattern keeps concurrency safe and simple without locks.

### 2. Typed Message Envelope

All WebSocket messages — in both directions — use a single JSON envelope:

```
{ "type": "message|join|leave|error", "payload": { ... } }
```

Define the type field as a string enum on both the Go and Flutter sides. Unknown types should be logged and ignored, not cause errors. This makes the protocol extensible without breaking existing clients.

### 3. Message History via REST, Live Updates via WebSocket

- On room entry: fetch history with a REST GET request first, then open the WebSocket
- Doing it in this order prevents missing messages during the connection window
- Paginate history (cursor or offset) — don't load the entire room history at once

### 4. Flutter State Architecture

- `ChatService` owns the `WebSocketChannel` and exposes a broadcast `Stream<Envelope>`
- A Riverpod `StateNotifier` subscribes to that stream and maintains the message list
- The UI widget watches the notifier — no direct WebSocket access in widgets
- Always call `disconnect()` in `dispose()` to avoid leaked connections

---

## Key Design Constraints

**SQLite concurrency**: SQLite allows only one writer at a time. This is fine for low-to-moderate write load. If write throughput becomes a bottleneck, migrate to Postgres. Don't try to work around SQLite's write limits — just switch databases.

**Single server assumption**: This architecture uses in-process fanout via the Hub. If you need to scale to multiple server instances, you'll need a pub/sub layer (e.g. Redis) between them. Don't add this complexity until it's needed.

**Ping/pong keepalive**: WebSocket connections go stale silently. The Go server must send periodic ping frames and close connections that don't respond with a pong. Set read deadlines accordingly. Without this, dead connections accumulate and the Hub leaks memory.

**Buffered send channels**: Each client's outbound channel should be buffered (e.g. 256). If the buffer fills (slow client), drop the client rather than blocking the Hub's broadcast loop.

**`CheckOrigin` in production**: `gorilla/websocket`'s upgrader rejects cross-origin requests by default. During development it's common to bypass this — make sure to restore proper origin validation before deploying.

---

## What to Build First

1. Hub + client skeleton with connect/disconnect
2. Broadcast a hardcoded message to verify fanout works
3. Add the message envelope and parse real payloads
4. Persist messages to SQLite via GORM
5. Add REST history endpoint
6. Build Flutter `ChatService` and wire to `flutter_chat_ui`
7. Add join/leave presence events last — they're non-critical

Don't add auth, rooms, or presence until the basic message loop is proven end-to-end.