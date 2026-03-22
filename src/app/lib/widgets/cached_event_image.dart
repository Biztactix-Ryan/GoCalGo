import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A cached network image widget used for event images throughout the app.
///
/// Wraps [CachedNetworkImage] to provide consistent placeholder/error handling
/// and disk+memory caching so images are not re-fetched on every build.
class CachedEventImage extends StatelessWidget {
  const CachedEventImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.placeholderColor,
    this.errorIcon,
    this.errorIconColor,
  });

  final String imageUrl;
  final double height;
  final double? width;
  final BoxFit fit;
  final String? semanticLabel;
  final Color? placeholderColor;
  final IconData? errorIcon;
  final Color? errorIconColor;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: width ?? double.infinity,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(
        height: height,
        width: width ?? double.infinity,
        color: placeholderColor ?? Colors.grey.shade200,
      ),
      errorWidget: (_, __, ___) => Semantics(
        label: semanticLabel != null
            ? '$semanticLabel, image failed to load'
            : 'Image failed to load',
        child: Container(
          height: height,
          width: width ?? double.infinity,
          color: placeholderColor ?? Colors.grey.shade200,
          child: Icon(
            errorIcon ?? Icons.broken_image_outlined,
            size: 48,
            color: errorIconColor ?? Colors.grey,
          ),
        ),
      ),
    );
  }
}
