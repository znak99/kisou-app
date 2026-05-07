# kisou-app

Flutter mobile app for **キソウ**, a weather-based personalized clothing recommendation app for Japan.

キソウ is not a fashion coordination app. It does not recommend colors, brands, or styles. It answers one practical question: how thick should the user dress today?

## Current Features

- Apple / Google login flow, plus development login buttons for local testing
- First-launch keychain cleanup for iOS reinstall behavior
- New-user onboarding: nickname, gender, cold/heat sensitivity, location, and departure/return time
- Home screen with three API-provided recommendation combinations
- Weather comparison for today, yesterday, and two days ago
- Feedback bottom sheet for actual clothing and comfort feedback
- Feedback submitted/edit state for today
- Settings screen for nickname, gender, sensitivity, time, location, privacy policy, logout, and account deletion
- JWT storage with `flutter_secure_storage`
- 401 session-expiration handling back to the login screen
- Network, timeout, and missing-location error messages with retry or settings actions

## Tech Stack

| Area | Technology |
| --- | --- |
| Framework | Flutter 3.x |
| Language | Dart |
| State management | Riverpod |
| HTTP client | dio |
| Auth | Apple Sign-In / Google Sign-In |
| Token storage | flutter_secure_storage |
| Local flags | shared_preferences |
| Location | geolocator |
| External URL | url_launcher |
| UI language | Japanese |

## API Server

The app expects `kisou-api` to be running separately. Business logic, recommendation calculation, weather fetching, offset updates, and account deletion are handled by the API.

Default development URL:

```text
http://127.0.0.1:8000
```

Override it at run time:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:8000
```

Development login buttons are shown by default in development builds. To hide them:

```bash
flutter run --dart-define=SHOW_DEV_LOGIN=false
```

## Build And Run

Install dependencies:

```bash
flutter pub get
```

Run on the selected simulator or device:

```bash
flutter run
```

Run with an explicit API server:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
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
    home/
    onboarding/
    settings/
  services/
  utils/
  widgets/
```

Key docs:

- [docs/DESIGN.md](docs/DESIGN.md)
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md)
- [docs/TASK_ORDER.md](docs/TASK_ORDER.md)
