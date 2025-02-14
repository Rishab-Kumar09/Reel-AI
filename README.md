# AI-Powered Video Learning Platform

A Flutter application that transforms video content into interactive learning experiences using AI. The app leverages OpenAI's GPT-4 and Whisper models to provide transcriptions, quizzes, and social sharing capabilities.

## Features

### 🎥 Video Management
- Smooth video playback with adaptive quality
- Automatic quality adjustment based on network conditions
- Support for both vertical and horizontal videos
- Video compression for optimal performance

### 🤖 AI-Powered Features
- **Smart Transcription**
  - Automatic video transcription using OpenAI's Whisper
  - Video compression before transcription for efficiency
  - Formatted transcripts with sections (Summary, Steps, Notes)
  - Category-based formatting (Educational vs General content)

- **Interactive Quizzes**
  - Automatic quiz generation for educational content
  - Smart content analysis to determine quiz suitability
  - Multiple choice questions with explanations
  - Progressive difficulty levels
  - Score tracking and performance feedback

- **Social Media Integration**
  - Intelligent post generation for Twitter, LinkedIn, and Facebook
  - Platform-specific formatting and tone
  - Standalone content that delivers full value
  - Automatic hashtag suggestions

### 💡 Smart Features
- Caching system for transcripts and quizzes
- Offline access to previously generated content
- Real-time network speed monitoring
- Adaptive video quality switching

## Technical Details

### Prerequisites
- Flutter SDK
- Firebase account
- OpenAI API key

### Environment Setup
1. Create a `.env` file in the root directory
2. Add your OpenAI API key:
```
OPENAI_API_KEY=your_api_key_here
```

### Firebase Configuration
The app uses the following Firebase services:
- Authentication
- Firestore Database
- Storage
- Analytics

### Dependencies
```yaml
dependencies:
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.6.5
  firebase_analytics: ^10.7.4

  # State Management
  get: ^4.6.6

  # Video Processing
  video_player: ^2.8.1
  video_compress: ^3.1.2

  # AI & API
  http: ^1.3.0
  flutter_dotenv: ^5.1.0

  # UI Components
  google_fonts: ^6.1.0
  cached_network_image: ^3.3.1
  flutter_svg: ^2.0.10+1
  lottie: ^3.1.0
```

## Architecture

The project follows a clean architecture pattern with the following structure:

```
lib/
  ├── core/
  │   ├── theme/
  │   └── utils/
  ├── features/
  │   └── feed/
  │       ├── data/
  │       │   ├── models/
  │       │   └── services/
  │       └── presentation/
  │           ├── controllers/
  │           ├── views/
  │           └── widgets/
  └── main.dart
```

## AI Integration

### Transcription Service
- Uses OpenAI's Whisper model for accurate transcription
- Implements video compression before transcription
- Handles chunking for long videos
- Provides formatted output based on content type

### Quiz Generation
- Analyzes content suitability for quizzes
- Generates contextually relevant questions
- Provides detailed explanations for answers
- Adapts difficulty based on content complexity

### Social Media Content
- Generates platform-specific content
- Ensures standalone value without video dependency
- Maintains consistent branding and tone
- Optimizes for engagement

## Performance Optimizations

- Video compression before processing
- Caching system for generated content
- Adaptive video quality
- Efficient memory management
- Background processing for heavy tasks

## Future Enhancements

- [ ] GPT-4 Vision integration for visual content analysis
- [ ] Enhanced quiz types (fill-in-blanks, matching)
- [ ] Learning path recommendations
- [ ] Progress tracking and analytics
- [ ] Collaborative learning features
- [ ] Custom video thumbnails
- [ ] Offline video download
- [ ] Multi-language support

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- OpenAI for GPT-4 and Whisper APIs
- Flutter team for the amazing framework
- Firebase for backend services


