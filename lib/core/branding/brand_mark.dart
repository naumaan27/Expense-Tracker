import 'package:flutter/material.dart';

import 'app_info.dart';

/// The Net Worth brand mark, using the official brand artwork asset across the application.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 40,
    this.tile,
    this.ink,
    this.radiusRim = true,
  });

  /// The literal launcher icon variant.
  const BrandMark.icon({super.key, this.size = 40})
      : tile = const Color(0xFF0E0E10),
        ink = Colors.white,
        radiusRim = true;

  final double size;
  final Color? tile;
  final Color? ink;

  /// A subtle shadow/rim for depth on dark or light backgrounds.
  final bool radiusRim;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: radiusRim
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: size * 0.10,
                  offset: Offset(0, size * 0.04),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/branding/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Brand name wordmark, set with heavy, elegant typography.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 26, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppInfo.name,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: fontSize * 0.06,
        height: 1.1,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// Mark and wordmark locked together, for headers and the About screen.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 34, this.fontSize = 24});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.34),
        BrandWordmark(fontSize: fontSize),
      ],
    );
  }
}
