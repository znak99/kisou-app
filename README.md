# kisou-app

Flutter mobile app for **キソウ** — a weather-based personalized clothing recommendation app for Japan.

## What is キソウ?

キソウ predicts whether a user will feel cold or hot based on weather data and personal comfort preferences, then recommends clothing tag combinations with intuitive icons (e.g., shirt icon + long pants icon + light outer icon). It is **not** a fashion coordination app — it does not recommend colors, brands, or styles. The goal is to answer: **"How thick should I dress today?"**

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.x |
| Language | Dart |
| State Management | Riverpod |
| HTTP Client | dio |
| Auth | Apple Sign-In / Google Sign-In |
| UI Language | Japanese only (MVP) |

## Project Structure

```
kisou-app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/               # Environment config, API base URL
│   ├── models/               # Data classes
│   ├── providers/            # Riverpod providers
│   ├── services/             # API client, auth service
│   ├── screens/              # Full-page screens
│   │   ├── onboarding/
│   │   ├── home/
│   │   └── settings/
│   ├── widgets/              # Reusable UI components
│   │   ├── clothing_icon.dart
│   │   ├── feedback_sheet.dart
│   │   └── weather_comparison.dart
│   ├── constants/            # Clothing tag codes, mappings
│   │   └── clothing_tags.dart
│   └── utils/                # Helpers, formatters
├── assets/
│   ├── icons/                # 16 clothing line-art icons
│   └── images/
├── docs/
│   ├── DESIGN.md             # Full detailed design document
│   ├── CONVENTIONS.md        # Code conventions
│   └── TASK_ORDER.md         # Development task order
├── pubspec.yaml
└── CLAUDE.md                 # Context file for AI agents
```

## Getting Started

### Prerequisites

- Flutter SDK 3.x installed
- iOS Simulator or Android Emulator
- kisou-api running (for API integration)

### Run

```bash
flutter pub get
flutter run
```

### Environment Configuration

Set the API base URL in config:
- Development: `http://<your-server-ip>:8000`
- Production: `https://api.kisou.app` (TBD)

## Documentation

- [Detailed Design](docs/DESIGN.md) — Full app design specification
- [Code Conventions](docs/CONVENTIONS.md) — Coding standards and patterns
- [Task Order](docs/TASK_ORDER.md) — Step-by-step development plan
