---
name: App-UI-layout
description: This is the general high level design document for app layout on flutter
---

### Onboarding

- First Page
  - Should put a name but also give the user an option to stay anonymous
  - next page should: put in your location and list all the communities
    - Also should give option to start your own community with a particular addiction type
  - Finally a welcome page giving information you are starting as anonymous and tiers

```
Your Journey Ahead:
    → Anonymous: Observe and learn
    → Apprentice: Engage with the community
    → Sponsor: Help others on their journey
    → Leader: Guide and moderate groups
    → Influencer: Inspire through your story
```

## App layout

### Home Page

- greets user
- keeps track of how many days
- has a daily check in for the app
- two tabs to go into community chat and global message board
- progress tracker
  - days-clean
  - check in completed
  - current tier

### Chat

- has page with all community chats
  - basic chat client with multiple users

### Community

- "substack like" with blog post from global users
- has post from various sponsors and Influencers and Leader

### Profile

- top of page has name, profile picture, location, and date joined
- has progression stats
  - days clean
  - Check-Ins
  - Days active

- have bottom section of current tier and percentage bar till next tier

```
Observer & Learner

You can view conversations and blogs. When ready, start engaging to become an Apprentice.
Progress to next tier0%
Current Perks:

    ✓View group chat
    ✓Read community posts
    ✓Complete daily check-ins
    ✓No pressure to engage
```
