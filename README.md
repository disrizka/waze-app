# wa_blast

A Flutter app for WaveUp.

## Requirements

- Flutter SDK (Dart >= 3.8.1)
- Android Studio / Xcode as needed

## Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Environment files (required):

This project loads environment variables from `.env.dev` or `.env.prod` (and falls back to `.env` if present). Make sure both files exist and are included in `pubspec.yaml` assets.

Create these files at the project root:

`.env.dev`

```
BASIC_AUTH=REPLACE_ME
MIDTRANS_CLIENT_KEY=REPLACE_ME
MERCHANT_BASE_URL=https://your-merchant-url.example
```

`.env.prod`

```
BASIC_AUTH=REPLACE_ME
MIDTRANS_CLIENT_KEY=REPLACE_ME
MERCHANT_BASE_URL=https://your-merchant-url.example
```

Notes:
- `BASIC_AUTH` can be raw base64 or already prefixed with `Basic `.
- `MIDTRANS_CLIENT_KEY` and `MERCHANT_BASE_URL` are required for Midtrans.

## Run

Dev flavor:

```bash
flutter run --dart-define=FLAVOR=dev
```

Prod flavor:

```bash
flutter run --dart-define=FLAVOR=prod
```

## Build

Android (APK):

```bash
flutter build apk --dart-define=FLAVOR=prod
```

Android (AAB):

```bash
flutter build appbundle --dart-define=FLAVOR=prod
```

iOS:

```bash
flutter build ios --dart-define=FLAVOR=prod
```

## Project Notes

- Env loading is handled in `lib/main_common.dart`.
- Flavor selection is handled in `lib/main.dart`.
- Base URL is configured via `lib/env.dart` and used in `lib/constants/api_constant.dart`.
