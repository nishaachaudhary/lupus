// lib/helper/firebase_helper.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:lupus_care/views/chat_screen/firebase/firebase_chat_service.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';

class FirebaseHelper {
  static FirebaseHelper? _instance;
  static FirebaseHelper get instance => _instance ??= FirebaseHelper._internal();

  FirebaseHelper._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize Firebase
  Future<bool> initializeFirebase() async {
    try {
      print('🔥 Initializing Firebase...');

      // Check if Firebase is already initialized
      try {
        Firebase.app();
        print('✅ Firebase already initialized');
        _isInitialized = true;
        return true;
      } catch (e) {
        // Firebase not initialized, continue with initialization
      }

      // Initialize Firebase
      await Firebase.initializeApp();

      // Configure Firestore settings
      await _configureFirestore();

      // Initialize Firebase services
      await _initializeFirebaseServices();

      _isInitialized = true;
      print('✅ Firebase initialized successfully');
      return true;

    } catch (e) {
      print('❌ Firebase initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> _configureFirestore() async {
    try {
      // Enable offline persistence (only if not already enabled)
      try {
        await FirebaseFirestore.instance.enablePersistence();
        print('✅ Firestore offline persistence enabled');
      } catch (e) {
        print('⚠️ Firestore persistence already enabled or not supported: $e');
      }

      // Configure Firestore settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      print('✅ Firestore configured');
    } catch (e) {
      print('⚠️ Firestore configuration warning: $e');
      // Continue even if this fails
    }
  }

  Future<void> _initializeFirebaseServices() async {
    try {
      // Register Firebase Chat Service if not already registered
      if (!Get.isRegistered<FirebaseChatService>()) {
        final firebaseChatService = FirebaseChatService.instance;
        Get.put<FirebaseChatService>(firebaseChatService, permanent: true);
        print('✅ FirebaseChatService registered');
      } else {
        print('✅ FirebaseChatService already registered');
      }

      // Don't register ChatController here - let it initialize when needed
      print('✅ Firebase services ready');

    } catch (e) {
      print('❌ Error initializing Firebase services: $e');
      rethrow;
    }
  }

  // Check if Firebase is properly configured
  Future<bool> checkFirebaseConfiguration() async {
    try {
      print('🔍 Checking Firebase configuration...');

      // Check if Firebase app is initialized
      final app = Firebase.app();
      print('✅ Firebase app initialized: ${app.name}');

      // Test Firestore connection with timeout
      await FirebaseFirestore.instance
          .collection('_health_check')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      print('✅ Firestore connection successful');

      // Test Firebase Auth
      final auth = FirebaseAuth.instance;
      print('✅ Firebase Auth available: ${auth.app.name}');

      // Test Firebase Storage
      final storage = FirebaseStorage.instance;
      print('✅ Firebase Storage available: ${storage.app.name}');

      return true;
    } catch (e) {
      print('❌ Firebase configuration check failed: $e');
      return false;
    }
  }

  // Initialize Firebase for chat functionality with retry logic
  Future<bool> initializeForChat() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        print('🎮 Initializing Firebase for chat (attempt ${retryCount + 1}/$maxRetries)...');

        if (!_isInitialized) {
          final success = await initializeFirebase();
          if (!success) {
            throw Exception('Firebase initialization failed');
          }
        }

        // Check configuration with timeout
        final isConfigured = await checkFirebaseConfiguration()
            .timeout(const Duration(seconds: 15));

        if (!isConfigured) {
          throw Exception('Firebase not properly configured');
        }

        // Test user authentication or create anonymous user
        await _ensureUserAuthentication();

        print('🎉 Firebase chat initialization completed successfully');
        return true;

      } catch (e) {
        retryCount++;
        print('❌ Firebase chat initialization attempt $retryCount failed: $e');

        if (retryCount < maxRetries) {
          print('🔄 Retrying in ${retryCount * 2} seconds...');
          await Future.delayed(Duration(seconds: retryCount * 2));
        } else {
          print('💀 Firebase chat initialization failed after $maxRetries attempts');
          return false;
        }
      }
    }

    return false;
  }

  // Ensure user is authenticated (create anonymous user if needed)
  Future<void> _ensureUserAuthentication() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        print('🔐 Creating anonymous user for chat...');
        final credential = await FirebaseAuth.instance.signInAnonymously();

        if (credential.user != null) {
          print('✅ Anonymous user created: ${credential.user!.uid}');

          // Create user document in Firestore
          await _createUserDocument(credential.user!);
        } else {
          throw Exception('Failed to create anonymous user');
        }
      } else {
        print('✅ User already authenticated: ${currentUser.uid}');

        // Update user document if needed
        await _updateUserDocument(currentUser);
      }
    } catch (e) {
      print('❌ Error ensuring user authentication: $e');
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'id': user.uid,
        'name': user.displayName ?? 'Anonymous User',
        'email': user.email ?? 'anonymous@lupuscare.com',
        'avatar': user.photoURL ?? '',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ User document created for: ${user.uid}');
    } catch (e) {
      print('❌ Error creating user document: $e');
      rethrow;
    }
  }

  // Update user document in Firestore
  Future<void> _updateUserDocument(User user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      print('✅ User document updated for: ${user.uid}');
    } catch (e) {
      print('⚠️ Could not update user document: $e');
      // Don't throw error, continue anyway
    }
  }

  // Get current user info
  User? getCurrentUser() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  // Check if user is authenticated
  bool isUserAuthenticated() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (e) {
      print('❌ Error checking authentication: $e');
      return false;
    }
  }

  // Get Firestore instance
  FirebaseFirestore get firestore {
    return FirebaseFirestore.instance;
  }

  // Get Firebase Auth instance
  FirebaseAuth get auth {
    return FirebaseAuth.instance;
  }

  // Get Firebase Storage instance
  FirebaseStorage get storage {
    return FirebaseStorage.instance;
  }

  // Create initial Firestore collections (for testing)
  Future<void> setupFirestoreCollections() async {
    try {
      print('📦 Setting up Firestore collections...');

      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        print('⚠️ No authenticated user, skipping collection setup');
        return;
      }

      // Test write to users collection
      await firestore.collection('users').doc(currentUser.uid).set({
        'id': currentUser.uid,
        'name': currentUser.displayName ?? 'Test User',
        'email': currentUser.email ?? 'test@lupuscare.com',
        'avatar': '',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Firestore collections verified successfully');
    } catch (e) {
      print('⚠️ Firestore collections setup warning: $e');
      // Continue even if this fails
    }
  }

  // Sign out and clean up
  Future<void> signOut() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Update user status to offline
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Error during sign out: $e');
    }
  }

  // Dispose Firebase resources
  Future<void> dispose() async {
    try {
      // Sign out user
      await signOut();

      // Dispose Firebase services
      if (Get.isRegistered<FirebaseChatService>()) {
        // FirebaseChatService handles its own disposal
        print('🧹 Firebase chat service will be disposed automatically');
      }

      _isInitialized = false;
      print('✅ Firebase resources disposed');
    } catch (e) {
      print('❌ Error disposing Firebase resources: $e');
    }
  }

  // Health check for Firebase services
  Future<Map<String, bool>> healthCheck() async {
    final results = <String, bool>{};

    try {
      // Check Firebase initialization
      results['firebase_initialized'] = _isInitialized;

      // Check Auth
      try {
        final user = FirebaseAuth.instance.currentUser;
        results['auth_available'] = true;
        results['user_authenticated'] = user != null;
      } catch (e) {
        results['auth_available'] = false;
        results['user_authenticated'] = false;
      }

      // Check Firestore
      try {
        await FirebaseFirestore.instance
            .collection('_health')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));
        results['firestore_available'] = true;
      } catch (e) {
        results['firestore_available'] = false;
      }

      // Check Storage
      try {
        final ref = FirebaseStorage.instance.ref().child('_health_check');
        results['storage_available'] = true;
      } catch (e) {
        results['storage_available'] = false;
      }

      print('🏥 Firebase health check completed: $results');
      return results;
    } catch (e) {
      print('❌ Firebase health check failed: $e');
      results['health_check_failed'] = true;
      return results;
    }
  }
}

// Extension for easy Firebase access
extension FirebaseAccess on GetInterface {
  FirebaseHelper get firebase => FirebaseHelper.instance;
}