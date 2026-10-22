import 'package:flutter/material.dart';
import 'package:medi_assist/core/constants/app_colors.dart';
import 'package:get/get.dart';


class PermissionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const PermissionBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withOpacity(0.15),
              AppColors.accent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warning.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'permissions_required'.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'permissions_required_detail'.tr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.warning,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}