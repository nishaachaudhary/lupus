import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lupus_care/views/onboarding/onboading_screen.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false; // Prevent multiple navigations

  @override
  void initState() {
    super.initState();
    print('🎬 === SPLASH SCREEN STARTED ===');

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    _handleSplashNavigation();
  }

  Future<void> _handleSplashNavigation() async {
    try {
      print('🎬 Lupus Care Splash Screen started');
      print('⏰ Displaying splash for 5 seconds...');


      await Future.delayed(Duration(seconds: 40));

      print('⏰ 5-second splash delay completed, navigating to initializer...');

      // Check if widget is still mounted and hasn't navigated yet
      if (mounted && !_hasNavigated) {
        _navigateToInitializer();
      } else {
        print('⚠️ Widget unmounted or already navigated, skipping navigation');
      }

    } catch (e) {
      print('❌ Error in splash navigation: $e');
      // Fallback to initializer if there's an error
      if (mounted && !_hasNavigated) {
        _navigateToInitializer();
      }
    }
  }

  void _navigateToInitializer() {
    try {
      if (_hasNavigated) {
        print('⚠️ Navigation already attempted, skipping...');
        return;
      }

      _hasNavigated = true; // Mark as navigated to prevent multiple calls
      print('🚀 Navigating to App Initializer...');

      if (mounted) {
        // Use Get.offAllNamed to clear all previous routes
        Get.offAllNamed('/initializer');
        print('✅ Navigation to initializer completed');
      } else {
        print('⚠️ Widget not mounted, cannot navigate');
      }
    } catch (e) {
      print('❌ Error navigating to initializer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Building Splash Screen UI');

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF943ED2), // Top: Purple
                Color(0xFF623284), // Bottom: Dark Purple
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Company logo with hero animation for smoother transition
                  Hero(
                    tag: 'company_logo',
                    child: Image.asset(
                      CustomImage.companyLogo,
                      height: 205,
                      width: 304,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Loading indicator with animation
                  SizedBox(height: 40),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7)
                      ),
                    ),
                  ),

                  // App name and version
                  SizedBox(height: 20),
                  Text(
                    'Lupus Care',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.2,
                    ),
                  ),

                  // Optional: Add a subtle loading message
                  SizedBox(height: 8),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    print('🎬 Splash Screen disposed');
    super.dispose();
  }
}