# Wardrobe - Hello World Flutter App

A simple Hello World Flutter application with a counter functionality.

## Getting Started

This project is a starting point for a Flutter application that runs on **iOS**, **Android**, **Web**, and **Desktop**.

### Prerequisites

- **Flutter SDK** (>=3.0.0)
- **Dart SDK** (included with Flutter)

#### Platform-Specific Requirements:

**For Android:**
- Android Studio
- Android SDK
- Android emulator OR physical Android device with USB debugging

**For iOS (macOS only):**
- Xcode
- iOS Simulator OR physical iOS device
- Apple Developer account (for physical device)

**For Web:**
- Chrome or any modern web browser

### Installation

1. Clone this repository or navigate to the project directory
2. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

**Android:**
```bash
flutter run                    # Run on Android device/emulator
flutter run -d android        # Specific Android target
```

**iOS:**
```bash
flutter run -d ios            # Run on iOS simulator/device
```

**Web:**
```bash
flutter run -d chrome         # Run in Chrome browser
```

**All Platforms:**
```bash
flutter run                  # Will prompt to choose device
```

### Available Devices

Check available devices:
```bash
flutter devices
```

### Project Structure

- `lib/main.dart` - Main application file containing the Hello World app
- `pubspec.yaml` - Project configuration and dependencies
- `analysis_options.yaml` - Linting rules configuration

### Features

- **Hello World Display**: Large, styled "Hello World!" text
- **Interactive Counter**: Tap the floating action button to increment the counter
- **Material Design**: Uses Material 3 design system
- **Responsive UI**: Works on both mobile and tablet devices

### Next Steps

You can customize this app by:
- Adding more screens and navigation
- Implementing additional features like user authentication
- Adding data persistence with a database
- Styling the UI to match your brand

### Development

To develop this app:
1. Make changes to the Dart files in the `lib/` directory
2. Hot reload by pressing `r` in the terminal or save your files
3. For more detailed logs, run with:
   ```bash
   flutter run --verbose
   ```

## Learn More

For more information about Flutter development:
- [Flutter documentation](https://docs.flutter.dev/)
- [Dart language documentation](https://dart.dev/guides/language/language-tour)
