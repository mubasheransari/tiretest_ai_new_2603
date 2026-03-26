import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Models/bottom_tab.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.active,
    required this.onChanged,
  });

  final BottomTab active;
  final ValueChanged<BottomTab> onChanged;

  @override
  Widget build(BuildContext context) {
    // your existing UI...
    // call onChanged(BottomTab.reports) etc.
    return Container();
  }
}
