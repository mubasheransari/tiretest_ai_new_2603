import 'package:flutter/material.dart';

class LogoutConfirmDialog extends StatelessWidget {
  const LogoutConfirmDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LogoutConfirmDialog(),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 26,
              offset: const Offset(0, 16),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ icon
            Container(
              width: 54 * s,
              height: 54 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF6F7FA),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: const Color(0xFF111827),
                size: 26 * s,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 18 * s,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),

            Text(
              'Are you sure you want to log out?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 13.5 * s,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6A6F7B),
                height: 1.25,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _SoftButton(
                    text: 'Cancel',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradientDangerButton(
                    text: 'Log out',
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientDangerButton extends StatelessWidget {
  const _GradientDangerButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFF97316)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
                color: Colors.white,
                letterSpacing: .2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
