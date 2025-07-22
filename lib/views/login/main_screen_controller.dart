// Final MainScreenController with tab refresh functionality
import 'package:get/get.dart';
import 'package:lupus_care/views/home/tab_refresh_service.dart';

class MainScreenController extends GetxController {
  var selectedIndex = 0.obs;

  void changeTabIndex(int index) {
    final oldIndex = selectedIndex.value;
    selectedIndex.value = index;

    print("🔄 Tab changed from $oldIndex to $index");

    // Trigger tab refresh through service
    if (Get.isRegistered<TabRefreshService>()) {
      TabRefreshService.to.onTabChanged(index, oldIndex);
    }
  }

  // Method to force refresh current tab
  void refreshCurrentTab() {
    if (Get.isRegistered<TabRefreshService>()) {
      TabRefreshService.to.forceRefreshTab(selectedIndex.value);
    }
  }

  // Method to force refresh all tabs
  void refreshAllTabs() {
    if (Get.isRegistered<TabRefreshService>()) {
      TabRefreshService.to.forceRefreshAllTabs();
    }
  }

  // Method to go to a specific tab and refresh it
  void goToTabAndRefresh(int tabIndex) {
    changeTabIndex(tabIndex);
    if (Get.isRegistered<TabRefreshService>()) {
      TabRefreshService.to.forceRefreshTab(tabIndex);
    }
  }
}