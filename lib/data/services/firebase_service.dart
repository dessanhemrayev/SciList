import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<bool>? _initialization;

  static Future<bool> initialize() =>
      _initialization ??= _initializeOnce();

  static Future<bool> _initializeOnce() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _installCrashlyticsHandlers();
      return true;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Firebase initialization',
          context: ErrorDescription('Firebase failed to initialize'),
        ),
      );
      return false;
    }
  }

  static void _installCrashlyticsHandlers() {
    final supportsCrashlytics =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supportsCrashlytics) return;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(FirebaseCrashlytics.instance.recordFlutterError(details));
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: true,
        ),
      );
      return true;
    };
  }
}