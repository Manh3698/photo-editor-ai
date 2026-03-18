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

> **Requires macOS + Xcode.** iOS builds cannot be produced on Windows or Linux.

### 1. Prerequisites (macOS)

1. Install the latest **Xcode** from the App Store (≥ Xcode 15 recommended).
2. Open Xcode once and accept the license / install additional components when prompted.
3. Install **CocoaPods**:

```bash
sudo gem install cocoapods
```

4. Install Flutter for macOS (if not already) and verify the full toolchain:

```bash
flutter doctor -v
```

Expected healthy items: Flutter, Xcode, CocoaPods, and (optionally) VS Code.

---

### 2. Prepare Project (macOS Terminal)

```bash
flutter pub get
cd ios
pod install
cd ..
```

If `pod install` fails with a version conflict, run:

```bash
cd ios
pod repo update
pod install
cd ..
```

---

### 3. Run On iOS Simulator

List available simulators:

```bash
flutter devices
# or
xcrun simctl list devices
```

Boot a simulator and run:

```bash
flutter run -d ios --dart-define-from-file=env/dev.json
```

Run on a specific simulator by id:

```bash
flutter run -d <simulator-id> --dart-define-from-file=env/dev.json
```

> Note: `Save to device` saves to the Simulator's photo library. You can view it inside the Simulator's Photos app.

---

### 4. Run On a Real iPhone / iPad

#### 4a. Apple Developer account

You need a free or paid Apple Developer account. A **free account** lets you sideload onto your own device (7-day cert expiry). A **paid account** ($99/year) lets you deploy more broadly and to TestFlight.

#### 4b. Register your device UDID (free account only)

1. Connect iPhone via USB.
2. Open Xcode → `Window → Devices and Simulators`.
3. Note the **Identifier** (UDID) shown next to your device.
4. Free accounts automatically register the device on first run from Xcode; paid accounts register via the Developer Portal.

#### 4c. Configure signing in Xcode

1. Open `ios/Runner.xcworkspace` (not `.xcodeproj`) in Xcode.
2. Select the **Runner** target → **Signing & Capabilities** tab.
3. Tick **Automatically manage signing**.
4. Select your **Team** from the dropdown (your Apple ID).
5. Set a unique **Bundle Identifier**, e.g. `com.yourname.photoeditorai`.
6. Xcode will automatically create a Development certificate and Provisioning Profile.

#### 4d. Trust the developer certificate on your device

> First-time setup only.

1. On your iPhone: **Settings → General → VPN & Device Management**.
2. Tap your developer account name under "Developer App".
3. Tap **Trust "Apple Development: …"** → confirm.

#### 4e. Run from terminal

Connect iPhone via USB, then:

```bash
flutter devices
```

Find your device id (e.g. `00008030-001234ABCDEF001E`), then:

```bash
flutter run -d 00008030-001234ABCDEF001E --dart-define-from-file=env/dev.json
```

Or let Flutter pick the only connected physical device:

```bash
flutter run -d ios --dart-define-from-file=env/dev.json
```

VS Code: select **Flutter iOS (dev env)** from the Run & Debug panel (`.vscode/launch.json` is already configured).

---

### 5. Wireless Debugging (USB-free after first pairing)

1. Connect iPhone via USB at least once.
2. In Xcode: `Window → Devices and Simulators` → select device → tick **Connect via network**.
3. Disconnect USB. The device stays listed in `flutter devices` over Wi-Fi as long as Mac and iPhone are on the same network.
4. Run as normal using the wireless device id.

---

### 6. Build iOS App (Release)

```bash
flutter build ios --release --dart-define-from-file=env/prod.json
```

Then in Xcode: **Product → Archive → Distribute App** (App Store / Ad Hoc / Development).

---

### 7. iOS Permissions Configured

The following usage descriptions are declared in `ios/Runner/Info.plist` and will be shown to the user:

| Permission | Key | When triggered |
|---|---|---|
| Photo library read | `NSPhotoLibraryUsageDescription` | Picking an image to edit |
| Photo library write | `NSPhotoLibraryAddUsageDescription` | Saving edited image to Photos |

---

## Troubleshooting

### Android

1. Device not found:
   - Check `flutter devices`.
   - Ensure emulator is running or USB debugging is enabled on physical device.

2. Gradle build fails:

```bash
flutter clean
flutter pub get
```

   Re-check Android SDK components in Android Studio SDK Manager.

### iOS

1. **CocoaPods error**:

```bash
cd ios
pod repo update
pod install
cd ..
```

2. **Signing error** ("No profiles for … were found"):
   - Open `ios/Runner.xcworkspace` in Xcode.
   - Signing & Capabilities → verify Team and Bundle ID.
   - Click **Try Again** next to the error or go to **Xcode → Preferences → Accounts** and refresh certificates.

3. **"Untrusted Developer"** on device:
   - Settings → General → VPN & Device Management → Trust your cert.

4. **Free account cert expired** (7-day limit):
   - Re-run `flutter run` from Xcode or terminal; Xcode will re-sign automatically.
   - Or upgrade to a paid Apple Developer account.

5. **Wireless device drops from `flutter devices`**:
   - Ensure Mac and iPhone are on the same Wi-Fi network.
   - Re-enable **Connect via network** in the Xcode Devices panel.

6. **Build on Windows fails for iOS**:
   - Expected. Move to a macOS machine or use a macOS CI runner (e.g. GitHub Actions `macos-latest`).

7. **`Save to device` doesn't appear in Photos**:
   - On first save, iOS will prompt for photo library permission — tap **Allow**.
   - Check `NSPhotoLibraryAddUsageDescription` is present in `Info.plist` (already added).
   - On simulator, saved images appear in the Simulator's Photos app under the `PhotoEditorAI` album.

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
