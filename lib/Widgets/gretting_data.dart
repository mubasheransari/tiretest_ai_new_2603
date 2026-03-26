import 'package:flutter/material.dart';

class GreetingData {
  final String text;
  final IconData icon;
  final Color iconColor;
  const GreetingData(this.text, this.icon, this.iconColor);
}

GreetingData getGreeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;

  if (h >= 5 && h < 12) {
    return const GreetingData('Good morning', Icons.wb_sunny_rounded, Color(0xFFFFB300));
  } else if (h >= 12 && h < 17) {
    return const GreetingData('Good afternoon', Icons.light_mode_rounded, Color(0xFFFFA000));
  } else if (h >= 17 && h < 21) {
    return const GreetingData('Good evening', Icons.wb_twilight_rounded, Color(0xFF7C3AED));
  } else {
    return const GreetingData('Good night', Icons.nights_stay_rounded, Color(0xFF2563EB));
  }
}
