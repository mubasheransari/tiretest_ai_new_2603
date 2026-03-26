import 'dart:io';
import 'package:flutter/material.dart';

/// ✅ Reusable widget: pass your "key" string, it will show:
/// - Image.network if it can build a URL
/// - fallback widget if invalid or fails
class KeyImageView extends StatelessWidget {
  const KeyImageView({
    super.key,
    required this.imageKey,
    this.baseHost = "http://54.162.208.215",
    this.pathPrefix = "/backend/uploads", // change if your server uses another path
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
    this.placeholder,
    this.errorWidget,
  });

  final String imageKey;

  /// e.g. "http://54.162.208.215"
  final String baseHost;

  /// e.g. "/backend/uploads"
  final String pathPrefix;

  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;

  final Widget? placeholder;
  final Widget? errorWidget;

  static bool _isHttp(String v) {
    final u = Uri.tryParse(v);
    return u != null &&
        u.hasScheme &&
        (u.scheme == "http" || u.scheme == "https") &&
        u.host.isNotEmpty;
  }

  String _buildImageUrlFromKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return "";

    // already a full url
    if (_isHttp(k)) return k;

    // your key format: "userId - vehicleType - vehicleId - filename.jpg"
    final parts = k.split(' - ').map((e) => e.trim()).toList();
    if (parts.length < 4) return "";

    final userId = parts[0];
    final vehicleType = parts[1];
    final vehicleId = parts[2];
    final fileName = parts.sublist(3).join(' - '); // keep original filename

    // final url = "$baseHost$pathPrefix/$userId/$vehicleType/$vehicleId/$fileName"
    final prefix = pathPrefix.startsWith("/") ? pathPrefix : "/$pathPrefix";
    final host = baseHost.endsWith("/") ? baseHost.substring(0, baseHost.length - 1) : baseHost;

    return "$host$prefix/$userId/$vehicleType/$vehicleId/$fileName";
  }

  @override
  Widget build(BuildContext context) {
    final url = _buildImageUrlFromKey(imageKey);

    final ph = placeholder ??
        SizedBox(
          height: height,
          width: width,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );

    final err = errorWidget ??
        SizedBox(
          height: height,
          width: width,
          child: const Center(child: Icon(Icons.broken_image)),
        );

    if (url.isEmpty) return err;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ph;
        },
        errorBuilder: (_, __, ___) => err,
      ),
    );
  }
}
