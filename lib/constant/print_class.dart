import 'package:flutter/material.dart';

class PrintClass {
  void showInitialization(String initializingMsg) {
    debugPrint('\x1B[32m✅ $initializingMsg!\x1B[0m');
  }

  void showError(String error) {
    debugPrint('\x1B[31m❌ $error\x1B[0m');
  }
}
