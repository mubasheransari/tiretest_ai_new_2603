import 'package:flutter/material.dart';
import 'dart:ui';

enum BottomTab { home, reports, map, about, profile }

class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.active,
    required this.onChanged,
    this.scale,
  });

  final BottomTab active;
  final ValueChanged<BottomTab> onChanged;
  final double? scale;

  void _go(BottomTab tab) {
    if (tab == active) return;
    onChanged(tab);
  }

  // Icons
  static const Map<BottomTab, String> _iconPath = {
    BottomTab.home:    'assets/icon_home_icon.png',
    BottomTab.reports: 'assets/history_bottom_icon.png',
    BottomTab.map:     'assets/location_bottom_bar.png',
    BottomTab.about:   'assets/technician_bottom_bar.png',
    BottomTab.profile: 'assets/profile_bottom_bar.png',
  };

  // Optional halos for inactive chips
  static const Map<BottomTab, Color?> _halo = {
    BottomTab.home:    Color(0xFFE3F7F3),
    BottomTab.reports: Color(0xFFE4F2FF),
    BottomTab.map:     null,
    BottomTab.about:   Color(0xFFE4F2FF),
    BottomTab.profile: Color(0xFFE4F2FF),
  };

  @override
  Widget build(BuildContext context) {
    final s = scale ?? (MediaQuery.of(context).size.width / 390.0);

    // ✅ Ensure the currently active icon is decoded and ready on first frame
    precacheImage(AssetImage(_iconPath[active]!), context);

    Widget _chip({
      required String asset,
      required VoidCallback onTap,
      Color? haloColor,
      Color? iconColor, // null = keep original asset colors
      bool lift = false,
    }) {
      final size = 56 * s;

      final chip = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE9ECF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 18 * s,
              offset: Offset(0, 10 * s),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            asset,
            width: 26 * s,
            height: 26 * s,
            color: iconColor,
            colorBlendMode: iconColor != null ? BlendMode.srcIn : null,
            fit: BoxFit.contain,
          ),
        ),
      );

      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (haloColor != null)
                Container(
                  width: size + 14 * s,
                  height: size + 14 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: haloColor.withOpacity(0.45),
                  ),
                ),
              if (lift)
                Transform.translate(offset: Offset(0, -10 * s), child: chip)
              else
                chip,
            ],
          ),
        ),
      );
    }

    // Active gradient chip (icon = solid white)
    Widget _gradientChip({
      required String asset,
      required VoidCallback onTap,
      bool lift = true,
    }) {
      final size = 60 * s;

      final chip = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF6DD5FF), Color(0xFF7F53FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ShaderMask(
            shaderCallback: (Rect r) =>
                const LinearGradient(colors: [Colors.white, Colors.white]).createShader(r),
            blendMode: BlendMode.srcATop,
            child: Image.asset(
              asset,
              width: 26 * s,
              height: 26 * s,
              fit: BoxFit.contain,
              // ✅ If the asset isn't ready/missing, show a white Material icon so the default tab isn’t blank
              errorBuilder: (_, __, ___) => Icon(
                Icons.circle, // or Icons.home_filled if you want
                size: 22 * s,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Transform.translate(offset: Offset(0, -7 * s), child: chip),
        ),
      );
    }

    Widget _buildItem(BottomTab tab) {
      final asset = _iconPath[tab]!;
      final isActive = active == tab;

      if (isActive) {
        return _gradientChip(asset: asset, onTap: () => _go(tab), lift: true);
      }
      return _chip(
        asset: asset,
        onTap: () => _go(tab),
        haloColor: _halo[tab],
        iconColor: Colors.black,
        lift: false,
      );
    }

    return SafeArea(
      minimum: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 5 * s),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44 * s),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
          child: Container(
            height: 78 * s,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(44 * s),
              border: Border.all(color: const Color(0xFFE9ECF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 20 * s,
                  offset: Offset(0, 10 * s),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 16 * s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildItem(BottomTab.home),
                _buildItem(BottomTab.reports),
                _buildItem(BottomTab.map),
                _buildItem(BottomTab.about),
                _buildItem(BottomTab.profile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

