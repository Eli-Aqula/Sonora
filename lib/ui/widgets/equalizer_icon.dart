import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_provider.dart';

class EqualizerIcon extends ConsumerStatefulWidget {
  final double size;
  final Color color;
  final int bars;
  final bool? playing;

  const EqualizerIcon({
    super.key,
    this.size = 14,
    required this.color,
    this.bars = 3,
    this.playing,
  });

  @override
  ConsumerState<EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends ConsumerState<EqualizerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(bool playing) {
    if (playing) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.playing ??
        ref.watch(
          playbackSnapshotProvider
              .select((s) => s.valueOrNull?.playing ?? false),
        ) ??
        false;
    _syncAnimation(isPlaying);

    final barWidth = widget.size * 0.18;
    final spacing =
        (widget.size - barWidth * widget.bars) / (widget.bars - 1);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.bars, (i) {
              final phase = (_controller.value + i / widget.bars) % 1.0;
              final h = 0.3 +
                  0.7 * (0.5 + 0.5 * math.sin(phase * math.pi * 2));
              return Padding(
                padding: EdgeInsets.only(
                  right: i == widget.bars - 1 ? 0 : spacing,
                ),
                child: Container(
                  width: barWidth,
                  height: widget.size * h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius:
                        BorderRadius.circular(barWidth * 0.4),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
