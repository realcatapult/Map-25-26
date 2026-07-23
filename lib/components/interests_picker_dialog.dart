import 'package:flutter/material.dart';
import 'package:login_ui/data/interests_catalog.dart';
import 'package:login_ui/theme/app_theme.dart';

Future<List<String>?> showInterestsPickerDialog(
  BuildContext context, {
  required List<String> initialSelection,
  bool isOnboarding = false,
}) {
  final selected = {...InterestsCatalog.normalize(initialSelection)};
  const featuredInterests = [
    'STEM',
    'Math',
    'Chemistry',
    'English',
    'Reading',
    'Law',
    'Culture',
    'AI',
  ];

  return showDialog<List<String>>(
    context: context,
    barrierDismissible: !isOnboarding,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: AppColors.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brass.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -10,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brassLight.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Pick Your Interests',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isOnboarding
                              ? 'Choose topics you care about so we can recommend clubs that fit you.'
                              : 'Update what you are into. Recommendations refresh instantly.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: featuredInterests.map((word) {
                            final isSelected = selected.contains(word);
                            return ChoiceChip(
                              label: Text(
                                word,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.navy
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: isSelected,
                              backgroundColor: AppColors.navyMid,
                              selectedColor: AppColors.brass,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.brass
                                    : Colors.white.withValues(alpha: 0.55),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              onSelected: (nextValue) {
                                setDialogState(() {
                                  if (nextValue) {
                                    selected.add(word);
                                  } else {
                                    selected.remove(word);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: InterestsCatalog.all
                                .where((interest) =>
                                    !featuredInterests.contains(interest))
                                .map((interest) {
                              final isSelected = selected.contains(interest);
                              return ChoiceChip(
                                label: Text(
                                  interest,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.navy
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                backgroundColor: AppColors.navyMid,
                                selectedColor: AppColors.brass,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.brass
                                      : Colors.white.withValues(alpha: 0.55),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                onSelected: (nextValue) {
                                  setDialogState(() {
                                    if (nextValue) {
                                      selected.add(interest);
                                    } else {
                                      selected.remove(interest);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${selected.length} selected',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!isOnboarding)
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                              ElevatedButton.icon(
                                onPressed: selected.isEmpty
                                    ? null
                                    : () => Navigator.pop(
                                          context,
                                          selected.toList()..sort(),
                                        ),
                                icon: const Icon(Icons.check),
                                label: Text(
                                  isOnboarding ? 'Save & Continue' : 'Save',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brass,
                                  foregroundColor: AppColors.navy,
                                  disabledBackgroundColor: Colors.white24,
                                  disabledForegroundColor: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
