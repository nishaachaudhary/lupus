import 'package:flutter/material.dart';
import 'package:lupus_care/data/model/view_user_model.dart';
import 'package:lupus_care/constant/dimension.dart';
import 'package:lupus_care/constant/images.dart';
import 'package:lupus_care/style/colors.dart';
import 'package:lupus_care/style/styles.dart';

class MemberItem extends StatelessWidget {
  final ViewMember member;
  final VoidCallback? onTap;

  const MemberItem({
    Key? key,
    required this.member,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.only(left:Dimensions.paddingSizeDefault,right: Dimensions.paddingSizeDefault,top: Dimensions.paddingSizeDefault),

          child: Row(
            children: [
              // Avatar
              buildAvatar(),
              const SizedBox(width: Dimensions.paddingSizeDefault),

              // Member Info
              Expanded(
                child: buildMemberInfo(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: ClipOval(
            child: member.avatarUrl.isNotEmpty
                ? Image.network(
              member.avatarUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return buildDefaultAvatar();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return buildDefaultAvatar();
              },
            )
                : buildDefaultAvatar(),
          ),
        ),
      ],
    );
  }

  Widget buildDefaultAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CustomColors.lightPurpleColor,
      ),
      child: Center(
        child: Text(
          getInitials(member.name),
          style: TextStyle(
            color: CustomColors.purpleColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String getInitials(String name) {
    List<String> names = name.trim().split(' ');
    if (names.isEmpty) return 'U';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }

  Widget buildMemberInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        Text(
          member.name,
          style: mediumStyle.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

      ],
    );
  }
}