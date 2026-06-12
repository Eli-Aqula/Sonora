import 'package:flutter/material.dart';
import 'dart:async';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double speed;
  final double separator;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.speed = 30,
    this.separator = 32,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  Timer? _timer;
  double _offset = 0;
  double _textWidth = 0;
  double _maxWidth = 0;
  bool _overflows = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    // 120 FPS = 8.33 ms per frame
    _timer = Timer.periodic(const Duration(microseconds: 8333), (_) {
      _onTick(1 / 120.0);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _measure() {
    if (!mounted) return;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.size.width;
    final box = context.findRenderObject() as RenderBox?;
    final maxW = box?.constraints.maxWidth ?? double.infinity;
    final overflows = w > maxW && maxW.isFinite;
    setState(() {
      _overflows = overflows;
      _textWidth = w;
      _maxWidth = maxW.isFinite ? maxW : 0;
    });
    if (!overflows) {
      _stopTimer();
    } else if (mounted) {
      _startTimer();
    }
  }

  void _onTick(double dt) {
    if (!mounted || _textWidth <= 0) return;
    final cycle = _textWidth + widget.separator;
    var newOffset = _offset + widget.speed * dt;
    if (cycle > 0 && newOffset >= cycle) {
      newOffset = newOffset % cycle;
    }
    setState(() {
      _offset = newOffset;
    });
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_overflows) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return ClipRect(
      child: SizedBox(
        width: _maxWidth,
        height: _textHeight(),
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(-_offset, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                  SizedBox(width: widget.separator),
                  Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _textHeight() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.size.height;
  }
}
