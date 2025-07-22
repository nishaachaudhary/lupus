// Create a new file: lib/mixins/tab_refresh_mixin.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/views/login/main_screen_controller.dart';

mixin TabRefreshMixin<T extends StatefulWidget> on State<T> {
  late MainScreenController _mainController;
  int? _currentTabIndex;
  int? get tabIndex;

  @override
  void initState() {
    super.initState();
    _mainController = Get.find<MainScreenController>();
    _currentTabIndex = _mainController.selectedIndex.value;

    // Listen to tab changes
    _mainController.selectedIndex.listen((index) {
      _handleTabChange(index);
    });
  }

  void _handleTabChange(int newIndex) {
    final oldIndex = _currentTabIndex;
    _currentTabIndex = newIndex;

    // If this tab is now active and was previously inactive, refresh
    if (newIndex == tabIndex && oldIndex != newIndex) {
      print("🔄 Tab $newIndex became active - triggering refresh");
      onTabBecameActive();
    }
  }

  // Override this method in your tab widgets
  void onTabBecameActive() {
    // To be implemented by each tab
  }

  // Helper method to check if this tab is currently active
  bool get isCurrentTab => _mainController.selectedIndex.value == tabIndex;
}