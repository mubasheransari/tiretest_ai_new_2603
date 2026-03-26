import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
   GradientText(this.text, {required this.gradient, required this.style, super.key});
  final String text;
  final Gradient gradient;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => gradient.createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style.copyWith(fontFamily: 'ClashGrotesk')),
    );
  }
}