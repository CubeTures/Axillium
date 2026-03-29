---
name: app-ui-layout
description: UI style, layout, and component reference for the Axillium Flutter app. Use this skill whenever working on screen layout, navigation, visual design, or new components. Covers the design language, spacing, typography, and the patterns established across home, chat, check-in, community, notifications, profile, and meetings screens.
---

# Axillium UI Reference

## Design Language

Flat Material You with warm tones. No gradients on content surfaces, no heavy shadows, no card elevation. The UI should feel calm and grounded — this is a recovery app, not a productivity tool.

**Core principles:**
- Surfaces use `surfaceContainerLow` for cards and tiles, `surface` for page backgrounds
- Rounded corners: `BorderRadius.circular(16)` for cards/tiles, `BorderRadius.circular(12)` for fields/icon boxes, `BorderRadius.circular(32)` for pill-shaped inputs
- No `Card` widget — use `Material` with explicit `color`, `borderRadius`, and `clipBehavior: Clip.antiAlias`
- No `ListTile` — build rows manually with `Padding` + `Row`
- No `Divider` as a list separator — use card-based lists with 10px bottom margin per item
- No engagement metrics, follower counts, or gamification chrome
- `withValues(alpha: x)` not `withOpacity` — keeps colour space correct

---

## Typography Scale in Use

| Use | Style | Weight |
|---|---|---|
| Tab-screen hero title | `displaySmall` | w700, height 1.1 |
| Pushed-screen title (in body) | `headlineSmall` | w700 |
| Section labels | `bodySmall` + `letterSpacing: 0.8` + `onSurfaceVariant` + uppercase | w600 |
| Card title | `titleSmall` | w600 |
| Body / description | `bodyMedium` | regular |
| Metadata / captions | `bodySmall`, `onSurfaceVariant` | regular |

---

## Navigation

Bottom nav with four tabs: **Home | Chat | Community | Profile**

Screens pushed from tabs use `Navigator.push` with `MaterialPageRoute` and get a transparent AppBar (for the back button). Tab screens have no AppBar at all.

---

## Two Header Patterns

### Tab screen display header (Home, Community, Notifications, Profile)

No AppBar. `SafeArea(bottom: false)` with the header built directly in the body.

```dart
Scaffold(
  backgroundColor: cs.surface,
  body: SafeArea(
    bottom: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Title', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, height: 1.1)),
                    Text('Subtitle', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: ...),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    ),
  ),
)
```

### Pushed screen header (Meetings, Sponsor List, Members, Check-in History, etc.)

Transparent AppBar provides the back button. Title lives in the body.

```dart
Scaffold(
  backgroundColor: cs.surface,
  appBar: AppBar(
    backgroundColor: Colors.transparent,
    scrolledUnderElevation: 0,
    // title only if needed (e.g. history screens with short content)
  ),
  body: ListView(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).padding.bottom),
    children: [
      Text('Screen Title', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      ...
    ],
  ),
)
```

---

## Section Labels

Use `SectionLabel` from `widgets/section_label.dart`. It uppercases the label and applies the standard section typography. Wrap in `Padding` to control spacing around it.

```dart
import '../widgets/section_label.dart';

// In a ListView:
const SectionLabel(label: 'Upcoming'),
const SizedBox(height: 8),
```

---

## Card Pattern

Every list item is a `Material` card, 10px bottom margin, not a `ListTile`:

```dart
Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Material(
    color: cs.surfaceContainerLow,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(        // only if tappable
      onTap: ...,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(...),
      ),
    ),
  ),
)
```

For featured/accented cards use `cs.primaryContainer` instead of `surfaceContainerLow`.

---

## HomeTile Widget (`widgets/home_card.dart`)

The primary home-screen navigation tile. Icon in a `surfaceContainerHighest` box, title + optional subtitle, trailing chevron.

```dart
HomeTile(
  icon: Icons.today_outlined,
  title: 'Daily Check-in',
  subtitle: 'Not done yet today',
  onTap: ...,
)
```

---

## FloatingActionButton Bottom Padding

Always add explicit bottom padding so the FAB clears the bottom nav bar:

```dart
floatingActionButton: Padding(
  padding: EdgeInsets.only(
    bottom: MediaQuery.of(context).padding.bottom + 20,
  ),
  child: FloatingActionButton(...),
),
```

---

## Home Screen Pattern

No AppBar. `SafeArea` + `ListView` with `padding: EdgeInsets.fromLTRB(20, 32, 20, bottom)`.

Structure:
1. Two-line greeting (`displaySmall` w300 muted / `displaySmall` w700)
2. Subtitle in `bodyMedium` + `onSurfaceVariant`
3. `_CheckInStrip` — full-width tappable row
4. `SectionLabel` rows
5. `HomeTile` rows

---

## Chat Screen Pattern

No AppBar. `extendBodyBehindAppBar: true`. Floating pill header via `Stack` + `Positioned`.

**Floating header pill:**
- `LinearGradient` from `primaryContainer` → `secondaryContainer`
- `BorderRadius.circular(28)`, `elevation: 3`

**Message bubbles:**
- "Me" bubbles: `Color(0xFFFCE4EC)` (hardcoded exception), text `Color(0xFF4A1428)`, right-aligned
- "Other" bubbles: `secondaryContainer`, text `onSecondaryContainer`, left-aligned
- System messages: centred, `surfaceContainerHighest` pill
- Max bubble width: 72% of screen width

**Input bar:** `surfaceContainerHighest` pill, `circular(32)`

---

## Form / Sheet Pattern (check-in, schedule meeting)

- Transparent AppBar or modal bottom sheet with drag handle
- Section containers: `surfaceContainerLow`, `circular(16)`, `padding: all(20)`, spaced 10px apart
- Section heading: `titleMedium` w600
- Submit: full-width `FilledButton`, `circular(14)`, height 52

---

## Colour Notes

- Never hardcode `Colors.white` or `Colors.black` — use `colorScheme` tokens
- "Me" chat bubble is the one intentional hardcoded colour: `0xFFFCE4EC` / `0xFF4A1428`
- `withValues(alpha: x)` not `withOpacity`

---

## What Not to Do

- No `Card()` — use `Material` with explicit decoration
- No `ListTile` — build rows manually
- No `Divider` as a list separator — use card-per-item with bottom margin
- No engagement widgets: likes, follower counts, streaks displayed as achievements
- No infinite scroll — use pagination
- No `withOpacity` — use `withValues(alpha: x)`
- No `Colors.white` backgrounds — use `cs.surface`
