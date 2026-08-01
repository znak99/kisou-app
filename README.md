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
- Server-authoritative future-estimate quota, retry-safe UUID idempotency, and
  an explicit rewarded-ad path after the allowance is exhausted
- Consent-gated, non-personalized inline adaptive AdMob banner at the end of
  the forecast scroll; ads are compile-time disabled by default
- Offline travel plans for up to 20 major-city departures, with JST D-day
  display and optional inexact device-local reminders
- Linked Open-Meteo/CC BY 4.0 attribution beside every weather-data surface,
  with the Ministry of the Environment source shown in context when WBGT appears
- Feedback bottom sheet for a recent date, outside time slots, actual clothing, and comfort feedback
- Feedback submitted/edit state for today
- Menu screen for account linking, profile, sensitivity, location, data reset, theme, privacy, logout, and in-app deletion
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
| Travel-plan storage | sqflite (device-local source of truth) |
| Local reminders | flutter_local_notifications + timezone (`Asia/Tokyo`) |
| Ads and consent | google_mobile_ads 9.x (Google Mobile Ads + UMP) |
| Location | geolocator |
| External URL | url_launcher |
| UI language | Japanese |

Travel plans are never sent to the API. A plan is written to SQLite before any
notification work; notification permission denial or a temporary scheduler
failure leaves a visible retry state without losing the plan. The app
reconciles pending reminders at startup, resume, and JST date rollover. Logout,
account switch, and in-app account deletion cancel this feature's reserved
notification IDs and remove its device-local rows. Android app backup is
disabled; iOS stores the database in a protected Application Support directory
that is explicitly excluded from device/cloud backup.

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
KISOU_ALLOW_EPHEMERAL_SIGNING=1 bash scripts/build_android_release.sh

# iOS production archive (macOS/Xcode signing required)
flutter build ipa --release --flavor prod \
  --dart-define-from-file=config/prod.json
```

Android release builds never fall back to the debug key. Without owner signing
configuration, the build fails before producing an artifact. For local or CI
compilation checks only, explicitly set `KISOU_ALLOW_EPHEMERAL_SIGNING=1`; this
creates a two-day temporary certificate and a clearly named
`build/verification/KISOU-prod-EPHEMERAL-NOT-FOR-STORE.aab`. CI deletes its
temporary AAB after verification.

For a distributable AAB, copy `android/key.properties.example` to the ignored
`android/key.properties`, use an owner-controlled upload keystore outside the
repository, and pin its SHA-256 certificate fingerprint. Alternatively, set an
absolute `KISOU_ANDROID_KEY_PROPERTIES_PATH`, or provide all five
`KISOU_ANDROID_*` signing variables documented by the build script. Then run
`bash scripts/build_android_release.sh`; the signer, production application ID,
production API URL, archive integrity, and absence of development markers are
verified. The pinned fingerprint must also be checked against the upload
certificate registered in Play Console before distribution.

### Available defines

| Define | Default | Purpose |
|--------|---------|---------|
| `APP_ENV` | debug: `development`, release: `production` | Selects the environment |
| `API_BASE_URL` | `http://127.0.0.1:8000` | Development API base URL |
| `API_PRODUCTION_BASE_URL` | *(empty)* | Production API base URL |
| `SHOW_DEV_LOGIN` | `true` | Show the development login buttons |
| `OUTLOOK_SCREENSHOT_FIXTURE` | `false` | Opt in to deterministic Outlook data for store capture |
| `ADS_ENABLED` | `false` | Enable UMP and mobile-ad requests explicitly |
| `ADMOB_ANDROID_APP_ID` | *(empty)* | Live Android App ID for an ads-enabled production build |
| `ADMOB_ANDROID_BANNER_ID` | *(empty)* | Live Android inline-banner unit ID |
| `ADMOB_ANDROID_REWARDED_ID` | *(empty)* | Live Android rewarded unit ID |
| `ADMOB_IOS_APP_ID` | *(empty)* | Live iOS App ID for an ads-enabled production build |
| `ADMOB_IOS_BANNER_ID` | *(empty)* | Live iOS inline-banner unit ID |
| `ADMOB_IOS_REWARDED_ID` | *(empty)* | Live iOS rewarded unit ID |

Resolution rules (`lib/config/api_config.dart`):

- `baseUrl` = `APP_ENV == 'development' ? API_BASE_URL : API_PRODUCTION_BASE_URL`
- release는 `APP_ENV=production`만 허용하며, 앱 시작 시 네트워크 요청 전에
  설정을 검사합니다.
- production URL은 유효한 절대 HTTPS URL이어야 하고 사용자 정보·query·
  fragment를 포함할 수 없습니다. 이 검사는 release에서도 제거되지 않습니다.
- 개발 로그인·개발 연동·스플래시 미리보기·Dio 로그는
  `kDebugMode && APP_ENV == development`일 때만 사용할 수 있습니다.
- 날짜 지정 스토어 캡처 fixture는
  `kDebugMode && OUTLOOK_SCREENSHOT_FIXTURE=true`일 때만 사용할 수 있습니다.
  운영 API와 같은 화면을 캡처하기 위해 production debug에서도 명시적으로
  켤 수 있지만 결과에 설명용 데이터 배지를 표시하며 profile·release에서는
  define 값과 관계없이 비활성화됩니다.
- `ADS_ENABLED`의 기본값은 `false`입니다. 이 경로는 UMP, Mobile Ads SDK,
  배너·리워드 요청을 호출하지 않습니다. development에서 명시적으로 켜면
  Google 공식 샘플 App/광고 단위만 사용합니다. production에서 켜면
  Android·iOS의 App/배너/리워드 ID 6개가 모두 형식에 맞는 실제 ID여야
  하며, 누락·샘플·형식 오류는 런타임과 네이티브 빌드에서 차단됩니다.
- 광고 활성 앱은 매 실행마다 UMP 정보를 갱신하고 필요한 동의 양식을
  표시한 뒤 `canRequestAds`가 참일 때만 G 등급 설정으로 SDK를 한 번
  초기화합니다. 광고 요청은 항상 비개인화 요청이며 정확 위치·닉네임·
  체감 기록·내부 사용자 ID를 전달하지 않습니다.
- iOS는 ATT를 요청하거나 `NSUserTrackingUsageDescription`을 선언하지
  않습니다. Android는 병합 manifest에서 광고 ID 권한을 제거합니다.
  양쪽 플랫폼은 앱 시작 측정을 지연하고, 운영 전환 전에는
  `STORE_RELEASE.md`의 UMP·SSV·app-ads.txt·스토어 신고 절차가 필요합니다.
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

### Reproducing the Outlook store screenshot

Run the production flavor as an explicitly opted-in debug build:

```bash
flutter run --debug --flavor prod \
  --dart-define-from-file=config/prod.json \
  --dart-define=OUTLOOK_SCREENSHOT_FIXTURE=true
```

The fixture preselects Tokyo and JST today + 8 days, starts with three in-memory
lookups, and returns a stable result without calling the API. It neither reads
nor writes the persisted quota. Even when `ADS_ENABLED=true` is supplied for
the isolation test, it makes no UMP, SDK, banner, rewarded, or quota request.
The fixture is unavailable in profile and release builds even if the define is
supplied.

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
flutter test --dart-define-from-file=config/prod.json \
  --dart-define=OUTLOOK_SCREENSHOT_FIXTURE=true \
  --dart-define=ADS_ENABLED=true \
  test/outlook_screenshot_fixture_test.dart
```

GitHub Actions runs analysis, the default, production-config, and opted-in
screenshot-fixture tests, plus a production-config Android App Bundle build on
every `main`/`develop` push and pull request into `main`. CI uses an ephemeral
two-day certificate, verifies the bundle, and deletes it. It never accepts
owner signing material and never publishes a store artifact.

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
