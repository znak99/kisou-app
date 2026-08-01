# Code Conventions — kisou-app

## Language & Framework

- Flutter 3.x / Dart
- Target platforms: iPhone and Android smartphones in portrait-up orientation
- Landscape and tablet layouts are not supported
- Minimum iOS version: 15.0
- Minimum Android SDK: 24

## State Management

- **Riverpod** is the only state management solution. Do not mix with setState (except for local widget-only state like TextEditingController), Provider, Bloc, or other solutions.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Files | snake_case | `home_screen.dart`, `clothing_icon.dart` |
| Classes | PascalCase | `HomeScreen`, `ClothingTag` |
| Variables / functions | camelCase | `offsetValue`, `getRecommendation()` |
| Constants | lowerCamelCase | `maxOffsetValue` |
| Enum values | camelCase | `ClothingTop.shortSleeve` |
| Providers | camelCase + Provider suffix | `homeProvider`, `userProvider` |

## Project Layout

Use **feature-first** folder structure:

```
lib/
├── main.dart              # Entry point
├── app.dart               # MaterialApp, routing, theme
├── config/
│   ├── api_config.dart    # API base URL, timeouts
│   └── theme.dart         # App theme (colors, text styles)
├── models/                # Immutable data classes
│   ├── user.dart
│   ├── recommendation.dart
│   ├── weather.dart
│   └── feedback.dart
├── providers/             # Riverpod providers
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   ├── home_provider.dart
│   └── feedback_provider.dart
├── services/              # External communication
│   ├── api_client.dart    # dio HTTP client with auth interceptor
│   └── auth_service.dart  # Apple/Google sign-in
├── screens/               # Full-page screens
│   ├── onboarding/
│   │   ├── onboarding_screen.dart
│   │   └── steps/         # Individual onboarding step widgets
│   ├── home/
│   │   └── home_screen.dart
│   ├── analysis/
│   │   └── analysis_screen.dart
│   ├── forecast/
│   │   ├── forecast_screen.dart
│   │   └── outlook_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   └── root_shell.dart
├── widgets/               # Reusable components
│   ├── clothing_icon.dart
│   ├── recommendation_card.dart
│   ├── feedback_sheet.dart
│   └── weather_comparison.dart
├── constants/
│   └── clothing_tags.dart # Tag codes → Japanese names + icon mappings
└── utils/
    └── formatters.dart    # Date, temperature formatters
```

## UI & Language

- All user-facing text is in **Japanese**
- Never hardcode Japanese strings in widget code — use a constants file or localization
- Use the app's nickname greeting format: `○○さん、今日の服装は`

## Clothing Tag System

Clothing tags are always handled as codes internally. Display names and icons are resolved at the UI layer only.

```dart
// constants/clothing_tags.dart
enum ClothingTop {
  sleeveless,   // タンクトップ
  shortSleeve,  // 半袖
  thinLong,     // 薄手の長袖
  longSleeve,   // 長袖
  thickLong,    // 厚手の長袖
  knitSweat,    // ニット・スウェット
}
```

The mapping from API code (`"THIN_LONG"`) → enum → Japanese display name → icon asset is centralized in `constants/clothing_tags.dart`. This is the single source of truth.

## API Communication

- Use `dio` as HTTP client
- Auth interceptor adds `Authorization: Bearer <token>` to all requests
- On a 401, refresh once with the stored rotating refresh token and retry the request; simultaneous 401s share one refresh operation
- Store access/refresh tokens and `device_secret` only in `flutter_secure_storage`
- After account deletion, clear all secure-storage credentials and local
  preferences immediately. Route onboarding and profile through one deletion
  coordinator, keep local-cleanup failure visible after the auth screen
  replaces the caller, and offer retry plus reinstall guidance. After a
  successful social-account link, remove the obsolete anonymous `device_secret`
- Persist account transitions independently from access-token state before
  login, logout, session expiry, or account deletion begins. Check that marker
  before `hasToken`; clear it only after every scoped local cleanup succeeds.
  Before in-app deletion, atomically persist the requested phase and a
  canonical lowercase UUID v4 in one secure-storage value, then send that UUID
  as `Idempotency-Key`. Only a `completed` result from the JWT-free
  `POST /account-deletion/status` receipt endpoint may advance to confirmed
  local cleanup; a DELETE 401, 404 receipt, timeout, 429, 5xx, or malformed
  response is never proof. Keep the UUID embedded in the confirmed marker until
  every account-bound store has been erased.
- A deletion 401 may clear the expired access/refresh tokens, but neither the
  interceptor callback nor `expireSession` may downgrade an active deletion
  marker to account switch. Restore an anonymous session only with the existing
  `device_secret`, without the normal create-new-guest fallback, and always
  reuse the same UUID. If the exact account cannot be restored, preserve local
  data and keep the recovery UI limited to receipt-status retry and an explicit
  local-only abandonment path.
- Offer local-only abandonment only when the exact session cannot be restored
  and the latest receipt lookup is a definitive 404—not on timeout, offline,
  429, 5xx, or malformed data. Warn that server deletion is unconfirmed, server
  data may remain and local erasure is irreversible. Confirmation must send
  no DELETE and claim no server success: atomically replace the deletion marker
  with a dedicated `unconfirmedAccountDiscard` marker, erase every local
  identity credential (including `device_secret`), account preference, travel
  plan/notification, reward operation, and theme, and clear the
  marker last. Do not reuse logout/account-switch cleanup because those preserve
  same-guest restoration. A marker-write failure preserves the deletion UUID
  and local data; later cleanup failure resumes from the dedicated marker after
  restart, and only successful cleanup may start a new anonymous account.
- API base URL is loaded from the matching `config/dev.json` or
  `config/prod.json`; release builds must fail before networking when the
  environment is not production or the production URL is not safe HTTPS
- Gate every development-only UI, network log, preview, and fake-auth method
  on both debug mode and the development environment; hiding a button alone is
  not sufficient
- A deterministic store-capture fixture may run in a production-config debug
  build only when an additional explicit Dart define is true. Keep `kDebugMode`
  in the compile-time gate so the fixture is inert in profile and release,
  bypass the API, keep its quota state in memory, and visibly identify the
  output as illustrative data
- Android and iOS development commands use the `dev` flavor so test
  credentials and preferences cannot overwrite the installed production app
- Keep the native flavor and Dart environment paired (`dev`/`development`,
  `prod`/`production`) on Android and iOS; runtime validation must reject
  missing or mismatched pairs before any network or storage access
- Keep iOS local-network permission and local HTTP transport allowance in the
  dev Info.plist only; a production archive must use the `prod` scheme
- Isolate iOS UserDefaults and Keychain with distinct bundle IDs and private
  default access groups; do not add a dev/prod shared Keychain group
- Never fall back to the Android debug key for a release. Keep owner upload
  keystores outside Git, pin the certificate SHA-256 fingerprint, and verify it
  against Play Console before distribution. Ephemeral signing is only an
  explicit compilation check and its artifact must not be uploaded
- All API responses are parsed into model classes
- Send exact coordinates for the future forecast in the
  `POST /forecast/outlook` JSON body, never in URL query parameters
- Treat `GET /forecast/outlook/quota` and the quota embedded in a successful
  POST response as authoritative. Never recreate the allowance in
  SharedPreferences. Invalidate quota and reward flow on every account
  transition, but preserve the device's UMP choice.
- Give each date/exact-coordinate outlook operation a UUID idempotency key.
  Reuse it for network and timeout retries only; replace it after input change,
  success, or a 409 conflict. A 409/429 must refresh quota and must not erase a
  previous successful result.
- Keep `ADS_ENABLED` false by default. Disabled and screenshot-fixture paths
  must not touch UMP, the Mobile Ads SDK, ad platform channels, or the quota
  API. Development ads use only current official Google sample IDs; an
  ads-enabled production build must reject missing, malformed, or sample App,
  banner, and rewarded IDs.
- Run UMP once per app process in update → required form → eligibility order.
  Recheck eligibility after every UMP error/form, initialize the SDK
  single-flight only when eligible, and retry a transient initialization error
  on resume. Set max content rating G before initialization.
- Every ad request is non-personalized. Never add location, nickname, feeling,
  profile/account identifiers, or SSV `userId`. Reward `customData` may contain
  only the server's one-time 43-character challenge.
- Load a rewarded ad before issuing a challenge. Send the exact loaded ad unit
  with the platform and a canonical client UUID v4 to the server. Persist the
  UUID and its `created_at` after a successful ad load and immediately before
  the API call; a no-fill must leave no never-sent operation. Replay it after
  timeout or process restart until the returned `expires_at`; never issue a
  second UUID while the first outcome is uncertain. If the initial issuance
  response itself is lost and
  `expires_at` is unknown, reuse that UUID for a local 61-minute ceiling (the
  server's 60-minute maximum plus one minute of margin). Persist only
  `issuing|issued|presented`, challenge ID, and timestamps in secure
  storage—never the raw 43-character challenge.
- Show a replayed challenge only while its server status is `pending`.
  `settling` resumes polling, `credited` refreshes authoritative quota without
  another ad, and `consumed|expired` clears the operation. Persist `presented`
  before entering the native ad SDK so a crash cannot show the same challenge
  twice. Set plaintext `customData` only in memory. Production grants credit
  only after server SSV status becomes `credited`; development confirmation is
  allowed only with official test units. Do not auto-show an ad or auto-run an
  outlook.
- Bind reward-store mutations to an account-generation lease. Logout, account
  switch, and deletion first invalidate the provider, close old leases, drain
  an in-flight secure write, and perform the final delete so a previous
  account's queued operation cannot be recreated for the next account.
- Inline banners belong at the end of the forecast scroll. Occupy no space
  before actual platform size is known, bound no-fill retries, and dispose
  stale/invisible/background handles only after removing their `AdWidget`.
- Never use raw `Map<String, dynamic>` beyond the parsing layer
- Keep weather-data attribution visible in the About screen and beside the data
  it describes. Open-Meteo data links to its CC BY 4.0 terms; when a surface
  displays summer WBGT, link Japan's Ministry of the Environment there as well.
  State that displayed weather values have been edited or processed

## Device-local travel plans and reminders

- Treat SQLite as the source of truth. Persist a create/update before calling a
  platform notification API; scheduler errors must leave an outbox state and a
  non-blocking user warning, never report the completed DB write as a failed
  save.
- On iOS, open the database only inside the native-prepared Application Support
  subdirectory after backup exclusion and file protection succeed. Apply the
  policy to existing SQLite/WAL/SHM files and fail closed if preparation fails.
  Migrate a legacy Documents database and its sidecars before deleting the
  old copies. Android keeps app backup disabled.
- Store stable city codes and UTC instants. Convert civil input, D-day labels,
  cleanup boundaries, and scheduled reminders explicitly with
  `Asia/Tokyo`; never inherit the device timezone.
- Default a new plan without an outlook date to the next whole JST hour, not a
  fixed time that may already be past.
- Keep the plan limit at 20, reject duplicate city/departure pairs, and isolate
  a malformed SQLite row so it cannot block every valid plan. Reconciliation
  owns recovery for pending schedule/cancel/delete states and orphan
  notifications. Serialize reconciliation and mutations so an old snapshot
  cannot overwrite a newer edit.
- Notification permission is explicit opt-in at reminder save time. Do not add
  Android exact-alarm, full-screen intent, DND, advertising-ID, or background
  location permissions. Use inexact scheduling and tell users it can be
  delayed by power management.
- Preserve an Android inexact alarm that is still pending just after its
  nominal trigger, but never beyond the departure instant.
- Keep lock-screen content generic. Use only the `travel:` payload namespace
  and notification IDs `100000..199999`; never include city, coordinates,
  profile data, or a server credential in title, body, or payload.
- Initialize tap handling before authenticated UI routing, validate the
  payload, and handle missing/expired local targets without crashing.
- On logout, account switch, or account deletion, cancel only the travel
  notification namespace before deleting its local rows. If cancellation
  fails, keep the rows/outbox available for a visible cleanup retry.

## Theming & Design

- Simple, clean design — NOT a fashion app aesthetic
- Clothing icons: simple line-art illustrations (15 clothing tags + the no-outer icon)
- Do not use flashy colors or fashion-oriented design language
- Consistent padding, spacing, and font sizes via theme

## Accessibility completion criteria

These criteria apply to every current screen and every future UI change. A UI
change is not complete until the affected screen has been checked against all
applicable items.

- At 200% text scaling, text and controls must not clip, overlap, or overflow.
  Content that no longer fits the viewport must remain reachable by scrolling.
- Do not shrink text to make a fixed layout fit. Reflow rows into columns,
  allow wrapping, or make the content scrollable instead.
- Interactive targets must be at least 48 × 48 logical pixels on Android and
  44 × 44 points on iOS.
- Text contrast must be at least 4.5:1 for normal text and 3:1 for large text.
- Selection, status, errors, and other meaningful state must not rely on color
  alone. Pair color with a border, icon, label, shape, or semantics state.
- VoiceOver and TalkBack must announce meaningful names, selected/enabled
  state, and the current tab. Decorative images must be excluded from
  semantics.
- Focus order must follow the visual and task order. Verify it manually on both
  VoiceOver and TalkBack for each changed flow.

The root work-list accessibility automation task tracks regression coverage for
these criteria; manual checks remain required where platform assistive
technology behavior cannot be represented by widget tests.

## Icon Assets

16 UI icon assets are used (15 clothing tags plus the no-outer choice):

**Top (6):** sleeveless, short_sleeve, thin_long, long_sleeve, thick_long, knit_sweat

**Bottom (4):** long_pants, half_pants, short_pants, skirt

**Outer (5 + none):** light_outer, cardigan, jacket, coat, padding, none

File naming: `assets/icons/top_thin_long.png`, `assets/icons/outer_none.png`

## Error Handling

- Network errors: show retry option
- Auth errors (401): redirect to login
- Show user-friendly Japanese error messages, never technical errors
- Loading states: show skeleton or spinner

## Testing

- Widget tests for key UI components
- Unit tests for clothing tag mapping logic
- Integration tests for API client (with mocked responses)
- Responsive tests use 320×568, 360×800, 390×844, and 430×932 portrait
  smartphone viewports at 100%, 130%, and 200% text scaling. Tablet and
  landscape cases are intentionally excluded.
- Stable changed screens must run Flutter's text-contrast, labeled-tap-target,
  Android tap-target, and iOS tap-target guidelines where applicable.
