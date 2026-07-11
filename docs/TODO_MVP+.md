# TODO — kisou-app

Post-MVP tasks in recommended priority order.

---

## High Priority

### High-Quality App Icon
- [x] 모던·미니멀 앱 아이콘 제작 (해+티셔츠 플랫 실루엣, 라이트/다크/틴티드 + Android 모노크롬 대응, flutter_launcher_icons)
- [ ] (선택) 스플래시 로고도 신규 아이콘 톤에 맞춰 교체 검토

### UI Design Renewal
- [ ] Design new visual identity (color palette, typography, spacing)
- [ ] Redesign all screens (login, onboarding, home, feedback, settings)
- [ ] Keep design simple and clean — NOT a fashion app aesthetic
- [ ] Ensure Japanese text readability

### Clothing Icons
- [ ] Design 16 clothing icons (simple line-art or flat style)
  - [ ] Top (6): sleeveless, short_sleeve, thin_long, long_sleeve, thick_long, knit_sweat
  - [ ] Bottom (4): long_pants, half_pants, short_pants, skirt
  - [ ] Outer (5): light_outer, cardigan, jacket, coat, padding
  - [ ] None icon for "no outer"
- [ ] Add flutter_svg package
- [ ] Replace text badges with SVG icons in clothing_icon.dart
- [ ] Update icon paths in clothing_tags.dart

### Authentication Production Setup
- [ ] Apple Sign-In: Add capability in Xcode, configure App ID
- [ ] Google Sign-In: Add GoogleService-Info.plist (iOS), google-services.json (Android)
- [ ] Test real sign-in flow on physical device
- [ ] Remove development login buttons for production build

### Environment Separation
- [ ] Create separate config for development and production
- [ ] Development: show dev login buttons, use dev API URL
- [ ] Production: hide dev login buttons, use production API URL
- [ ] Use flutter build flags or .env files

### Privacy Policy Integration
- [ ] Update privacy policy URL in settings screen (replace placeholder)
- [ ] Test WebView or browser opening

---

## Medium Priority

### Real Device Testing
- [ ] Test on physical iOS device
- [ ] Test on physical Android device
- [ ] Test GPS location on real device (not simulator)
- [ ] Test Apple Sign-In on real device
- [ ] Test Google Sign-In on real device
- [ ] Verify push notification permissions (for future use)

### iOS Widget (Phase 2)
- [ ] Create iOS widget target (SwiftUI + WidgetKit)
- [ ] iOS Medium Widget: show rank 1 recommendation
- [ ] iOS Small Widget: show rank 1 recommendation (compact)
- [ ] App-widget data sharing via home_widget package or App Groups
- [ ] Widget refresh strategy

### Android Widget (Phase 3)
- [ ] Create Android widget (Kotlin + Glance or AppWidget)
- [ ] Same display as iOS widget
- [ ] App-widget data sharing

### Push Notification UI (Phase 2)
- [ ] Integrate Firebase Cloud Messaging
- [ ] Handle morning notification tap → open home screen
- [ ] Handle evening notification tap → open feedback sheet
- [ ] Add notification settings to settings screen (on/off, time)

### App Store Preparation
- [ ] App icon design
- [ ] Splash screen / launch screen
- [ ] App Store screenshots (Japanese)
- [ ] App Store description (Japanese)
- [ ] App Store privacy nutrition label
- [ ] Google Play data safety section
- [ ] App Store review guidelines compliance check

---

## Low Priority

### UX Improvements
- [ ] Onboarding animation or illustration
- [ ] Home screen pull-to-refresh animation
- [ ] Skeleton loading UI (instead of spinner)
- [ ] Haptic feedback on button taps
- [ ] Dark mode support

### Accessibility
- [ ] VoiceOver / TalkBack support
- [ ] Dynamic font size support
- [ ] Sufficient color contrast

### Analytics
- [ ] Integrate Firebase Analytics
- [ ] Track key events: onboarding completion, feedback submission, settings changes
- [ ] Configure without IDFA (no ATT popup needed)

### Crash Reporting
- [ ] Integrate Firebase Crashlytics
- [ ] Test crash reporting

### Multi-language (Future)
- [ ] Localization infrastructure (arb files or similar)
- [ ] Currently Japanese only — plan for future languages

---

## Completed (MVP)

- [x] Flutter project setup (Riverpod, dio, secure storage)
- [x] API client with auth interceptor
- [x] Clothing tag constants (6 tops, 4 bottoms, 5 outers + none)
- [x] Authentication (Apple/Google + development login)
- [x] Onboarding 6 steps (login → nickname → gender → sensitivity → location → time)
- [x] Onboarding completion flag (SharedPreferences)
- [x] Keychain cleanup on fresh install
- [x] Home screen (3 recommendations + weather comparison)
- [x] Clothing display with text badges
- [x] Weather comparison (today / yesterday / 2 days ago)
- [x] Feedback bottom sheet (clothing selection + comfort feeling)
- [x] Feedback status display + edit mode
- [x] Settings screen (nickname, gender, sensitivity, time, location, privacy, logout, delete)
- [x] Sensitivity change confirmation + offset reset
- [x] Account deletion
- [x] Error handling (network, timeout, 401, location not set)
- [x] JST timezone handling
