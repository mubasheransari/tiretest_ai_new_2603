import 'package:flutter/material.dart';
import 'dart:ui';


class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.enabled,
    required this.onPickGallery,
    required this.onCapture,
  });

  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onCapture;

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8 * s),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // glass bar background
            ClipRRect(
              borderRadius: BorderRadius.circular(26 * s),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  height: 105 * s,
                  padding: EdgeInsets.symmetric(horizontal: 16 * s),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.35),
                    borderRadius: BorderRadius.circular(26 * s),
                    border: Border.all(color: Colors.white.withOpacity(.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.28),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _PillAction(
                        s: s,
                        enabled: enabled,
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: onPickGallery,
                        glow: true,
                      ),
                      const Spacer(),
                      // space for center capture button
                      SizedBox(width: 92 * s),
                      const Spacer(),
                      _PillAction(
                        s: s,
                        enabled: false, // keep right side for symmetry (optional)
                        icon: Icons.flash_on_rounded,
                        label: 'Auto',
                        onTap: () {},
                        ghost: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // center capture (floating)
            Positioned(
              bottom: 16 * s,
              child: _CaptureFab(
                s: s,
                enabled: enabled,
                onTap: onCapture,
                gradient: _brandGrad,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.s,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
    this.glow = false,
    this.ghost = false,
  });

  final double s;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool glow;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : (ghost ? .35 : .45);

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18 * s),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
          decoration: BoxDecoration(
            color: ghost ? Colors.white.withOpacity(.06) : Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(color: Colors.white.withOpacity(.12)),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(.08),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20 * s),
              SizedBox(width: 8 * s),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5 * s,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureFab extends StatelessWidget {
  const _CaptureFab({
    required this.s,
    required this.enabled,
    required this.onTap,
    required this.gradient,
  });

  final double s;
  final bool enabled;
  final VoidCallback onTap;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 82 * s,
          height: 82 * s,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.28),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(.10),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 64 * s,
              height: 64 * s,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.22)),
              ),
              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 30 * s),
            ),
          ),
        ),
      ),
    );
  }
}


/*

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.enabled,
    required this.onPickGallery,
    required this.onCapture,
    required this.galleryIconAsset,
    required this.captureIconAsset,
  });

  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onCapture;
  final String galleryIconAsset;
  final String captureIconAsset;

  static const LinearGradient _brandGrad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22 * s),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(22 * s),
            border: Border.all(color: Colors.white.withOpacity(.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.30),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              // Gallery
              _SideButton(
                s: s,
                enabled: enabled,
                onTap: onPickGallery,
                child: _IconTile(
                  s: s,
                  asset: galleryIconAsset,
                  label: 'Gallery',
                ),
              ),

              SizedBox(width: 14 * s),

              // Capture (big gradient button)
              Expanded(
                child: _CaptureButton(
                  s: s,
                  enabled: enabled,
                  onTap: onCapture,
                  gradient: _brandGrad,
                  asset: captureIconAsset,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.s,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final double s;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18 * s),
        child: Container(
          width: 92 * s,
          padding: EdgeInsets.symmetric(vertical: 12 * s),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(color: Colors.white.withOpacity(.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.s,
    required this.asset,
    required this.label,
  });

  final double s;
  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(asset, width: 22 * s, height: 22 * s, color: Colors.white),
        SizedBox(height: 6 * s),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontWeight: FontWeight.w800,
            fontSize: 12.5 * s,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.s,
    required this.enabled,
    required this.onTap,
    required this.gradient,
    required this.asset,
  });

  final double s;
  final bool enabled;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20 * s),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14 * s),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20 * s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.25),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42 * s,
                height: 42 * s,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(.22)),
                ),
                child: Center(
                  child: Image.asset(asset, width: 22 * s, height: 22 * s, color: Colors.white),
                ),
              ),
              SizedBox(width: 12 * s),
              Text(
                'Capture',
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5 * s,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/

// class BottomActionBar extends StatelessWidget {
//   const BottomActionBar({
//     super.key,
//     required this.onPickGallery,
//     required this.onCapture,
//     required this.onPickDocs,
//     required this.enabled,
//     required this.galleryIconAsset,
//     required this.captureIconAsset,
//     required this.docsIconAsset,
//   });

//   final VoidCallback onPickGallery;
//   final VoidCallback onCapture;
//   final VoidCallback onPickDocs;
//   final bool enabled;

//   final String galleryIconAsset; // e.g. 'assets/icons/gallery.png'
//   final String captureIconAsset; // e.g. 'assets/icons/scan.png'
//   final String docsIconAsset;    // e.g. 'assets/icons/docs.png'

//   @override
//   Widget build(BuildContext context) {
//     final w = MediaQuery.sizeOf(context).width;
//     final s = w / 390.0; // simple scale (base width 390)

//     return SizedBox(
//       height: 148 * s,
//       child: Stack(
//         alignment: Alignment.bottomCenter,
//         children: [
//           // pill container
//           Positioned.fill(
//             top: 32 * s, // give room so the middle circle can sit inside nicely
//             child: Container(
//               margin: EdgeInsets.symmetric(horizontal: 16 * s),
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFFEAF2FF), Color(0xFFF5F6FF)],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 borderRadius: BorderRadius.circular(28 * s),
//                 boxShadow: const [
//                   BoxShadow(
//                     color: Color(0x140E1631),
//                     blurRadius: 20,
//                     offset: Offset(0, 10),
//                   ),
//                 ],
//                 border: Border.all(color: Color(0xFFE6EBF5)),
//               ),
//               padding: EdgeInsets.fromLTRB(22 * s, 1 * s, 22 * s, 8 * s),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
                  
//                   _circleWithLabel(
//                     s: s,
//                     label: 'Images',
//                     iconAsset: galleryIconAsset,
//                     onTap: onPickGallery,
//                   ),
//                   SizedBox(width: 86 * s), // space reserved for center button
//                   _circleWithLabel(
//                     s: s,
//                     label: 'Documents',
//                     iconAsset: docsIconAsset,
//                     onTap: onPickDocs,
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // center scan button
//           Positioned(
//             bottom: 32 * s,
//             child: _CenterCaptureButton(
//               s: s,
//               enabled: enabled,
//               iconAsset: captureIconAsset,
//               onTap: enabled ? onCapture : null,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _circleWithLabel({
//     required double s,
//     required String label,
//     required String iconAsset,
//     VoidCallback? onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(999),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 64 * s,
//             height: 64 * s,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//               border: Border.all(color: const Color(0xFFE6EBF5)),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Color(0x140E1631),
//                   blurRadius: 14,
//                   offset: Offset(0, 8),
//                 ),
//               ],
//             ),
//             alignment: Alignment.center,
//             child: Image.asset(
//               iconAsset,
//               width: 48 * s,
//               height: 48 * s,
//              // color: const Color(0xFF111827), // black-ish
//             ),
//           ),
//           SizedBox(height: 8 * s),
//           Text(
//             label,
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w800,
//               fontSize: 14 * s,
//               color: const Color(0xFF0E1631),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _CenterCaptureButton extends StatelessWidget {
  const _CenterCaptureButton({
    required this.s,
    required this.enabled,
    required this.iconAsset,
    required this.onTap,
  });

  final double s;
  final bool enabled;
  final String iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color a = const Color(0xFF4CA6FF);
    final Color b = const Color(0xFF6B8CFF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 86 * s,
        height: 86 * s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: enabled ? [a, b] : [Colors.grey.shade400, Colors.grey.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x330E1631), blurRadius: 20, offset: Offset(0, 12)),
          ],
        ),
        padding: EdgeInsets.all(14 * s),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent, // we keep only the outer gradient
          ),
          alignment: Alignment.center,
          child: Image.asset(
            iconAsset,
            width: 54 * s,
            height: 54 * s,
          //  color: Colors.white,
          ),
        ),
      ),
    );
  }
}

