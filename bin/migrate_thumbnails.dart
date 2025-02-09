import 'dart:io' show ProcessSignal, exit;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_firebase_app_new/firebase_options.dart';
import 'package:flutter_firebase_app_new/scripts/thumbnail_migration.dart';

void main() async {
  try {
    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase only if it hasn't been initialized yet
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    print('Starting thumbnail migration script...');
    final migrationScript = ThumbnailMigrationScript();

    // Handle script interruption
    ProcessSignal.sigint.watch().listen((signal) {
      print('\nReceived interrupt signal, stopping migration gracefully...');
      migrationScript.stopMigration();
    });

    // Start migration
    await migrationScript.startMigration();

    // Print final stats
    final stats = migrationScript.getMigrationStats();
    print('\nMigration completed!');
    print('Total processed: ${stats['processedCount']}');
    print('Successful: ${stats['successCount']}');
    print('Failed: ${stats['failureCount']}');

    if (stats['failureCount'] > 0) {
      print('\nTo resume migration for failed videos, use this ID:');
      print('Last processed ID: ${stats['lastProcessedId']}');
    }

    // Exit the script
    exit(0);
  } catch (e, stackTrace) {
    print('Error running migration: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
