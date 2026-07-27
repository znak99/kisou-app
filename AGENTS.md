# AGENTS.md — kisou-app

## Project Overview

This is the Flutter mobile app for **キソウ**, a weather-based personalized clothing recommendation app targeting Japan. The app displays clothing tag combinations as icons based on weather data and the user's personal comfort preferences.

This is NOT a fashion app. We do not handle colors, brands, styles, or outfit coordination. We only answer: "How thick should I dress today?"

## Key Documents

- `docs/DESIGN.md` — Full detailed design (MVP scope, recommendation logic, onboarding, feedback, etc.)
- `docs/CONVENTIONS.md` — Code style, naming, project layout, and patterns

**Read these documents before making changes.**

## Tech Stack

- **Flutter 3.x** / Dart
- **Riverpod** for state management (the only state management solution)
- **dio** for HTTP client
- **flutter_secure_storage** for JWT token storage
- Apple Sign-In + Google Sign-In

## API Backend

This app communicates with `kisou-api` (separate repository). All business logic (recommendation, weather fetching, offset calculation) lives on the server. This app is a **display + input layer**.

### API Endpoints Used

| Method | Path | Used By |
|--------|------|---------|
| POST | /auth/login | Onboarding (login) |
| GET | /users/me | Settings, profile display |
| PUT | /users/me | Onboarding completion, settings changes |
| GET | /home | Home screen (recommendations + weather) |
| POST | /feedback | Feedback submission |
| GET | /feedback/today | Feedback status check |
| DELETE | /users/me | Account deletion |

### API Base URL

- Development: `http://<server-ip>:8000`
- Production: `https://kisou.znak99.cloud`

## Core Concepts

### Clothing Tags

Clothing items are represented as **codes** from the API. The app maps these codes to Japanese display names and icon assets. This mapping is centralized in `lib/constants/clothing_tags.dart`.

| Code (from API) | Japanese | Icon |
|-----------------|----------|------|
| SHORT_SLEEVE | 半袖 | top_short_sleeve.png |
| LONG_PANTS | 長ズボン | bottom_long_pants.png |
| LIGHT_OUTER | 薄手の羽織り | outer_light_outer.png |
| ... | ... | ... |

Full tag list — **Top (6):** SLEEVELESS, SHORT_SLEEVE, THIN_LONG, LONG_SLEEVE, THICK_LONG, KNIT_SWEAT. **Bottom (4):** LONG_PANTS, HALF_PANTS, SHORT_PANTS, SKIRT. **Outer (5 + null):** LIGHT_OUTER, CARDIGAN, JACKET, COAT, PADDING.

### Screens

1. **Onboarding** (6 steps): login → nickname → gender → sensitivity → location → time
2. **Home**: greeting + 3 recommendation combos (icons) + weather comparison (today/yesterday/2 days ago)
3. **Feedback** (bottom sheet): select actual clothing worn → select comfort feeling
4. **Settings**: profile edits, logout, account deletion

### All UI Text in Japanese

Every user-facing string is in Japanese. This includes button labels, error messages, greetings, and instructions.

## Important Rules

- **Riverpod only** — no setState for shared state, no Provider package, no Bloc
- **Clothing codes are never displayed to users** — always convert to Japanese name + icon
- **Keep it simple** — this is not a fashion app; avoid flashy design
- **All data comes from the API** — the app does not calculate recommendations locally
- **16 clothing icons** — simple line-art style, monochrome or minimal color
