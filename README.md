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
# Android emulator development (separate .dev installation)
flutter run --flavor dev \
  --dart-define-from-file=config/dev.json \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS development
flutter run --flavor dev --dart-define-from-file=config/dev.json

# Android production-config verification App Bundle
bash scripts/build_android_release.sh

# iOS production archive (macOS/Xcode signing required)
flutter build ipa --release --flavor prod \
  --dart-define-from-file=config/prod.json
```

The current Android release build is still signed with the debug key so local
and CI verification can run. It is not a store-uploadable artifact; the
`실기기·출시 준비` work must configure the owner-controlled upload key before
distribution.

### Available defines

| Define | Default | Purpose |
|--------|---------|---------|
| `APP_ENV` | debug: `development`, release: `production` | Selects the environment |
| `API_BASE_URL` | `http://127.0.0.1:8000` | Development API base URL |
| `API_PRODUCTION_BASE_URL` | *(empty)* | Production API base URL |
| `SHOW_DEV_LOGIN` | `true` | Show the development login buttons |

Resolution rules (`lib/config/api_config.dart`):

- `baseUrl` = `APP_ENV == 'development' ? API_BASE_URL : API_PRODUCTION_BASE_URL`
- release는 `APP_ENV=production`만 허용하며, 앱 시작 시 네트워크 요청 전에
  설정을 검사합니다.
- production URL은 유효한 절대 HTTPS URL이어야 하고 사용자 정보·query·
  fragment를 포함할 수 없습니다. 이 검사는 release에서도 제거되지 않습니다.
- 개발 로그인·개발 연동·스플래시 미리보기·Dio 로그는
  `kDebugMode && APP_ENV == development`일 때만 사용할 수 있습니다.
- Android와 iOS의 `dev` flavor는 `.dev` 앱 식별자와 `KISOU Dev`
  표시명을 사용해 운영 앱의 보안 저장소와 로컬 설정을 공유하지 않습니다.
- iOS의 로컬 네트워크 권한과 HTTP 허용은 dev Info.plist에만 있으며,
  prod Info.plist에는 포함되지 않습니다. 운영 Keychain service 이름은
  기존 사용자 세션을 유지하고 dev는 별도 service를 사용합니다. 공용
  Keychain access group은 사용하지 않습니다.
- Android와 iOS는 시작 시 `dev ↔ development`, `prod ↔ production`
  조합을 강제하며 flavor와 `APP_ENV`가 다르거나 flavor가 없으면
  네트워크·저장소 초기화 전에 즉시 중단합니다.
- release는 production만 허용하므로 배포 archive는 `prod` scheme만
  지원합니다. dev scheme은 archive 대상에서 제외합니다.

### Testing on a physical device over the LAN

The Mac's LAN IP changes per network, so keep it out of git — copy the dev config and edit the URL (`config/*.local.json` is gitignored):

```bash
cp config/dev.json config/dev.local.json
# edit API_BASE_URL to e.g. http://192.168.0.242:8000  (find it on Ubuntu with: hostname -I)
flutter run --flavor dev --dart-define-from-file=config/dev.local.json
```

## Build And Run

Install dependencies:

```bash
flutter pub get
```

Run on the selected simulator or device:

```bash
# Android
flutter run --flavor dev \
  --dart-define-from-file=config/dev.json \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

## Verification

Static analysis:

```bash
flutter analyze
```

Tests:

```bash
flutter test
flutter test --dart-define-from-file=config/prod.json \
  test/production_config_test.dart
```

GitHub Actions runs analysis, both test modes, and a production-config Android
App Bundle build on every `main`/`develop` push and pull request into `main`.
That CI artifact verifies configuration and compilation only; it is not
published or treated as store-signed.

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
