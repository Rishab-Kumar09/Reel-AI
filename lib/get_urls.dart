import 'package:firebase_core/firebase_core.dart';
import 'features/feed/data/services/sample_data_service.dart';
import 'firebase_options.dart';

void main() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    final sampleDataService = SampleDataService();
    await sampleDataService.getVideoDownloadUrls();
  } catch (e) {
    print('Error: $e');
  }
} 