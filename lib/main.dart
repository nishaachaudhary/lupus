import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lupus_care/data/api/token_expiration_handler.dart';
import 'package:lupus_care/helper/route_helper.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/views/chat_screen/chat_controller.dart';
import 'package:lupus_care/views/chat_screen/notification_service.dart';
import 'package:lupus_care/views/home/tab_refresh_service.dart';
import 'package:lupus_care/views/login/login_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done
  await Firebase.initializeApp();

  print('📨 Background message received: ${message.notification?.title}');
  print('📨 Background message data: ${message.data}');

  // Handle background message
  // You can show local notification here if needed
  // Note: This runs in a separate isolate, so you can't access app state
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 === STARTING LUPUS CARE APP ===');
  print('🚀 Time: ${DateTime.now()}');

  // Lock app to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase with better error handling
  print('🔥 Initializing Firebase...');
  try {
    await _initializeFirebase();

    // CRITICAL: Set background message handler BEFORE any other Firebase operations
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('✅ Firebase background message handler set');
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    Get.put(NotificationService(), permanent: true);
    Get.put(ChatController(), permanent: true);
    await initializeServices();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    // You can choose to continue without Firebase or show an error
  }

  print('🚀 Starting MyApp widget...');
  runApp(const MyApp());
}

Future<void> initializeServices() async {
  print('🚀 Initializing services...');

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.onInit();
  Get.put<NotificationService>(notificationService, permanent: true);

  print('✅ NotificationService initialized');
}

Future<void> _initializeFirebase() async {
  try {
    // Try to initialize Firebase normally first
    await Firebase.initializeApp();
  } catch (e) {
    print('⚠️ Normal Firebase initialization failed: $e');

    // If normal initialization fails, try with manual configuration
    if (Platform.isIOS) {
      print('🍎 Attempting iOS Firebase initialization with options...');
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          // Replace these with your actual Firebase project values
          apiKey: 'your-ios-api-key',
          appId: 'your-ios-app-id',
          messagingSenderId: 'your-sender-id',
          projectId: 'your-project-id',
          storageBucket: 'your-storage-bucket',
          // For iOS, these are typically required
          iosClientId: 'your-ios-client-id',
          iosBundleId: 'your-bundle-id',
        ),
      );
    } else {
      print('🤖 Attempting Android Firebase initialization...');
      // Android should work with google-services.json, but you can add options here too
      rethrow;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building MyApp widget');
    return GetMaterialApp(
      title: 'LUPUS CARE',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [RouteObserver()],
      initialRoute: '/initializer',
      getPages: [
        GetPage(
          name: '/initializer',
          page: () {
            print('🏗️ Creating AppInitializer page');
            return const AppInitializer();
          },
        ),
        ...AppRoutes.routes,
      ],
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() {
    print('🏗️ Creating AppInitializer state');
    return _AppInitializerState();
  }
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitializing = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasNavigated = false;
  String _initializationStatus = 'Starting...';

  @override
  void initState() {
    super.initState();
    print('🏗️ AppInitializer initState called');
    _initializeApp();
    Get.put(TabRefreshService(), permanent: true);
  }

  Future<void> _initializeApp() async {
    if (_hasNavigated) return;

    try {
      print('⚙️ === STARTING APP INITIALIZATION ===');

      setState(() {
        _initializationStatus = 'Checking Firebase connection...';
      });

      // Check Firebase connection
      await _verifyFirebaseConnection();

      setState(() {
        _initializationStatus = 'Initializing storage...';
      });

      // Initialize Storage Service
      await _initializeStorageService();

      setState(() {
        _initializationStatus = 'Initializing security monitoring...';
      });

      // Initialize Token Expiration Handler AFTER StorageService
      await _initializeTokenExpirationHandler();

      setState(() {
        _initializationStatus = 'Checking user state...';
      });

      final storageService = Get.find<StorageService>();

      // Debug current state
      print('🔍 === NAVIGATION DECISION LOGIC ===');
      storageService.printStorageInfo();

      String initialRoute = await _determineInitialRoute(storageService);

      if (!_hasNavigated) {
        _hasNavigated = true;
        Get.offAllNamed(initialRoute);
      }
    } catch (e, stackTrace) {
      print('❌ === INITIALIZATION ERROR ===');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');

      if (e is PlatformException || e.toString().contains('GoogleSignIn')) {
        print('🔧 Attempting auth recovery...');
        await _clearAuthCache();
        await Future.delayed(Duration(seconds: 1));
        if (!_hasNavigated) {
          _hasNavigated = true;
          Get.offAllNamed('/login');
        }
        return;
      }

      if (!_hasNavigated) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = 'Initialization failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _verifyFirebaseConnection() async {
    try {
      print('🔥 Verifying Firebase connection...');

      // Try to access Firebase services to verify connection
      final auth = FirebaseAuth.instance;
      print('✅ Firebase Auth accessible');

      // You can add more verification here if needed
    } catch (e) {
      print('❌ Firebase connection verification failed: $e');
      throw Exception('Firebase connection failed: $e');
    }
  }

  Future<String> _determineInitialRoute(StorageService storageService) async {
    print('🎯 === DETERMINING INITIAL ROUTE ===');

    // First check if user is logged in
    if (storageService.isFullyLoggedIn()) {
      final userData = storageService.getUser();
      final userId = userData?['id']?.toString();

      if (userId == null) {
        return '/login';
      }
      final lastRoute = storageService.getLastRoute();

      // Check if user needs to complete profile
      if (!storageService.hasCompletedProfile() &&
          (lastRoute != '/home') &&
          (lastRoute == '/createProfile')) {
        // Add this condition
        print('🔍 Profile not completed - redirecting to profile creation');
        return '/createProfile';
      }

      // Check subscription status if needed
      if (!storageService.hasActiveSubscription() && (lastRoute != '/home')) {
        print('🔍 No active subscription - redirecting to subscription');
        return '/subscription';
      }

      // if (lastRoute == '/profile' || lastRoute == '/subscription' || lastRoute == '/home') {
      //   print('✅ Valid last route found - redirecting to $lastRoute');
      //   return lastRoute;
      // }

      print('ℹ️ No valid last route found - defaulting to home');
      return '/home';
    }

    // For non-logged in users, proceed with normal flow
    final hasUsedAppBefore = storageService.hasUsedAppBefore();
    final hasCompletedOnboarding = storageService.hasCompletedOnboarding();

    if (!hasUsedAppBefore && !hasCompletedOnboarding) {
      print('🔍 New user - redirecting to onboarding');
      return '/onboarding';
    } else {
      print('🔍 Returning user - redirecting to login');
      return '/login';
    }
  }

  Future<void> _clearAuthCache({bool preserveUserData = false}) async {
    try {
      print('🧹 Starting auth cleanup process...');
      print('   - Preserve user data: $preserveUserData');

      // Stop token monitoring before clearing auth
      try {
        if (Get.isRegistered<TokenExpirationHandler>()) {
          final tokenHandler = Get.find<TokenExpirationHandler>();
          tokenHandler.pauseMonitoring();
          print('🕐 Token monitoring paused during auth cleanup');
        }
      } catch (e) {
        print('⚠️ Error pausing token monitoring: $e');
      }

      // 1. First sign out from Firebase (with error handling)
      try {
        await FirebaseAuth.instance.signOut();
        print('✅ Firebase auth signed out successfully');
      } catch (e) {
        print('⚠️ Firebase signout error: $e');
      }

      // 2. Clear local storage based on preservation option
      try {
        final storageService = Get.find<StorageService>();

        if (preserveUserData) {
          // Smart logout that preserves progress
          await storageService.logoutPreservingProgress();
          print('✅ Local auth storage cleared (progress preserved)');
        } else {
          // Complete clear
          await storageService.clearAll();
          print('✅ Local auth storage cleared completely');
        }
      } catch (e) {
        print('⚠️ Storage clear error: $e');
      }

      print('🧹 Auth cleanup completed');
    } catch (e) {
      print('⚠️ General auth cleanup error: $e');
    }
  }

  Future<void> _initializeStorageService() async {
    try {
      print('📱 Initializing StorageService...');

      if (!Get.isRegistered<StorageService>()) {
        final storageService = StorageService();
        await storageService.init();
        Get.put<StorageService>(storageService, permanent: true);
        print('✅ StorageService initialized successfully');
      } else {
        print('✅ StorageService already registered');
      }
    } catch (e) {
      print('❌ StorageService initialization failed: $e');
      print('🚨 Using emergency storage service');

      final emergencyService = EmergencyStorageService();
      await emergencyService.init();
      Get.put<StorageService>(emergencyService, permanent: true);
    }
  }

  Future<void> _initializeTokenExpirationHandler() async {
    try {
      print('🕐 Initializing TokenExpirationHandler...');

      if (!Get.isRegistered<TokenExpirationHandler>()) {
        final tokenHandler = TokenExpirationHandler();
        Get.put<TokenExpirationHandler>(tokenHandler, permanent: true);
        print('✅ TokenExpirationHandler initialized successfully');

        final storageService = Get.find<StorageService>();
        if (storageService.isLoggedIn()) {
          print(
              '🕐 User is logged in - token monitoring will start automatically');
        } else {
          print(
              '🕐 No user logged in - token monitoring will start after login');
        }
      } else {
        print('✅ TokenExpirationHandler already registered');
      }
    } catch (e) {
      print('❌ TokenExpirationHandler initialization failed: $e');
      print('⚠️ App will continue without automatic token expiration handling');
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        '🏗️ Building AppInitializer UI (navigated: $_hasNavigated, error: $_hasError, initializing: $_isInitializing)');

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'App Initialization Failed',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _isInitializing = true;
                      _hasNavigated = false;
                      _initializationStatus = 'Retrying...';
                    });
                    _initializeApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(CustomColors.purpleColor),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _initializationStatus,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    print(
        '⚠️ WARNING: AppInitializer build reached end - this should not happen');
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Initializing...',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// Emergency storage service (unchanged)
class EmergencyStorageService extends StorageService {
  final Map<String, dynamic> _storage = {};

  @override
  bool get isInitialized => true;

  @override
  String get storageType => 'Emergency Memory Storage';

  @override
  Future<StorageService> init() async {
    print("🚨 Emergency storage initialized");
    return this;
  }

  @override
  Future<bool> saveUser(Map<String, dynamic> userData) async {
    _storage['user_data'] = userData;
    _storage['is_logged_in'] = true;
    return true;
  }

  @override
  Future<bool> saveToken(String token) async {
    _storage['auth_token'] = token;
    return true;
  }

  @override
  Map<String, dynamic>? getUser() {
    return _storage['user_data'] as Map<String, dynamic>?;
  }

  @override
  String? getToken() {
    return _storage['auth_token'] as String?;
  }

  @override
  bool isLoggedIn() {
    return _storage['is_logged_in'] == true &&
        getUser() != null &&
        getToken() != null;
  }

  @override
  bool hasKey(String key) {
    return _storage.containsKey(key);
  }

  @override
  List<String> getAllKeys() {
    return _storage.keys.toList();
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }

  @override
  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }

  @override
  Future<bool> markFirstInstallComplete() async {
    _storage['first_install_complete'] = true;
    return true;
  }
}

class RouteObserver extends GetObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _saveCurrentRoute(route.settings.name);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _saveCurrentRoute(newRoute.settings.name);
    }
  }

  void _saveCurrentRoute(String? routeName) {
    if (routeName != null &&
        (routeName == '/home' ||
            routeName == '/createProfile' ||
            routeName == '/subscription')) {
      final storageService = Get.find<StorageService>();
      storageService.saveLastRoute(routeName);
      print('💾 Saved current route: $routeName');
    }
  }
}
