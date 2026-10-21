import 'package:flutter/material.dart';

import 'widgets.dart';

/// Ortak kaplama bileşenleri (yeni ekranlar için): karartma + krem kart.
class OverlayDim extends StatelessWidget {
  const OverlayDim({super.key, required this.child, this.opacity = 0.62, this.onTapOutside});
  final Widget child;
  final double opacity;
  final VoidCallback? onTapOutside;
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapOutside,
          child: ColoredBox(color: Colors.black.withValues(alpha: opacity), child: child),
        ),
      );
}

class OverlayCard extends StatelessWidget {
  const OverlayCard({super.key, required this.child, this.width = 760, this.padding = 28});
  final Widget child;
  final double width;
  final double padding;
  @override
  Widget build(BuildContext context) => Center(
        child: GestureDetector(
          onTap: () {}, // kartın içine dokunmak kapatmasın
          child: Container(
            width: width,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: kWood, width: 6),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: child,
          ),
        ),
      );
}
