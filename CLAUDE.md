# Project Overview

An addiction recovery app whose explicit goal is to move users from anonymous online interaction toward real-world community. The app is not meant to retain users — it is a funnel to in-person connection. Every feature should reduce dependency on the app, not increase it.

# Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Go with Gin
- **Database**: SQLite with Gorm
- **API**: REST, endpoints under `/api/`, JSON bodies, standard HTTP status codes

# Project Structure

```
/
├── frontend/
│   └── lib/
│       ├── models/        # Dart data models mirroring backend structs
│       ├── screens/       # One file per screen
│       ├── widgets/       # Shared UI components
│       └── services/      # All API calls to Go backend
├── backend/
│   ├── main.go
│   ├── handlers/          # Route handler functions
│   ├── models/            # Gorm models
│   ├── routes/            # Route registration
│   └── db/                # DB init and migrations
```

# Roles

Users progress through roles. Each unlocks new capabilities and responsibilities. Role transitions are suggested by the app at thresholds — never forced. Everyone is an apprentice always -- additional roles just add some extra responsibilities along the recovery journey.

| Role | Description |
|---|---|
| **Anonymous** | Read-only access to the forum. Alias username only. No profile visible to others. No data stored in main database, only local. |
| **Apprentice** | Create profile with password, stored in database. Can post in the forum. Can be paired with a sponsor (opt-in). Has access to the crisis button. Completes daily check-ins. |
| **Sponsor** | A graduate who has opted in to guide apprentices. Visible to their group members only. Manages their own availability. |
| **Leader** | Started or was elected to lead a small group. Moderates the group, sets check-in schedules, assigns light responsibilities to members. |
| **Influencer** | An established sponsor or leader who publishes long-form public stories. Visible outside the group to anonymous users. Not a social media presence — no follower counts, no engagement metrics. |
| **Graduated** | Marked by the user themselves. Can remain in the app as a sponsor or silently exit. |

Sponsors and leaders are assumed to be trying their best and can still struggle. They are not held to a standard of perfection.

# Graduation System

The app tracks progress passively and suggests next steps — it does not gamify or pressure.

Tracked signals:
- Forum posts made
- Sponsor connection established
- Crisis button uses and outcomes
- Call/check-in history with sponsor
- Small group attendance
- Check-in streak (with relapse tolerance — see below)

# Relapse Handling

Relapse is loggable without resetting all progress. A relapse log entry pauses streak counting but preserves role, sponsor connection, group membership, and history. Recovery is not linear and the app must reflect that. A relapsed sponsor should be able to step back from their role temporarily without losing their account or history.

# Forum

- Posts separated by addiction type
- No likes, no follower counts, no share counts
- "Me too" reaction only — acknowledges without creating engagement loops
- Anonymous users can read but not post
- No infinite scroll — paginated, reverse chronological

# Small Groups

- 8-16 members, same addiction type, same approximate stage
- Led by a Leader role
- Voice/video check-ins on schedule denoted by leader (default weekly)
- Text chat check-ins and group discussions (async) on schedule denoted by leader (default semi-daily)
- Members are visible to each other by alias until mutual trust levels advance
- Leaders can assign light responsibilities (e.g., "open next week's check-in")

# Sponsor System

- Apprentices are matched with an available sponsor based on addiction type and group
- Sponsor availability is self-managed — sponsors can mark themselves unavailable
- Communication follows the anonymity ladder strictly
- Sponsors see only what trust level permits

# Crisis Button

Available to Apprentices and above. On trigger:

1. Immediately notifies the user's sponsor if available
2. If sponsor is marked unavailable or does not respond within a short timeout, notifies other sponsors in the same group who know the user
3. If no group sponsor responds, surfaces a static list of crisis resources (hotlines, text lines)

The crisis button is not a replacement for emergency services. If the user indicates immediate physical danger, the app surfaces emergency service information first.

# Influencer / Public Stories

Established sponsors and leaders can opt in to publish long-form personal stories. These are:
- Visible to anonymous users (the widest audience, lowest trust level)
- Styled as long-form narrative — no headlines optimised for clicks, no engagement metrics shown to the author
- Moderated by leaders before publication
- Not attributed beyond a first name and addiction type unless the author opts in to more

The purpose is stigma reduction and proof that recovery is possible — not building an audience.

# Do Not

- Suggest Firebase or any third-party backend service
- Add social media features: followers, likes, share counts, trending sections
- Store real phone numbers before trust level 4
- Skip error handling on any API call
- Add features that increase time spent in the app
- Use infinite scroll or engagement-optimised notifications
- Reset all progress on relapse
- Expose user data across trust levels without explicit mutual opt-in
- Design the crisis button as the primary safety net — always pair it with a professional resource fallback

# API Conventions

- All endpoints under `/api/`
- JSON request and response bodies
- Return semantically correct HTTP status codes
- Never return data above the requesting user's trust level with the target user

# Flutter Conventions

- All API calls in `lib/services/` — screens never call HTTP directly
- One file per screen in `lib/screens/`
- Shared UI in `lib/widgets/`
- Models in `lib/models/` — mirror backend structs exactly