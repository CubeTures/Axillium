# Project Overview

An addiction recovery app with the goal of moving users from anonymous online interaction to in-person community. The app is not meant to retain users — it is a funnel to real-world connection.

# Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Go with Gin
- **Database**: SQLite with Gorm
- **API**: REST

# Project Structure

```
/
├── frontend/        # Flutter app
│   ├── lib/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── services/  # API calls to Go backend
├── backend/         # Go + Gin
│   ├── main.go
│   ├── handlers/
│   ├── models/
│   ├── routes/
│   └── db/
```

# Core Features

- **Graduation system**: tracks user progress from forum → sponsor connection → small group → in-person meeting
- **Sponsor system**: users connect to a sponsor with an anonymity ladder (text only → first name → in-app voice → phone → in-person)
- **Forum**: anonymous posts separated by addiction type, no likes or follower counts, "me too" reactions only
- **Personal/success stories**: substack-style long-form posts
- **Small groups**: 4-8 people, same addiction type, weekly voice/video check-ins
- **Crisis button**: immediately notifies sponsor

# Anonymity Ladder (trust levels)

1. Text only, alias username
2. First name — mutual opt-in
3. Phone number exchange — mutual opt-in
4. In-person meeting suggestion — after milestone hit

Neither side can skip a level without mutual agreement.

# Graduation System Logic

- App tracks: forum posts, sponsor connection, call history, check-in streaks
- At thresholds, app suggests next step explicitly
- User marks themselves as attending in-person meetings → "graduate" status
- Graduates can become sponsors or forum mentors

# General Rules

- Do not add features that increase time spent on the app
- No infinite scroll, no vanity metrics, no engagement notifications
- Relapse should be loggable without resetting all progress — recovery is not linear
- Always include a crisis fallback if sponsor is unreachable
- Keep the anonymity model intact — never expose user data between trust levels without mutual opt-in

# API Conventions

- REST endpoints under `/api/v1/`
- JSON request and response bodies
- Return appropriate HTTP status codes
- Auth via JWT

# Flutter Conventions

- API calls go in `lib/services/`
- One file per screen in `lib/screens/`
- Shared UI components in `lib/widgets/`

# Do Not

- Suggest Firebase or third-party backend services
- Add social media style features (followers, likes, share counts)
- Store real phone numbers before trust level 4 is reached
- Skip error handling on API calls

