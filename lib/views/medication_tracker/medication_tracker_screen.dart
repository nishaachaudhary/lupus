// views/medication_tracker/medication_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/login/main_screen_controller.dart';
import 'package:lupus_care/views/medication_tracker/medication_card.dart';
import 'package:lupus_care/views/medication_tracker/medication_filter_chips.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_controller.dart';
import 'package:lupus_care/views/medication_tracker/search_bar_widget.dart';

class MedicationTrackerScreen extends StatefulWidget {
  @override
  _MedicationTrackerScreenState createState() => _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState extends State<MedicationTrackerScreen> {
  late MedicationController controller;
  late MainScreenController mainController;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    if (Get.isRegistered<MedicationController>()) {
      Get.delete<MedicationController>();
    }
    controller = Get.put(MedicationController());
    mainController = Get.find<MainScreenController>();

    // Listen to tab changes to refresh when this tab becomes active
    mainController.selectedIndex.listen((index) {
      if (index == 2 && mounted) { // Medication tab index is 2
        print("💊 Medication tab became active - refreshing data");
        _refreshMedicationData();
      }
    });

    // Initial setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshMedicationData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when tab becomes visible
    if (mainController.selectedIndex.value == 2) {
      print("💊 Medication tab dependencies changed - refreshing data");
      _refreshMedicationData();
    }
  }

  void _refreshMedicationData() {
    if (mounted) {
      print("🔄 Refreshing Medication tab data");
      controller.resetToAllMedications();
      controller.refreshMedications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Medication Tracker',
          style: mediumStyle.copyWith(fontSize: Dimensions.fontSizeOverLarge),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchBarWidget(),
              const SizedBox(height: 16),
              // Make filter chips scrollable horizontally
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: MedicationFilterChips(),
              ),
              const SizedBox(height: 24),
              Obx(() => Text(
                controller.selectedMedication.value,
                style: mediumStyle.copyWith(fontSize: Dimensions.fontSizeExtraLarge),
              )),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  // Show loading indicator
                  if (controller.isLoading.value && controller.medications.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  // Show error message if there's an error and no data
                  if (controller.errorMessage.value.isNotEmpty && controller.medications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            controller.errorMessage.value,
                            style: semiLightStyle.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: controller.refreshMedications,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CustomColors.purpleColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              "Retry",
                              style: mediumStyle.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final meds = controller.filteredMedications;

                  // Show empty state if no medications
                  if (meds.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medication_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            controller.medications.isEmpty
                                ? "No medications found"
                                : "No medications match your search",
                            style: mediumStyle.copyWith(
                              fontSize: Dimensions.fontSizeExtraLarge,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            controller.medications.isEmpty
                                ? "Start by adding your first medication"
                                : "Try adjusting your search or filter",
                            style: semiLightStyle.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Show medications with pull-to-refresh
                  return RefreshIndicator(
                    onRefresh: controller.refreshMedications,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: meds.length,
                      itemBuilder: (context, index) {
                        final med = meds[index];
                        return MedicationCard(medication: med);
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CustomColors.purpleColor,
        shape: const CircleBorder(),
        child: Image.asset(
          CustomImage.add,
          height: 30,
          width: 30,
        ),
        onPressed: () => Get.toNamed('/addMedication')?.then((_) {
          // Refresh medications when returning from Add Medication screen
          controller.refreshMedications();
        }),
      ),
    );
  }
}