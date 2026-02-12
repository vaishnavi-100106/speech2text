# GreenVoice - Speech-to-Text Converter

A professional cross-platform mobile application built with Flutter, designed specifically for hearing-impaired users. GreenVoice converts real-time speech into accurate text using the OpenAI Whisper API.

## 🎯 Features

### Core Functionality
- **Real-Time Speech Recognition**: Capture live audio and convert to text instantly
- **Whisper AI Integration**: Uses OpenAI's Whisper API for accurate transcription
- **Secure API Key Handling**: Stores API keys securely using Flutter Secure Storage
- **Cross-Platform Support**: Optimized for both Android and iOS

### User Interface
- **Modern Green Theme**: Professional green color palette symbolizing clarity and accessibility
- **Dark/Light Mode**: Toggle between themes for comfortable usage
- **Accessible Design**: Large buttons, clear typography, and high contrast options

### Accessibility Features
- **Adjustable Font Size**: Customize text size for better readability
- **High Contrast Mode**: Enhanced text contrast for visually impaired users
- **Vibration Feedback**: Haptic feedback on record start/stop
- **Simple Navigation**: Intuitive interface designed for accessibility

### Additional Features
- **Transcription History**: Save and manage previous transcriptions
- **Export/Share**: Share transcribed text via other apps
- **Language Selection**: Support for multiple transcription languages
- **Audio Playback**: Play back recorded audio
- **Auto-Save**: Automatically save transcriptions to history

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode for mobile development
- OpenAI API key

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd greenvoice
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API Key**
   - Open `.env` file in the root directory
   - Replace `your_openai_api_key_here` with your actual OpenAI API key
   - Alternatively, you can set the API key in the app settings

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Screens

### 1. Splash Screen
- Beautiful animated splash screen with logo and tagline "Hear Through Text"

### 2. Home Screen
- Large central microphone button for recording
- Real-time transcription display
- Status indicators for recording/processing
- Quick action buttons for sharing and clearing

### 3. History Screen
- List of all saved transcriptions
- Timestamp and preview for each entry
- Share and delete functionality
- Clear all history option

### 4. Settings Screen
- API key configuration
- Accessibility options (font size, contrast, vibration)
- Theme selection (dark/light mode)
- Language preferences
- Reset settings option

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the root directory:

```env
# OpenAI API Configuration
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_BASE_URL=https://api.openai.com/v1

# App Configuration
APP_NAME=GreenVoice
APP_VERSION=1.0.0
```

### Permissions

#### Android
Add these permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

#### iOS
Add these permissions to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>GreenVoice needs access to your microphone to convert speech to text for hearing-impaired users.</string>
```

## 🏗️ Architecture

### State Management
- **Provider**: Used for state management across the app
- **AudioRecorderProvider**: Manages audio recording and transcription
- **ThemeProvider**: Handles theme switching
- **SettingsProvider**: Manages user preferences

### Services
- **WhisperApiService**: Handles OpenAI API communication
- **StorageService**: Manages local data storage and preferences

### Key Dependencies
- `provider`: State management
- `record`: Audio recording
- `flutter_dotenv`: Environment variable management
- `flutter_secure_storage`: Secure key storage
- `http`: HTTP requests for API calls
- `permission_handler`: Runtime permissions
- `vibration`: Haptic feedback
- `share_plus`: Share functionality

## 🔒 Security

- **API Key Storage**: API keys are stored using Flutter Secure Storage
- **HTTPS Communication**: All API communications use HTTPS
- **No Hardcoded Keys**: API keys are loaded from environment variables or secure storage
- **Permission Handling**: Proper runtime permission requests for microphone access

## 📦 Build & Release

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [Issues](../../issues) page
2. Create a new issue with detailed information
3. Include device information and error logs

## 🌟 Acknowledgments

- OpenAI for the Whisper API
- Flutter community for excellent packages and tools
- Accessibility advocates for inspiring this project

---

**GreenVoice** - Making communication accessible through technology.
