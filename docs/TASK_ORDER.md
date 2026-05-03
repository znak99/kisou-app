# Task Order — kisou-app

Development tasks in recommended order. **Start this after kisou-api Phase 4 (Home endpoint) is complete**, so you have a working API to test against.

Each task should be completed, tested, and committed before moving to the next.

---

## Phase 1: Project Foundation

### Task 1.1 — Flutter Project Setup

- Create Flutter project
- Configure pubspec.yaml with dependencies:
  - `flutter_riverpod` (state management)
  - `dio` (HTTP client)
  - `sign_in_with_apple` (Apple auth)
  - `google_sign_in` (Google auth)
  - `flutter_secure_storage` (token storage)
- Set up folder structure per CONVENTIONS.md
- Set up theme and basic MaterialApp
- Verify: app builds and runs on iOS simulator with blank screen

### Task 1.2 — API Client + Config

- Create `api_config.dart` with dev/prod base URL
- Create `api_client.dart` with dio instance
- Add auth interceptor (reads JWT from secure storage, attaches to requests)
- Add error interceptor (handle 401 → redirect to login)
- Create health check test: call `GET /health` on kisou-api
- Verify: app can reach the API server and log the health check response

### Task 1.3 — Clothing Tag Constants

- Create `clothing_tags.dart` with enums and mappings:
  - `ClothingTop`, `ClothingBottom`, `ClothingOuter` enums
  - API code string → enum conversion (`"SHIRT"` → `ClothingTop.shirt`)
  - Enum → Japanese display name (`ClothingTop.shirt` → `"シャツ"`)
  - Enum → icon asset path (`ClothingTop.shirt` → `"assets/icons/top_shirt.svg"`)
- Verify: write a simple test that round-trips API code → enum → display name

---

## Phase 2: Authentication + Onboarding

### Task 2.1 — Auth Service + Login

- Implement Apple Sign-In flow
- Implement Google Sign-In flow
- On success: send token to `POST /auth/login`, receive JWT
- Store JWT in flutter_secure_storage
- Create `auth_provider` (tracks login state)
- Verify: tap Apple/Google sign-in, receive JWT, store it, confirm authenticated state

### Task 2.2 — Onboarding Flow (Steps 1-3)

- Create onboarding screen with page-based navigation
- Step 1: Welcome message + Apple/Google sign-in buttons (calls Task 2.1 flow)
- Step 2: Nickname input (text field, max 10 characters, required)
- Step 3: Gender selection (男性 / 女性 / 選択しない)
- After each step, data is held in local state until onboarding completes
- Verify: complete steps 1-3, confirm data is captured correctly

### Task 2.3 — Onboarding Flow (Steps 4-6)

- Step 4: Cold/heat sensitivity selection
  - 寒がり: 寒がり / 普通 / 寒くない
  - 暑がり: 暑がり / 普通 / 暑くない
- Step 5: Location permission
  - Show explanation screen first, then trigger system permission dialog
  - If granted: get current location
  - If denied: show manual region selection (list of Japanese municipalities)
- Step 6: Departure/return time picker
  - Default: 09:00 / 18:00
  - "スキップ" button available (applies defaults)
  - On completion or skip: show completion popup → navigate to home
- On onboarding complete: call `PUT /users/me` with all collected data
- Verify: complete full onboarding, confirm user profile saved via API

---

## Phase 3: Home Screen

### Task 3.1 — Home Screen Layout

- Create home screen with three sections:
  - Top: greeting ("○○さん、今日の服装は") + region name
  - Middle: recommendation area (placeholder)
  - Bottom: weather comparison area (placeholder)
- Create `home_provider` that calls `GET /home`
- Show loading state while fetching
- Verify: home screen loads and displays greeting with user's nickname

### Task 3.2 — Recommendation Display

- Create `ClothingIcon` widget that displays the correct icon for a clothing code
- Create `RecommendationCard` widget showing one combination (top + bottom + outer icons)
- Display rank 1 prominently (large icons)
- Display rank 2 and 3 below (smaller icons)
- Vertical layout, all visible without scrolling if possible
- Verify: mock recommendation data renders correctly with icons

### Task 3.3 — Weather Comparison Display

- Create `WeatherComparison` widget
- Show today / yesterday / 2 days ago in a row
- Display: high temp, low temp
- Show relative comparison (e.g., "昨日より3°低い")
- Verify: mock weather data renders correctly with comparison text

### Task 3.4 — API Integration

- Connect `home_provider` to real `GET /home` endpoint
- Parse response into model classes
- Map clothing codes to enums and display
- Handle error states (no location, API error)
- Pull-to-refresh support
- Verify: home screen shows live data from API

---

## Phase 4: Feedback

### Task 4.1 — Feedback Bottom Sheet

- Create `FeedbackSheet` as a modal bottom sheet
- Step 1: "今日の服装は？" — show clothing icon grid for each category:
  - Top: tap one of 7 icons
  - Bottom: tap one of 4 icons (filtered by gender)
  - Outer: tap one of 5 icons or "なし"
- Step 2: "今日の体感は？" — three large buttons:
  - 寒かった / ちょうどよかった / 暑かった
- On submit: call `POST /feedback`
- Show confirmation: "反映しました！" → close sheet
- Verify: complete feedback flow, confirm data saved via API

### Task 4.2 — Feedback Trigger + Status

- On home screen, after return_time: show feedback prompt at bottom
- Call `GET /feedback/today` to check if already submitted
- If submitted: show "フィードバック済み" with edit link
- If not submitted: show "今日はどうでしたか？" button → opens feedback sheet
- On edit: pre-fill previous selections in the feedback sheet
- Verify: feedback prompt appears at correct time, status updates after submission

---

## Phase 5: Settings

### Task 5.1 — Settings Screen

- Create settings screen accessible from home (gear icon or menu)
- Sections:
  - ニックネーム変更 (nickname edit)
  - 性別変更 (gender change)
  - 寒がり・暑がり設定 (sensitivity change)
    - On change: show confirmation dialog ("補正値がリセットされます。よろしいですか？")
    - If confirmed: reset offset via `PUT /users/me`
  - 外出・帰宅時間 (departure/return time pickers)
  - 位置情報変更 (location: re-request GPS or manual selection)
  - プライバシーポリシー (opens WebView with GitHub Pages URL)
  - ログアウト (clear token, return to login)
  - アカウント削除 (confirmation dialog → call `DELETE /users/me` → return to login)
- All changes call `PUT /users/me`
- Verify: each setting change persists and is reflected on home screen

---

## Phase 6: Polish

### Task 6.1 — Placeholder Icons

- Create or source 16 simple line-art clothing icons
- Integrate into `assets/icons/`
- Update `clothing_tags.dart` with correct asset paths
- Verify: all icons display correctly in recommendations and feedback sheet

### Task 6.2 — Error Handling + Edge Cases

- No internet connection: show offline message
- API timeout: show retry button
- Token expired: redirect to login
- No location set: prompt to set location
- Empty state: first-time user before first recommendation

### Task 6.3 — End-to-End Testing

- Full flow: launch → onboarding → home → feedback → settings → logout → re-login
- Verify offset changes after feedback (check recommendation shifts)
- Verify sensitivity reset works
- Verify account deletion removes all data
