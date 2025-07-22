import 'package:get/get.dart';
import 'package:lupus_care/views/create_profile/create_profile_controller.dart';



class CreateProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(CreateProfileController());
  }
}
