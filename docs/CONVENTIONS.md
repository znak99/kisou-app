# Code Conventions — kisou-app

## Language & Framework

- Flutter 3.x / Dart
- Target platforms: iOS (primary), Android
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
- API base URL loaded from config (different for dev/prod)
- All API responses are parsed into model classes
- Never use raw `Map<String, dynamic>` beyond the parsing layer

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

The root `TODO.md` accessibility automation task tracks regression coverage for
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
