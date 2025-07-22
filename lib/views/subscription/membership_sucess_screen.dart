import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';
import 'package:lupus_care/views/subscription/subscription_controller.dart';




class SubscriptionSuccessScreen extends StatelessWidget {
  // final SubscriptionController controller = Get.put(SubscriptionController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6EEFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                CustomImage.activate,
                width: 250,
                height: 200,
                fit: BoxFit.contain,
              ),

              SizedBox(height: 35),
              Text(
                  "Subscription Activated!",
                  textAlign: TextAlign.center,
                  style: boldStyle.copyWith(
                      fontSize: 28,
                      color: CustomColors.subscribeColor
                  )
              ),
              SizedBox(height: 24),
              Text(
                  "🎉 Thank you for subscribing!",
                  textAlign: TextAlign.center,
                  style: boldStyle.copyWith(
                    fontSize: Dimensions.fontSizeExtraLarge,

                  )
              ),
              SizedBox(height: 8),
              Text(
                  "You now have full access to all premium features.Start exploring and make the most of your experience!",
                  textAlign: TextAlign.center,
                  style: semiLightStyle.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: CustomColors.blackColor
                  )
              ),
              SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (){
                    Get.offAllNamed('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColors.greenColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text("Continue",
                      style: semiBoldStyle.copyWith(
                          fontSize: Dimensions.fontSizeExtraLarge,
                          color: CustomColors.darkGreenColor
                      )),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
