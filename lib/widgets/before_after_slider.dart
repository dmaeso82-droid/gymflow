import 'dart:math' as math;
import 'package:flutter/material.dart';

class BeforeAfterSlider extends StatefulWidget {
  final String beforeImageUrl;
  final String afterImageUrl;
  final String beforeLabel;
  final String afterLabel;
  final double aspectRatio;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.beforeLabel = 'ANTES',
    this.afterLabel = 'AHORA',
    this.aspectRatio = 4 / 5,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double split = 0.5;

  void updateSplitFromLocalPosition(Offset localPosition, double width) {
    if (width <= 0) return;
    final next = (localPosition.dx / width).clamp(0.02, 0.98).toDouble();
    setState(() => split = next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / widget.aspectRatio;
        final splitWidth = math.max(1.0, width * split);
        final handleLeft = (splitWidth - 24).clamp(0.0, math.max(0.0, width - 48)).toDouble();

        return MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => updateSplitFromLocalPosition(event.localPosition, width),
            onPointerMove: (event) => updateSplitFromLocalPosition(event.localPosition, width),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => updateSplitFromLocalPosition(details.localPosition, width),
              onPanDown: (details) => updateSplitFromLocalPosition(details.localPosition, width),
              onPanUpdate: (details) => updateSplitFromLocalPosition(details.localPosition, width),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: _ComparisonImage(
                          imageUrl: widget.afterImageUrl,
                          semanticLabel: widget.afterLabel,
                        ),
                      ),
                      Positioned.fill(
                        child: ClipRect(
                          clipper: _BeforeAfterClipper(split: split),
                          child: _ComparisonImage(
                            imageUrl: widget.beforeImageUrl,
                            semanticLabel: widget.beforeLabel,
                          ),
                        ),
                      ),
                      Positioned(
                        left: splitWidth - 1.5,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 3, color: Colors.white.withValues(alpha: 0.94)),
                      ),
                      Positioned(
                        left: handleLeft,
                        top: height / 2 - 24,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617).withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.compare_arrows, color: Colors.greenAccent),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: IgnorePointer(child: _ComparisonLabel(text: widget.beforeLabel)),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: IgnorePointer(child: _ComparisonLabel(text: widget.afterLabel)),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.52),
                                ],
                              ),
                            ),
                            child: Text(
                              'Arrastra la barra para comparar la evolución',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BeforeAfterClipper extends CustomClipper<Rect> {
  final double split;

  const _BeforeAfterClipper({required this.split});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * split, size.height);
  }

  @override
  bool shouldReclip(covariant _BeforeAfterClipper oldClipper) {
    return oldClipper.split != split;
  }
}

class _ComparisonImage extends StatelessWidget {
  final String imageUrl;
  final String semanticLabel;

  const _ComparisonImage({required this.imageUrl, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        color: const Color(0xFF020617),
        child: Center(child: Icon(Icons.photo, color: Colors.white38, size: 44)),
      );
    }

    return Image.network(
      imageUrl,
      semanticLabel: semanticLabel,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(child: CircularProgressIndicator());
      },
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF020617),
        child: Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 44)),
      ),
    );
  }
}

class _ComparisonLabel extends StatelessWidget {
  final String text;

  const _ComparisonLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}



