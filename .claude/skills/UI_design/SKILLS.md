---
name: app-ui-layout
description: UI style, layout, and component reference for the Axillium Flutter app. Use this skill whenever working on screen layout, navigation, visual design, or new components. Covers the design language, spacing, typography, and the patterns established across home, chat, check-in, and meetings screens.
---

# Axillium UI Reference

## Design Language

Flat Material You with warm tones. No gradients on content surfaces, no heavy shadows, no card elevation. The UI should feel calm and grounded — this is a recovery app, not a productivity tool.

**Core principles:**
- Surfaces use `surfaceContainerLow` for cards and tiles, `surface` for page backgrounds
- Rounded corners: `BorderRadius.circular(16)` for cards/tiles, `BorderRadius.circular(12)` for fields, `BorderRadius.circular(32)` for pill-shaped inputs
- No `Card` widget — use `Material` with explicit `color` and `borderRadius` + `clipBehavior: Clip.antiAlias`
- No `ListTile` — build rows manually with `Padding` + `Row` for full control
- AppBars are transparent with `scrolledUnderElevation: 0`; page title comes from the body content, not the AppBar, on content-heavy screens
- No engagement metrics, follower counts, or gamification chrome

---

## Typography Scale in Use

| Use | Style | Weight |
|---|---|---|
| Page greeting / hero title | `displaySmall` | w300 (muted) + w700 (name) on two lines |
| Section labels | `bodySmall` + `letterSpacing: 0.8` + `onSurfaceVariant` | w600 |
| Card title | `titleSmall` or `titleMedium` | w600 |
| Body / description | `bodyMedium` | regular |
| Metadata / captions | `bodySmall`, `onSurfaceVariant` | regular |

---

## Navigation

Bottom nav with four tabs: **Home | Chat | Community | Profile**

No nested navigators — screens pushed from tabs use `Navigator.push` with `MaterialPageRoute`.

---

## Home Screen Pattern

No AppBar. `SafeArea` + `ListView` with `padding: EdgeInsets.fromLTRB(20, 32, 20, bottom)`.

Structure:
1. Two-line greeting (`displaySmall` w300 muted / `displaySmall` w700)
2. Subtitle in `bodyMedium` + `onSurfaceVariant`
3. `_CheckInStrip` — full-width tappable row, filled primary when not yet done, `surfaceContainerLow` when done
4. Section labels (`bodySmall`, spaced caps, `onSurfaceVariant`)
5. `HomeTile` rows — `surfaceContainerLow`, `circular(16)`, icon box + title + chevron

`HomeTile` anatomy:
- Container: `surfaceContainerLow`, `circular(16)`, `InkWell`
- Icon in a `surfaceContainerHighest` box, `circular(12)`, 20px icon
- Title: `titleMedium` w600, optional subtitle: `bodySmall` `onSurfaceVariant`
- Trailing: `Icons.chevron_right_rounded`, `onSurfaceVariant` at 50% alpha

---

## Chat Screen Pattern

No AppBar. `extendBodyBehindAppBar: true`. Floating pill header positioned with `Stack` + `Positioned`.

**Floating header pill:**
- `LinearGradient` from `primaryContainer` → `secondaryContainer`
- `BorderRadius.circular(28)`, `elevation: 3`
- Left padding `20`, right padding `12`
- Title uses `titleMedium` w600 inside a `PopupMenuButton`

**Message bubbles:**
- "Me" bubbles: `Color(0xFFFCE4EC)` (light pink), text `Color(0xFF4A1428)`, right-aligned, subtle shadow
- "Other" bubbles: `secondaryContainer`, text `onSecondaryContainer`, left-aligned with `CircleAvatar`
- Sender alias: `bodySmall` bold above bubble content, bottom padding 2px
- System messages (check-in notifications): centred, `surfaceContainerHighest` pill, `bodySmall` `onSurfaceVariant`
- Max bubble width: 72% of screen width

**Input bar:**
- `surfaceContainerHighest` pill, `circular(32)`
- `TextField` with no border, horizontal padding 20
- Trailing `FilledButton` circle send button

---

## Form / Sheet Pattern (check-in, schedule meeting)

- Transparent AppBar or modal bottom sheet with drag handle
- Section containers: `surfaceContainerLow`, `circular(16)`, `padding: all(20)`, spaced 10px apart
- Section heading: `titleMedium` w600
- Submit: full-width `FilledButton`, `circular(14)`, height 52

---

## Meetings / List Screen Pattern

Transparent AppBar, bold title (`w700`), refresh icon (`Icons.refresh_outlined`).

`ListView` padding: `fromLTRB(20, 16, 20, bottom)`.

**Meeting card:**
- `Material` with `surfaceContainerLow`, `circular(16)`, `Clip.antiAlias`
- Padding: `fromLTRB(20, 16, 12, 16)`
- Title: `titleSmall` w600
- Info rows: 16px icon + 6px gap + `bodyMedium` text
- Footer: `bodySmall` `onSurfaceVariant`
- Bottom margin: 10px

Section headers (`Upcoming`, `Past`): `bodySmall` w600, `letterSpacing: 0.8`, `onSurfaceVariant`, `padding: only(bottom: 10, top: 8)`.

---

## Colour Notes

- Never hardcode `Colors.white` or `Colors.black` — use `colorScheme` tokens
- "Me" chat bubble is the one intentional hardcoded colour: `0xFFFCE4EC` / `0xFF4A1428`
- Accent tints (e.g. green on check-in complete) use `accentColor` props, not hardcoded palette values in layout code
- `withValues(alpha: x)` not `withOpacity` — keeps colour space correct

---

## What Not to Do

- No `Card()` — use `Material` with explicit decoration
- No `ListTile` — build rows manually
- No engagement widgets: likes, follower counts, streaks displayed as achievements
- No infinite scroll — use pagination
- No `withOpacity` — use `withValues(alpha: x)`
- No `Colors.white` backgrounds — use `cs.surface`
