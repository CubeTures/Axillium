---
name: flutter-go-group-chat
description: Architecture and implementation reference for the Axillium chat system. Use this skill when working on group chat, direct messages, weekly prompts, or any messaging feature. Covers the actual patterns in use — REST-based polling, the unified message model, mode switching, and the overlay layout.
---

# Axillium Chat Architecture

## What's Actually Built

The chat system uses **REST polling**, not WebSockets. There is no `flutter_chat_ui` package, no Riverpod, no StreamBuilder. Messages are fetched on demand and state lives in a single `StatefulWidget`.

---

## Backend

| Endpoint | Purpose |
|---|---|
| `GET /api/chat/:group_id` | Fetch group messages |
| `POST /api/chat` | Send a group message |
| `GET /api/dm/:user_a/:user_b` | Fetch DMs between two users |
| `POST /api/dm` | Send a DM |
| `GET /api/weekly-prompt/current` | Get current week's prompt |
| `POST /api/weekly-prompt/respond` | Post a response to the prompt |

All responses are JSON arrays or objects. Standard HTTP status codes. No WebSocket endpoints.

---

## Flutter Layer

### Service Files (`lib/services/`)

- `ChatService` — group messages
- `DmService` — direct messages
- `WeeklyPromptService` — weekly prompt + paginated responses
- `SponsorService` — used to resolve sponsor/apprentice DM targets

Screens never call HTTP directly — all network calls go through these services.

### State (`_ChatScreenState`)

Single `StatefulWidget` owns all chat state. Three modes controlled by `_ChatMode` enum:

```dart
enum _ChatMode { group, weeklyPrompt, dm }
```

Mode switch triggers a load. No persistent connection — fetch on enter, fetch on refresh.

DM targets are resolved once at init: sponsor (if user has one) and apprentices (if user is sponsor/leader).

### `_UnifiedMessage`

A thin view model that normalises group messages, DMs, and prompt responses into a single shape for `_MessageBubble`:

```dart
class _UnifiedMessage {
  final int senderId;
  final String alias;
  final String role;
  final String content;
}
```

---

## Chat Screen Layout

The screen uses `extendBodyBehindAppBar: true` with a `Stack`. No `AppBar` widget.

```
Stack
├── Positioned.fill: message ListView (or loading/empty state)
├── Positioned bottom: solid background block (covers bottom safe area + half the input bar)
├── Positioned bottom: _InputBar or _AnonBanner
├── Positioned top: solid background block (covers status bar + half the pill)
└── Positioned top: floating header pill
```

The `headerOffset` (top padding + 88px) is passed as padding to the `ListView` so content starts below the pill. The `solidBottomHeight` (safe area + 32px) mirrors this at the bottom.

---

## Bubble Colours

| Sender | Background | Text |
|---|---|---|
| Me | `Color(0xFFFCE4EC)` (light pink) | `Color(0xFF4A1428)` |
| Others | `colorScheme.secondaryContainer` | `colorScheme.onSecondaryContainer` |
| System (📋 prefix) | `colorScheme.surfaceContainerHighest` | `colorScheme.onSurfaceVariant` |

System messages are check-in notifications — detected by `content.startsWith('📋')`, displayed as centred pills, not bubbles.

---

## Role Badges

Shown inline next to alias for `leader` (primary colour) and `sponsor` (secondary colour). Rendered as `_RoleBadge` — small pill with 15% alpha background.

---

## Weekly Prompt

Paginated (20 per page). `_scrollController` listener triggers `_loadMorePromptResponses` when user scrolls near the bottom. Responses use the same `_MessageBubble` as group chat.

Prompt card appears above the response list, styled with `colorScheme.primaryContainer`.

Only `_canSetPrompt` roles (`sponsor`, `leader`, `influencer`) see the edit icon. Only `_canRespond` roles can post responses.

---

## Key Constraints

- **No real-time**: Users must pull-to-refresh or re-enter the screen to see new messages. This is intentional for now — the app is not designed to keep users engaged.
- **No message deletion**: Messages are append-only from the client side.
- **DM targets are fixed at load time**: The list of people a user can DM is resolved once in `initState` and doesn't refresh unless the screen is rebuilt.
- **Group ID 0 guard**: If `_groupId == 0`, the screen shows an "join a group" message and makes no network calls.
