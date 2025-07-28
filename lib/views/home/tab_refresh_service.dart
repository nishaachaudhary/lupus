// Create a new file: lib/services/tab_refresh_service.dart
import 'package:get/get.dart';
import 'package:lupus_care/views/home/home_controller.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_controller.dart';

class TabRefreshService extends GetxService {
  static TabRefreshService get to => Get.find();

  // Track the last active tab
  int _lastActiveTab = 0;

  // Track tab refresh timestamps to avoid excessive refreshes
  final Map<int, DateTime> _lastRefreshTimes = {};

  // Minimum time between refreshes (in milliseconds)
  static const int MIN_REFRESH_INTERVAL = 2000;

  void onTabChanged(int newTabIndex, int oldTabIndex) {
    _lastActiveTab = newTabIndex;

    // Check if enough time has passed since last refresh
    if (_shouldRefreshTab(newTabIndex)) {
      _refreshTab(newTabIndex);
      _lastRefreshTimes[newTabIndex] = DateTime.now();
    }
  }

  bool _shouldRefreshTab(int tabIndex) {
    if (!_lastRefreshTimes.containsKey(tabIndex)) {
      return true;
    }

    final lastRefresh = _lastRefreshTimes[tabIndex]!;
    final timeSinceRefresh =
        DateTime.now().difference(lastRefresh).inMilliseconds;

    return timeSinceRefresh > MIN_REFRESH_INTERVAL;
  }

  void _refreshTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        _refreshHomeTab();
        break;
      case 1:
        _refreshSymptomsTab();
        break;
      case 2:
        _refreshMedicationTab();
        break;
      case 3:
        _refreshChatTab();
        break;
      case 4:
        _refreshProfileTab();
        break;
    }
  }

  void _refreshHomeTab() {
    try {
      if (Get.isRegistered<HomeController>()) {
        final controller = Get.find<HomeController>();
        controller.refreshProfile();
        controller.refreshReminders();
      }
    } catch (e) {}
  }

  void _refreshSymptomsTab() {
    try {
      // Add symptoms controller refresh logic here
    } catch (e) {}
  }

  void _refreshMedicationTab() {
    try {
      if (Get.isRegistered<MedicationController>()) {
        final controller = Get.find<MedicationController>();
        controller.refreshMedications();
        controller.resetToAllMedications();
      }
    } catch (e) {}
  }

  void _refreshChatTab() {
    try {
      // Add chat controller refresh logic here
    } catch (e) {}
  }

  void _refreshProfileTab() {
    try {
      // Add profile controller refresh logic here
    } catch (e) {}
  }

  // Force refresh a specific tab
  void forceRefreshTab(int tabIndex) {
    _refreshTab(tabIndex);
    _lastRefreshTimes[tabIndex] = DateTime.now();
  }

  // Force refresh all tabs
  void forceRefreshAllTabs() {
    for (int i = 0; i < 5; i++) {
      _refreshTab(i);
      _lastRefreshTimes[i] = DateTime.now();
    }
  }

  // Get the last active tab
  int get lastActiveTab => _lastActiveTab;

  // Check if a tab was recently refreshed
  bool wasRecentlyRefreshed(int tabIndex) {
    if (!_lastRefreshTimes.containsKey(tabIndex)) {
      return false;
    }

    final lastRefresh = _lastRefreshTimes[tabIndex]!;
    final timeSinceRefresh =
        DateTime.now().difference(lastRefresh).inMilliseconds;

    return timeSinceRefresh < MIN_REFRESH_INTERVAL;
  }
}
