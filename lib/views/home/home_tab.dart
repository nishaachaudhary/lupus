// Updated HomeTab with proper refresh logic and image priority support
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/helper/storage_service.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/home/home_controller.dart';
import 'package:lupus_care/views/login/main_screen_controller.dart';
import 'package:lupus_care/views/profile_screen/profile_controller.dart';
import 'feature_card_widget.dart';
import 'medication_reminder_widget.dart';
import 'dart:io';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  late final HomeController homeController;
  late final MainScreenController mainController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    homeController = Get.put(HomeController());
    mainController = Get.find<MainScreenController>();

    // Listen to tab changes to refresh when this tab becomes active
    mainController.selectedIndex.listen((index) {
      if (index == 0 && mounted) { // Home tab index is 0
        print("🏠 Home tab became active - refreshing data");
        _refreshHomeData();
      }
    });

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storageService = Get.find<StorageService>();
      storageService.saveLastRoute('/home');
      print('🏠 Home screen initialized - route saved');
      _refreshHomeData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when tab becomes visible
    if (mainController.selectedIndex.value == 0) {
      print("🏠 Home tab dependencies changed - refreshing data");
      _refreshHomeData();
    }
  }

  void _refreshHomeData() {
    if (mounted) {
      print("🔄 Refreshing Home tab data");
      homeController.refreshProfile();
      homeController.refreshReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await homeController.forceRefresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Enhanced User greeting section with image priority support
                  Obx(() {
                    final displayName = homeController.displayName;
                    final truncatedName = displayName.length > 30
                        ? '${displayName.substring(0, 30)}...'
                        : displayName;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hi $truncatedName!",
                                style: semiBoldStyle.copyWith(
                                  fontSize: Dimensions.fontSizeOverLarge,
                                ),
                              ),
                              Text(
                                "How are you feeling today?",
                                style: semiLightStyle.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                  color: CustomColors.lightereColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ✅ Enhanced Profile Image with Local Support
                        _buildEnhancedProfileAvatar(),
                      ],
                    );
                  }),




                  const SizedBox(height: 16),

                  // Medication Reminder Widget
                  Obx(() {
                    if (homeController.isLoadingReminders.value) {
                      return _buildLoadingReminder();
                    } else if (homeController.hasUpcomingReminders) {
                      final reminder = homeController.nextReminder!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: MedicationReminderWidget(
                          medicationName: reminder['medication_name']?.toString() ?? 'Medication',
                          time: reminder['formatted_time']?.toString() ??
                              reminder['reminder_time']?.toString() ??
                              'Time',
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),

                  // Spacing
                  Obx(() => (homeController.hasUpcomingReminders || homeController.isLoadingReminders.value)
                      ? const SizedBox(height: 16)
                      : const SizedBox.shrink()),

                  // Feature section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Track, Manage & Connect",
                        style: semiBoldStyle.copyWith(
                          fontSize: Dimensions.fontSizeExtraLarge,
                          color: CustomColors.blackColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Feature Cards
                  FeatureCardWidget(
                    title: "Symptoms & Trigger Tracking",
                    buttonLabel: "Start Now",
                    color: CustomColors.homeColor,
                    leadingIcon: Image.asset(CustomImage.symptoms),
                    onTap: () {
                      Get.toNamed('/newLog');
                    },
                  ),
                  const SizedBox(height: 12),
                  FeatureCardWidget(
                    title: "Medication Tracker",
                    buttonLabel: "Start Now",
                    color: CustomColors.tintColor,
                    leadingIcon: Image.asset(CustomImage.medicalService),
                    onTap: () {
                      mainController.changeTabIndex(2);
                    },
                  ),
                  const SizedBox(height: 12),
                  FeatureCardWidget(
                    title: "Community Chat & Support",
                    buttonLabel: "Engage Now",
                    color: CustomColors.seaGreenColor,
                    leadingIcon: Image.asset(CustomImage.chatting),
                    onTap: () {
                      mainController.changeTabIndex(3);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Enhanced profile avatar widget with image priority logic
  Widget _buildEnhancedProfileAvatar() {
    return Obx(() {
      if (homeController.isLoading.value) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CustomColors.lightPurpleColor,
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: CustomColors.purpleColor,
              strokeWidth: 2,
            ),
          ),
        );
      }

      return Stack(
        children: [
          // Main profile avatar with enhanced logic
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: CustomColors.lightPurpleColor,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _buildEnhancedHomeProfileImage(),
            ),
          ),

          // Loading overlay for image operations
          if (homeController.isImageLoading.value)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.3),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 1,
                  ),
                ),
              ),
            ),



        ],
      );
    });
  }

  // ✅ Enhanced image widget with priority logic for Home screen
  Widget _buildEnhancedHomeProfileImage() {
    final displayPath = homeController.displayImagePath.value;

    print("🏠🖼️ Building home profile image with displayPath: $displayPath");
    print("🏠🖼️ Has API Image: ${homeController.hasApiImage.value}");
    print("🏠🖼️ Has Local Image: ${homeController.hasLocalImage.value}");

    // No image available - show default
    if (displayPath.isEmpty) {
      print("🏠🖼️ Using default avatar - no display path");
      return _buildDefaultHomeAvatar();
    }

    // Check if this is a local file path
    if (homeController.hasLocalImage.value && !displayPath.startsWith('http')) {
      print("🏠🖼️ Loading local image from: $displayPath");
      return _buildLocalHomeImage(displayPath);
    }

    // Check if this is an API image (URL)
    if (homeController.hasApiImage.value && displayPath.startsWith('http')) {
      print("🏠🖼️ Loading API image from: $displayPath");
      return _buildNetworkHomeImage(displayPath);
    }

    // Fallback to default
    print("🏠🖼️ Falling back to default avatar");
    return _buildDefaultHomeAvatar();
  }

  // Build local image widget for Home
  Widget _buildLocalHomeImage(String imagePath) {
    return Image.file(
      File(imagePath),
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print("🏠❌ Local image load error: $error");
        print("🏠❌ Attempted path: $imagePath");

        // Check if file exists
        final file = File(imagePath);
        print("🏠❌ File exists: ${file.existsSync()}");

        // Fallback to API image if available
        if (homeController.hasApiImage.value && homeController.profileImageUrl.value.isNotEmpty) {
          print("🏠🔄 Falling back to API image");
          return _buildNetworkHomeImage(homeController.profileImageUrl.value);
        }

        return _buildDefaultHomeAvatar();
      },
    );
  }

  // Build network image widget for Home
  Widget _buildNetworkHomeImage(String imageUrl) {
    return Image.network(
      imageUrl,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildImageLoadingIndicator();
      },
      errorBuilder: (context, error, stackTrace) {
        print("🏠❌ Network image load error: $error");
        print("🏠❌ Attempted URL: $imageUrl");

        // Fallback to local image if available
        if (homeController.hasLocalImage.value && homeController.localImagePath.value.isNotEmpty) {
          print("🏠🔄 Falling back to local image");
          return _buildLocalHomeImage(homeController.localImagePath.value);
        }

        return _buildDefaultHomeAvatar();
      },
    );
  }

  // Default avatar widget for Home screen
  Widget _buildDefaultHomeAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CustomColors.purpleColor, CustomColors.lightPurpleColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          homeController.displayName.isNotEmpty
              ? homeController.displayName[0].toUpperCase()
              : 'U',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Image loading indicator for Home
  Widget _buildImageLoadingIndicator() {
    return Container(
      width: 48,
      height: 48,
      color: CustomColors.lightPurpleColor.withOpacity(0.3),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 1,
          color: CustomColors.purpleColor,
        ),
      ),
    );
  }

  // ✅ Debug section for Home screen (remove in production)
  Widget _buildHomeDebugSection() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home, color: Colors.blue[700], size: 16),
              SizedBox(width: 6),
              Text(
                "Home Debug (Dev Only)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),

          // Current Status Display
          Obx(() => Text(
            "Image: ${homeController.bestImageSource} | "
                "Path: ${homeController.displayImagePath.value.isEmpty ? 'EMPTY' : homeController.displayImagePath.value.substring(0, 20)}... | "
                "Loading: ${homeController.isImageLoading.value ? 'YES' : 'NO'}",
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue[600],
              fontFamily: 'monospace',
            ),
          )),

          SizedBox(height: 4),

          // Debug Action Buttons
          Row(
            children: [
              InkWell(
                onTap: () => homeController.debugHomeImageStatus(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Debug",
                    style: TextStyle(fontSize: 10, color: Colors.blue[800]),
                  ),
                ),
              ),
              SizedBox(width: 6),
              InkWell(
                onTap: () => homeController.refreshProfile(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Refresh",
                    style: TextStyle(fontSize: 10, color: Colors.green[800]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingReminder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD794CD),
              offset: const Offset(0, 4.21),
              blurRadius: 26.32,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            CircularProgressIndicator(
              color: CustomColors.homeColor,
              strokeWidth: 2,
            ),
            const SizedBox(width: 12),
            Text(
              "Loading reminders...",
              style: TextStyle(
                color: CustomColors.blackColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}