# photo_editor_ai

Flutter MVP for an AI-assisted photo editor.

## Quick Start

```bash
flutter pub get
flutter run -d chrome
```

## Export Behavior

- Android/iOS: `Save to device` writes edited image directly to Photos/Gallery.
- Web/Desktop: mobile gallery save is not available; this path is intended for Android/iOS.

## Centralized Env Setup

You can keep env values in one file instead of repeating `--dart-define` in each run command.

1. Copy `env/dev.example.json` to `env/dev.json`.
2. Put your real values in `env/dev.json`.
3. Run with:

```bash
flutter run -d chrome --dart-define-from-file=env/dev.json
```

VS Code launch profiles are already added in `.vscode/launch.json`:
- `Flutter Web (dev env)`
- `Flutter Android (dev env)`

Both profiles automatically pass `--dart-define-from-file=env/dev.json`.

## Run On Android (Detailed)

### 1. Prerequisites

1. Install Android Studio.
2. Install Android SDK + Platform Tools.
3. Install at least one Android Emulator image (or use a physical device).
4. Accept Android licenses:

```bash
flutter doctor --android-licenses
```

5. Verify toolchain:

```bash
flutter doctor -v
```

### 2. Prepare Project

```bash
flutter pub get
```

### 3. List Available Devices

```bash
flutter devices
```

### 4. Run On Android Emulator/Device

Using env file:

```bash
flutter run -d android --dart-define-from-file=env/dev.json
```

If you have multiple Android devices, pick exact id from `flutter devices`:

```bash
flutter run -d <android-device-id> --dart-define-from-file=env/dev.json
```

### 5. Build APK

Debug APK:

```bash
flutter build apk --debug --dart-define-from-file=env/dev.json
```

Release APK:

```bash
flutter build apk --release --dart-define-from-file=env/prod.json
```

Output path:

`build/app/outputs/flutter-apk/`

## Run On iOS (Detailed)

Important: iOS build/run requires macOS + Xcode. You cannot build iOS locally on Windows.

### 1. Prerequisites (macOS)

1. Install latest Xcode from App Store.
2. Install CocoaPods:

```bash
sudo gem install cocoapods
```

3. Open Xcode once and install additional components.
4. Verify:

```bash
flutter doctor -v
```

You should see:
- Flutter: OK
- Xcode: OK
- CocoaPods: OK

### 2. Prepare Project (macOS terminal)

```bash
flutter pub get
cd ios
pod install
cd ..
```

### 3. Run On iOS Simulator

List simulators:

```bash
flutter devices
```

Run:

```bash
flutter run -d ios --dart-define-from-file=env/dev.json
```

Or run with specific simulator id:

```bash
flutter run -d <ios-simulator-id> --dart-define-from-file=env/dev.json
```

### 4. Run On Real iPhone

1. Open `ios/Runner.xcworkspace` in Xcode.
2. In Signing & Capabilities, select Team and Bundle Identifier.
3. Connect iPhone, trust computer/device certificate.
4. Then run:

```bash
flutter run -d <iphone-device-id> --dart-define-from-file=env/dev.json
```

### 5. Build iOS App

```bash
flutter build ios --release --dart-define-from-file=env/prod.json
```

Then archive/upload via Xcode Organizer.

## Troubleshooting

### Android

1. Device not found:
- Check `flutter devices`.
- Ensure emulator is running or USB debugging is enabled.

2. Gradle build fails:
- Run `flutter clean` then `flutter pub get`.
- Re-check Android SDK components in Android Studio SDK Manager.

### iOS

1. CocoaPods error:

```bash
cd ios
pod repo update
pod install
cd ..
```

2. Signing error:
- Verify Team/Bundle ID in Xcode.
- Ensure Apple Developer account is active.

3. Build on Windows fails for iOS:
- Expected behavior. Move to macOS machine or CI runner on macOS.

## AI Integration

App supports 2 ways to get AI presets:

1. `AI_PRESET_API_URL`: call your own backend that returns `{"presets": [...]}`.
2. Direct LLM endpoint (OpenAI-compatible Chat Completions):
   - `AI_LLM_API_URL`
   - `AI_LLM_API_KEY`
   - `AI_LLM_MODEL` (optional, default `gpt-4o-mini`)

### Example: OpenAI-compatible endpoint

```bash
flutter run -d chrome \
  --dart-define=AI_LLM_API_URL=https://api.openai.com/v1/chat/completions \
  --dart-define=AI_LLM_API_KEY=YOUR_KEY \
  --dart-define=AI_LLM_MODEL=gpt-4o-mini
```

### Example: Other LLM endpoints (OpenAI format)

```bash
flutter run -d chrome \
  --dart-define=AI_LLM_API_URL=https://your-llm-endpoint/v1/chat/completions \
  --dart-define=AI_LLM_API_KEY=YOUR_KEY \
  --dart-define=AI_LLM_MODEL=your-model-name
```

If both remote calls fail, app automatically falls back to local generated presets.

## Security Note

Do not ship production mobile builds with a raw provider API key embedded in client `--dart-define`. In production, route requests through your backend and keep provider keys server-side.
