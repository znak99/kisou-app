# kisou-app

Flutter mobile app for **キソウ**, a weather-based personalized clothing recommendation app for Japan.

キソウ is not a fashion coordination app. It does not recommend colors, brands, or styles. It answers one practical question: how thick should the user dress today?

## Current Features

- Automatic anonymous account creation/restoration without a login gate
- Apple / Google account linking, plus development-only auth controls for local testing
- First-launch keychain cleanup for iOS reinstall behavior
- Four-step onboarding: nickname, gender, cold/heat sensitivity, and location
- Home screen with three API-provided recommendation combinations
- Weather comparison for today, yesterday, and two days ago
- Forecast tab with tomorrow recommendation, D+2 through D+4 weather, and future date/place estimates
- Feedback bottom sheet for a recent date, outside time slots, actual clothing, and comfort feedback
- Feedback submitted/edit state for today
- Menu screen for account linking, profile, sensitivity, location, data reset, theme, privacy, logout, and account deletion
- Access/refresh tokens and the anonymous credential stored with `flutter_secure_storage`
- Automatic refresh-token rotation on 401, then session-expiration handling if renewal fails
- Network, timeout, and missing-location error messages with retry or settings actions

## Tech Stack

| Area | Technology |
| --- | --- |
| Framework | Flutter 3.x |
| Language | Dart |
| State management | Riverpod |
| HTTP client | dio |
| Auth | Anonymous account + Apple/Google linking |
| Token storage | flutter_secure_storage |
| Local flags | shared_preferences |
| Location | geolocator |
| External URL | url_launcher |
| UI language | Japanese |

## API Server

The app expects `kisou-api` to be running separately. Business logic, recommendation calculation, weather fetching, offset updates, and account deletion are handled by the API.

## Environments

Environment values are compile-time `--dart-define`s, so **changing one requires a rebuild**. Ready-made config files live in `config/`:

| File | Environment | API base URL |
|------|-------------|--------------|
| `config/dev.json` | development | `http://127.0.0.1:8000` (simulator / local) |
| `config/prod.json` | production | `https://kisou.znak99.cloud` |

```bash
# development (simulator, local API) — this is also the default with no flags
flutter run --dart-define-from-file=config/dev.json

# production (e.g. release install on a physical device)
flutter run --release --dart-define-from-file=config/prod.json
```

### Available defines

| Define | Default | Purpose |
|--------|---------|---------|
| `APP_ENV` | `development` | Selects the environment |
| `API_BASE_URL` | `http://127.0.0.1:8000` | Development API base URL |
| `API_PRODUCTION_BASE_URL` | *(empty)* | Production API base URL |
| `SHOW_DEV_LOGIN` | `true` | Show the development login buttons |

Resolution rules (`lib/config/api_config.dart`):

- `baseUrl` = `APP_ENV == 'development' ? API_BASE_URL : API_PRODUCTION_BASE_URL`
- `showDevelopmentLogin` = `!kReleaseMode && isDevelopment && SHOW_DEV_LOGIN` — never shown in a release build
- Non-development builds assert that `baseUrl` is `https`

### Testing on a physical device over the LAN

The Mac's LAN IP changes per network, so keep it out of git — copy the dev config and edit the URL (`config/*.local.json` is gitignored):

```bash
cp config/dev.json config/dev.local.json
# edit API_BASE_URL to e.g. http://192.168.0.242:8000  (find it on Ubuntu with: hostname -I)
flutter run --dart-define-from-file=config/dev.local.json
```

## Build And Run

Install dependencies:

```bash
flutter pub get
```

Run on the selected simulator or device:

```bash
flutter run --dart-define-from-file=config/dev.json
```

## Verification

Static analysis:

```bash
flutter analyze
```

Tests:

```bash
flutter test
```

Common manual checks:

- Stop `kisou-api`, open the app, and confirm an error message plus retry button.
- Start `kisou-api`, tap retry, and confirm home data loads.
- Submit feedback and confirm the home screen changes to `フィードバック済み ✓`.
- Change settings, return home, and confirm user/home data refreshes.

## Project Structure

```text
lib/
  app.dart
  main.dart
  config/
  constants/
  models/
  providers/
  screens/
    forecast/
    home/
    onboarding/
    profile/
  services/
  utils/
  widgets/
```

Key docs:

- [docs/DESIGN.md](docs/DESIGN.md)
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md)
