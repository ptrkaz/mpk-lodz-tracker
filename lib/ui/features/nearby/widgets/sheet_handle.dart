import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: LodzSpacing.sm),
      decoration: BoxDecoration(
        color: LodzColors.outlineVariant,
        borderRadius: BorderRadius.circular(LodzRadius.full),
      ),
    );
  }
}
