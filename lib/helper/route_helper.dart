import 'package:get/get.dart';
import 'package:lupus_care/helper/create_profile_binding.dart';
import 'package:lupus_care/views/add_medication/add_medication_screen.dart';
import 'package:lupus_care/views/add_members/add_member_screen.dart';
import 'package:lupus_care/views/chat_screen/community_chat_screen.dart';
import 'package:lupus_care/views/create_new_password/create_new_password_screen.dart';
import 'package:lupus_care/views/create_profile/create_profile_screen.dart';
import 'package:lupus_care/views/edit_medication/edit_medication_screen.dart';
import 'package:lupus_care/views/edit_profile/edit_profile_screen.dart';
import 'package:lupus_care/views/forget_password/forget_password_screen.dart';
import 'package:lupus_care/views/home/home_screen.dart';
import 'package:lupus_care/views/login/login_screen.dart';
import 'package:lupus_care/views/medication_tracker/medication_tracker_screen.dart';
import 'package:lupus_care/views/my_report/my_report_screen.dart';
import 'package:lupus_care/views/onboarding/onboading_screen.dart';
import 'package:lupus_care/views/onboarding/splash_screen.dart';
import 'package:lupus_care/views/otp_verification/otp_verification_screen.dart';
import 'package:lupus_care/views/report/report_detail_screen.dart';
import 'package:lupus_care/views/sign_in/sign_in_screen.dart';
import 'package:lupus_care/views/subscription/membership_sucess_screen.dart';
import 'package:lupus_care/views/subscription/subscription_screen.dart';
import 'package:lupus_care/views/add_symptoms/add_new_symptom.dart';
import 'package:lupus_care/views/symptom/symptoms_screen.dart';
import 'package:lupus_care/views/view_member/view_member_screen.dart';

class AppRoutes {
  static final routes = [
    // FIXED: Main splash/login screen - this should be the landing page for returning users
    GetPage(
      name: '/',
      page: () => SplashScreen(), // or LoginScreen() if SplashScreen handles login
    ),

    // AUTHENTICATION FLOW
    GetPage(
      name: '/onboarding',
      page: () => OnboardingScreen(),
    ),
    GetPage(
      name: '/login',
      page: () => LoginScreen(),
    ),
    GetPage(
      name: '/signup',
      page: () => SignupScreen(),
    ),
    GetPage(
      name: '/forgetPassword',
      page: () => ForgotPasswordScreen(),
    ),
    GetPage(
      name: '/otpVerification',
      page: () => OtpScreen(),
    ),
    GetPage(
      name: '/resetPassword',
      page: () => ResetPasswordScreen(),
    ),

    // ONBOARDING FLOW
    GetPage(
      name: '/createProfile',
      page: () => CreateProfileScreen(),
      binding: CreateProfileBinding(), // Keep the binding here
    ),

    GetPage(
      name: '/editMedication',
      page: () => EditMedicationScreen(),

    ),

    // SUBSCRIPTION FLOW
    GetPage(
      name: '/subscription',
      page: () => SubscriptionScreen(),
    ),
    GetPage(
      name: '/subscriptionSuccess',
      page: () => SubscriptionSuccessScreen(),
    ),

    // MAIN APP SCREENS
    GetPage(
      name: '/home',
      page: () => HomeScreen(),
    ),
    GetPage(
      name: '/editProfile',
      page: () => EditProfileScreen(),
    ),

    // FEATURE SCREENS
    GetPage(
      name: '/newLog',
      page: () => AddNewLogScreen(),
    ),
    GetPage(
      name: '/medication',
      page: () => MedicationTrackerScreen(),
    ),
    GetPage(
      name: '/symptom',
      page: () => SymptomScreen(),
    ),
    GetPage(
      name: '/chat',
      page: () => CommunityChatScreen(),
    ),
    GetPage(
      name: '/addMedication',
      page: () => AddMedicationScreen(),
    ),
    GetPage(
      name: '/addMember',
      page: () => AddMembersScreen(),
    ),
    // GetPage(
    //   name: '/viewMember',
    //   page: () => ViewMemberScreen(),
    // ),

    // REPORTS
    GetPage(
      name: '/insightReport',
      page: () => InsightReportScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: '/report',
      page: () => MyReportsScreen(),
      transition: Transition.rightToLeft,
    ),
  ];
}

