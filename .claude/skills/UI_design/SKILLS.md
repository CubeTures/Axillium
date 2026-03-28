---
name: app-ui-layout
description: High-level UI and layout reference for a Flutter addiction recovery app. Use this skill whenever working on screen layout, navigation structure, onboarding flow, user progression/tiers, or any feature placement decisions for this app.
---

# App UI Layout Reference

## Onboarding Flow

**Screen 1 — Identity**

- User enters a name OR opts to remain anonymous

**Screen 2 — Location & Community**

- User sets location
- App lists available communities (filtered by addiction type)
- Option to start a new community (user selects addiction type)

**Screen 3 — Welcome / Tier Intro**

- Explains anonymous start and the tier system:

```
Your Journey Ahead:
    → Anonymous:   Observe and learn
    → Apprentice:  Engage with the community
    → Sponsor:     Help others on their journey
    → Leader:      Guide and moderate groups
    → Influencer:  Inspire through your story
```

---

## Navigation Structure

Bottom nav (or equivalent): **Home | Chat | Community | Profile**

---

## Home

- Personalized greeting
- Days-clean counter
- Daily check-in action
- Two tabs:
  - Community chat (scoped to user's community)
  - Global message board
- Progress tracker widget:
  - Days clean
  - Check-ins completed
  - Current tier

---

## Chat

- List of community chats the user belongs to
- Each chat: basic multi-user chat client

---

## Community

- Global feed, "Substack-style" blog posts
- Posts surfaced from: Sponsors, Influencers, Leaders
- Read-only for Anonymous/Apprentice tiers (implied)

---

## Profile

**Header:** Name, profile picture, location, date joined

**Stats section:**

- Days clean
- Check-ins completed
- Days active

**Tier section:**

- Current tier name + description
- Progress bar to next tier

Example tier display:

```
Observer & Learner
You can view conversations and blogs. When ready, start engaging to become an Apprentice.

Progress to next tier: 0%

Current Perks:
    ✓ View group chat
    ✓ Read community posts
    ✓ Complete daily check-ins
    ✓ No pressure to engage
```
