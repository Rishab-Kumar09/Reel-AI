# Reel AI - A Short format Video Learning App

A modern short video platform built with Flutter and Firebase, featuring AI-powered video transcription.

## Features

- User Authentication (Email/Password and Google Sign-in)
- Video Upload and Recording
- Feed with Video Playback
- AI-Powered Video Transcription
  - Automatic transcription using OpenAI Whisper
  - Smart formatting that preserves video content integrity
  - Transcript caching for faster access
  - Support for videos up to 25MB
- Profile Management
- Category-based Content Discovery
- Dark/Light Theme Support

## Tech Stack

- Flutter
- Firebase (Auth, Firestore, Storage)
- OpenAI (Whisper API for transcription, GPT-4 for formatting)
- GetX for State Management
- Camera Plugin for Video Recording
- File Picker for Video Upload
- Video Compression for optimal processing

## Getting Started

### Prerequisites

- Flutter SDK
- Firebase Project
- OpenAI API Key
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

4. Set up OpenAI API
- Create a `.env` file in the root directory
- Add your OpenAI API key:
  ```
  OPENAI_API_KEY=your_api_key_here
  ```

5. Run the app
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
│   │   ├── data/
│   │   │   ├── models/
│   │   │   └── services/
│   │   │       └── transcription_service.dart
│   │   ├── presentation/
│   │   └── widgets/
│   ├── create/
│   ├── discover/
│   ├── profile/
│   └── navigation/
└── main.dart
```

## AI Transcription Features

The app includes advanced AI-powered video transcription:

- **Automatic Transcription**: Uses OpenAI's Whisper API to generate accurate transcripts
- **Content Integrity**: Ensures transcripts only contain information from the video
- **Smart Formatting**: Organizes content while preserving original context and quotes
- **Efficient Processing**: 
  - Compresses videos for optimal processing
  - Caches transcripts for faster access
  - Handles videos up to 25MB
- **Error Handling**: 
  - Retries on API failures
  - Provides clear error messages
  - Maintains transcript state in Firestore

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request.

