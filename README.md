# Reel AI - Flutter Video Learning App

A modern video learning platform built with Flutter and Firebase.

## Features

- User Authentication (Email/Password and Google Sign-in)
- Video Upload and Recording
- Feed with Video Playback
- Profile Management
- Category-based Content Discovery
- Dark/Light Theme Support

## Tech Stack

- Flutter
- Firebase (Auth, Firestore, Storage)
- GetX for State Management
- Camera Plugin for Video Recording
- File Picker for Video Upload

## Getting Started

### Prerequisites

- Flutter SDK
- Firebase Project
- Android Studio / VS Code
- Git

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/flutter_firebase_app_new.git
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Firebase
- Create a new Firebase project
- Add Android and iOS apps to your Firebase project
- Download and place the configuration files:
  - `google-services.json` for Android
  - `GoogleService-Info.plist` for iOS
  - Update `firebase_options.dart` with your Firebase configuration

4. Run the app
```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   ├── routes/
│   ├── theme/
│   └── widgets/
├── features/
│   ├── auth/
│   ├── feed/
│   ├── create/
│   ├── discover/
│   ├── profile/
│   └── navigation/
└── main.dart
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
