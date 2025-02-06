class AppConstants {
  static const String appName = 'Reel AI';
  static const String appVersion = '1.0.0';

  // Video Constants
  static const int maxVideoDuration = 90; // seconds
  static const int minVideoDuration = 60; // seconds
  static const int maxVideoSize = 50; // MB
  static const List<String> supportedVideoFormats = ['mp4', 'mov'];
  static const int defaultVideoQuality = 1080; // p

  // Feed Constants
  static const int initialFeedItems = 10;
  static const int feedBatchSize = 5;

  // Categories
  static const List<String> mainCategories = [
    'all',
    'tech',
    'lifehacks',
    'education',
    'cooking',
    'art',
    'fun',
  ];
}
