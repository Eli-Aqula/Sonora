import 'package:flutter/material.dart';

class FlatTrackShape extends SliderTrackShape {
  const FlatTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 3;
    final trackLeft = offset.dx;
    final trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(trackLeft, trackTop, parentBox.size.width, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 3;
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
    );
    final activeRect = Rect.fromLTRB(
      rect.left,
      rect.top,
      thumbCenter.dx,
      rect.bottom,
    );
    final inactiveRect = Rect.fromLTRB(
      thumbCenter.dx,
      rect.top,
      rect.right,
      rect.bottom,
    );
    if (activeRect.width > 0) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          activeRect,
          Radius.circular(trackHeight / 2),
        ),
        Paint()..color = sliderTheme.activeTrackColor ?? Colors.white,
      );
    }
    if (inactiveRect.width > 0) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          inactiveRect,
          Radius.circular(trackHeight / 2),
        ),
        Paint()
          ..color =
              sliderTheme.inactiveTrackColor ?? Colors.white24,
      );
    }
  }
}
