import 'package:flutter/material.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/style/styles.dart';

class FeatureCardWidget extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;
  final Widget? leadingIcon;

  const FeatureCardWidget({
    super.key,
    required this.title,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Text and button section
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: mediumStyle.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                    onPressed: onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonLabel,
                          style: semiBoldStyle.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: Colors.black,
                          ),
                        ),
                        Transform.rotate(
                          angle: 45 * 3.1416 / 180,
                          child: const Icon(
                            Icons.arrow_upward,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Image section
          if (leadingIcon != null) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: leadingIcon!,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}