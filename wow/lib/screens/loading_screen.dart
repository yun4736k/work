import 'dart:async';
import 'package:flutter/material.dart';

/// 로딩 동안 로고만 중앙에 크게 보여주는 미니멀 스플래시.
/// - 텍스트 없음, 그라디언트 배경 + 펄스 글로우 + 살짝 스케일
/// - 원형 배지 크기: 화면 가로폭의 70%
class LoadingScreen extends StatefulWidget {
  final Future<void> Function()? doInitialize;                 // 선택: 초기화 작업
  final Widget Function(BuildContext context) nextPageBuilder; // 다음 화면
  final ImageProvider? logo;                                   // 중앙 로고

  const LoadingScreen({
    super.key,
    required this.nextPageBuilder,
    this.doInitialize,
    this.logo,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scale = Tween(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _kickoff();
  }

  /// 최소 표시 시간(여기서는 10초) + 선택적 초기화 동시 진행 후 다음 화면으로
  Future<void> _kickoff() async {
    try {
      final futures = <Future<void>>[
        Future.delayed(const Duration(seconds: 10)), // 최소 표시 시간
      ];
      if (widget.doInitialize != null) {
        futures.add(widget.doInitialize!());
      }
      await Future.wait(futures);
    } catch (_) {
      // 필요시 로깅/에러 화면 분기 가능
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.nextPageBuilder),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 원형 지름 = 화면 가로폭의 70%
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenWidth * 0.7;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.9, -0.9),
            end: Alignment(0.9, 0.9),
            colors: [Color(0xFFA8D5BA), Color(0xFFEAF6EF)],
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 바깥쪽 펄스 링
              _PulseHalo(
                controller: _controller,
                baseSize: circleSize * 1.1,
                maxSpread: circleSize * 0.06,
                baseOpacity: 0.08,
              ),
              // 안쪽 펄스 링
              _PulseHalo(
                controller: _controller,
                baseSize: circleSize * 0.9,
                maxSpread: circleSize * 0.045,
                baseOpacity: 0.12,
                phaseShift: 0.5,
              ),
              // 중앙 원형 로고 배지
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.85),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 36,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                        color: Colors.black.withOpacity(0.12),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 1.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.logo != null
                      ? Image(image: widget.logo!, fit: BoxFit.contain)
                      : const Icon(
                    Icons.directions_walk,
                    size: 120,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 부드럽게 커졌다 작아지는 원형 글로우(오라)
class _PulseHalo extends StatelessWidget {
  final AnimationController controller;
  final double baseSize;
  final double maxSpread;
  final double baseOpacity;
  final double phaseShift;

  const _PulseHalo({
    required this.controller,
    required this.baseSize,
    required this.maxSpread,
    required this.baseOpacity,
    this.phaseShift = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = (controller.value + phaseShift) % 1.0; // 0~1
        final spread = maxSpread * t;
        final opacity = baseOpacity * (1.0 - t);

        return Container(
          width: baseSize + spread,
          height: baseSize + spread,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(opacity),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.2, 1.0],
            ),
          ),
        );
      },
    );
  }
}