import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../results/results_page.dart';
import '../../domain/entities/match_history.dart';
import 'gameplay_bloc.dart';

String _calcRank(double pct) {
  if (pct >= 100) return 'S';
  if (pct >= 91) return 'A';
  if (pct >= 80) return 'B';
  if (pct >= 70) return 'C';
  if (pct >= 60) return 'D';
  if (pct >= 50) return 'E';
  return 'F';
}

class GameplayActionPage extends StatelessWidget {
  const GameplayActionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameplayActionBloc(),
      child: const _GameView(),
    );
  }
}

class _GameView extends StatefulWidget {
  const _GameView({Key? key}) : super(key: key);
  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060416),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          final bloc = context.read<GameplayActionBloc>();
          final key = event.logicalKey.keyLabel.toUpperCase();
          if (event is KeyDownEvent) {
            bloc.add(KeyPressed(key));
          } else if (event is KeyUpEvent) {
            bloc.add(KeyReleased(key));
          }
        },
        child: BlocBuilder<GameplayActionBloc, GameplayActionState>(
          builder: (context, state) {
            return LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final scale = w / kGameW;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Static court background
                  CustomPaint(
                    size: Size(w, h),
                    painter: _CourtPainter(scale: scale, canvasH: h),
                  ),
                  // Dynamic game objects
                  CustomPaint(
                    size: Size(w, h),
                    painter: _GameObjectsPainter(state: state, scale: scale, canvasH: h),
                  ),
                  // HUD overlays
                  _ShotClockWidget(state: state),
                  _GameClockWidget(state: state),
                  _ScoreboardWidget(state: state),
                  _ChargeBarWidget(state: state),
                  _ControlsHint(),
                  _EndButton(),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

// ─── HUD WIDGETS ─────────────────────────────────────────────────────────────

class _ShotClockWidget extends StatelessWidget {
  final GameplayActionState state;
  const _ShotClockWidget({required this.state});

  @override
  Widget build(BuildContext context) {
    final sec = state.shotClock.ceil();
    final urgent = state.shotClock < 5;
    final color = urgent ? Colors.redAccent : const Color(0xFFDE1A58);
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0A1F).withOpacity(0.9),
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Text('SHOT CLOCK',
                style: GoogleFonts.pressStart2p(color: Colors.white54, fontSize: 7)),
            const SizedBox(height: 6),
            Text(sec.toString().padLeft(2, '0'),
                style: GoogleFonts.pressStart2p(
                    color: color,
                    fontSize: 30,
                    shadows: [Shadow(color: color, blurRadius: 10)])),
          ],
        ),
      ),
    );
  }
}

class _GameClockWidget extends StatelessWidget {
  final GameplayActionState state;
  const _GameClockWidget({required this.state});

  @override
  Widget build(BuildContext context) {
    final min = (state.gameClock / 60).floor();
    final sec = (state.gameClock % 60).floor();
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0A1F).withOpacity(0.9),
            border: Border.all(color: const Color(0xFF6664E8), width: 2),
          ),
          child: Text(
            '$min:${sec.toString().padLeft(2, '0')}  Q${state.period}',
            style: GoogleFonts.pressStart2p(
                color: const Color(0xFF6664E8), fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _ScoreboardWidget extends StatelessWidget {
  final GameplayActionState state;
  const _ScoreboardWidget({required this.state});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0A1F).withOpacity(0.9),
          border: Border.all(color: const Color(0xFF1A05A2), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0xFF1A05A2), blurRadius: 12)
          ],
        ),
        child: Row(
          children: [
            _ScoreCol('HOME', state.homeScore),
            const SizedBox(width: 20),
            Text('VS',
                style: GoogleFonts.pressStart2p(
                    color: Colors.white38, fontSize: 9)),
            const SizedBox(width: 20),
            _ScoreCol('GUEST', state.guestScore),
          ],
        ),
      ),
    );
  }
}

class _ScoreCol extends StatelessWidget {
  final String label;
  final int score;
  const _ScoreCol(this.label, this.score);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 8)),
        const SizedBox(height: 6),
        Text(score.toString().padLeft(2, '0'),
            style: GoogleFonts.pressStart2p(
                color: const Color(0xFFF67D31),
                fontSize: 26,
                shadows: const [
                  Shadow(color: Color(0xFFF67D31), blurRadius: 8)
                ])),
      ],
    );
  }
}

class _ChargeBarWidget extends StatelessWidget {
  final GameplayActionState state;
  const _ChargeBarWidget({required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.isCharging && state.chargeLevel == 0) return const SizedBox.shrink();
    return Positioned(
      bottom: 70,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          children: [
            Text(
              'CHARGE: ${(state.chargeLevel * 100).toInt()}%',
              style: GoogleFonts.pressStart2p(
                  color: Colors.orangeAccent, fontSize: 9),
            ),
            const SizedBox(height: 6),
            Container(
              width: 220,
              height: 14,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orangeAccent, width: 2),
                color: Colors.black38,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: state.chargeLevel,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.yellow, Colors.orange, Colors.red]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsHint extends StatelessWidget {
  const _ControlsHint();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Text(
        'WASD: Move/Jump  |  S (hold): Charge Shot  |  W near hoop: DUNK  |  Q/E: Block  |  Z: Step Back',
        style: GoogleFonts.spaceMono(color: Colors.white24, fontSize: 8),
      ),
    );
  }
}

class _EndButton extends StatelessWidget {
  const _EndButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          final s = context.read<GameplayActionBloc>().state;
          final pct = s.shotsFired == 0 ? 0.0 : s.shotsScored / s.shotsFired * 100;
          MatchHistory.add(MatchResult(
            shotsFired: s.shotsFired,
            shotsScored: s.shotsScored,
            homeScore: s.homeScore,
            guestScore: s.guestScore,
            rank: _calcRank(pct),
            time: DateTime.now(),
          ));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PostGameResultsPage(
                shotsFired: s.shotsFired,
                shotsScored: s.shotsScored,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A05A2).withOpacity(0.85),
            border: Border.all(color: const Color(0xFFF67D31), width: 2),
          ),
          child: Text('END MATCH',
              style: GoogleFonts.pressStart2p(
                  color: const Color(0xFFF67D31), fontSize: 10)),
        ),
      ),
    );
  }
}

// ─── PAINTERS ────────────────────────────────────────────────────────────────

// Converts world coords (x right, y up from floor) to canvas coords (top-left origin)
Offset _w2c(double wx, double wy, double scale, double canvasH) {
  return Offset(wx * scale, canvasH - (80 + wy) * scale);
}

class _CourtPainter extends CustomPainter {
  final double scale;
  final double canvasH;

  const _CourtPainter({required this.scale, required this.canvasH});

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = canvasH - 80 * scale;

    // Background beneath floor
    canvas.drawRect(
      Rect.fromLTRB(0, floorY, size.width, size.height),
      Paint()..color = const Color(0xFF0A0620),
    );

    // Court surface gradient
    final courtPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1A0A3E),
          const Color(0xFF0D0624),
        ],
      ).createShader(Rect.fromLTRB(0, floorY - 300 * scale, size.width, floorY));
    canvas.drawRect(
        Rect.fromLTRB(0, floorY - 350 * scale, size.width, floorY), courtPaint);

    // Floor line
    canvas.drawLine(
      Offset(0, floorY),
      Offset(size.width, floorY),
      Paint()
        ..color = const Color(0xFF6664E8).withOpacity(0.6)
        ..strokeWidth = 2 * scale,
    );

    final linePaint = Paint()
      ..color = const Color(0xFF6664E8).withOpacity(0.35)
      ..strokeWidth = 1.5 * scale
      ..style = PaintingStyle.stroke;

    // Center line
    final cx = size.width / 2;
    canvas.drawLine(
        Offset(cx, floorY), Offset(cx, floorY - 300 * scale), linePaint);

    // Center circle
    canvas.drawCircle(Offset(cx, floorY), 70 * scale, linePaint);

    // Key areas and 3-point lines
    _drawKeyArea(canvas, kLeftHoopX, floorY, scale, linePaint, isLeft: true);
    _drawKeyArea(canvas, kRightHoopX, floorY, scale, linePaint, isLeft: false);

    // Hoops
    _drawHoop(canvas, kLeftHoopX, isLeft: true);
    _drawHoop(canvas, kRightHoopX, isLeft: false);
  }

  void _drawKeyArea(Canvas canvas, double hoopX, double floorY, double scale,
      Paint linePaint, {required bool isLeft}) {
    final rimScreenY = floorY - kHoopRimY * scale;
    final left = isLeft
        ? hoopX * scale
        : (kGameW - kThreePtX) * scale;
    final right = isLeft ? kThreePtX * scale : kRightHoopX * scale;

    // Key fill
    canvas.drawRect(
      Rect.fromLTRB(left, rimScreenY, right, floorY),
      Paint()..color = const Color(0xFF6664E8).withOpacity(0.06),
    );
    // Key outline
    canvas.drawRect(Rect.fromLTRB(left, rimScreenY, right, floorY), linePaint);

    // Free throw circle
    final ftX = isLeft ? kThreePtX * scale : (kGameW - kThreePtX) * scale;
    canvas.drawCircle(Offset(ftX, floorY), 50 * scale, linePaint);

    // 3-point arc (simplified as semicircle)
    final arcCx = isLeft ? kLeftHoopX * scale : kRightHoopX * scale;
    final arcRadius = (kThreePtX - (isLeft ? kLeftHoopX : kGameW - kRightHoopX)) * scale;
    final arcRect = Rect.fromCircle(
        center: Offset(arcCx, floorY), radius: arcRadius);
    canvas.drawArc(arcRect, isLeft ? -pi / 2 : pi / 2, pi, false, linePaint);
  }

  void _drawHoop(Canvas canvas, double hoopWorldX, {required bool isLeft}) {
    final rimScreenX = hoopWorldX * scale;
    final rimScreenY = canvasH - (80 + kHoopRimY) * scale;
    final halfGap = kHoopHalfGap * scale;

    // Backboard
    final bbX = isLeft ? rimScreenX - halfGap - 6 * scale : rimScreenX + halfGap + 6 * scale;
    canvas.drawRect(
      Rect.fromLTRB(
          bbX - 5 * scale,
          rimScreenY - 55 * scale,
          bbX + 5 * scale,
          rimScreenY + 25 * scale),
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    // Net lines
    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 1.2 * scale;
    final netBottom = rimScreenY + 38 * scale;
    for (double t = 0; t <= 1; t += 0.2) {
      final x = (rimScreenX - halfGap) + 2 * halfGap * t;
      canvas.drawLine(Offset(x, rimScreenY), Offset(rimScreenX, netBottom), netPaint);
    }

    // Rim glow
    canvas.drawLine(
      Offset(rimScreenX - halfGap, rimScreenY),
      Offset(rimScreenX + halfGap, rimScreenY),
      Paint()
        ..color = const Color(0xFFF67D31).withOpacity(0.25)
        ..strokeWidth = 10 * scale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Rim
    canvas.drawLine(
      Offset(rimScreenX - halfGap, rimScreenY),
      Offset(rimScreenX + halfGap, rimScreenY),
      Paint()
        ..color = const Color(0xFFF67D31)
        ..strokeWidth = 3.5 * scale
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CourtPainter old) => false;
}

class _GameObjectsPainter extends CustomPainter {
  final GameplayActionState state;
  final double scale;
  final double canvasH;

  const _GameObjectsPainter(
      {required this.state, required this.scale, required this.canvasH});

  @override
  void paint(Canvas canvas, Size size) {
    _drawPlayer(canvas);
    _drawBall(canvas);
  }

  void _drawPlayer(Canvas canvas) {
    final center = _w2c(state.playerX + 25, state.playerY, scale, canvasH);
    final w = 50.0 * scale;
    final h = 72.0 * scale;

    Color bodyColor;
    switch (state.action) {
      case PlayerAction.chargeShoot:
        bodyColor = Colors.orangeAccent;
        break;
      case PlayerAction.awakening:
        bodyColor = const Color(0xFFDE1A58);
        break;
      case PlayerAction.blockLeft:
      case PlayerAction.blockRight:
        bodyColor = const Color(0xFF4488FF);
        break;
      case PlayerAction.crouch:
        bodyColor = Colors.purpleAccent;
        break;
      case PlayerAction.dunk:
        bodyColor = const Color(0xFFFF2266);
        break;
      default:
        bodyColor = const Color(0xFFFF71D8);
    }

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, canvasH - 80 * scale + 2 * scale),
          width: w * 0.9,
          height: 10 * scale),
      Paint()..color = Colors.black.withOpacity(0.4),
    );

    final bodyTop = center.dy - h;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(center.dx - w / 2, bodyTop, w, h),
      Radius.circular(5 * scale),
    );

    // Body fill
    canvas.drawRRect(bodyRect, Paint()..color = bodyColor.withOpacity(0.85));
    // Body outline
    canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = bodyColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale);

    // Charge glow
    if (state.isCharging) {
      canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = Colors.orangeAccent
              .withOpacity(0.3 + state.chargeLevel * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale),
      );
    }

    // 灌籃光暈
    if (state.action == PlayerAction.dunk) {
      canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = const Color(0xFFFF2266).withOpacity(0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * scale),
      );
    }

    // Head
    final headCenter = Offset(center.dx, bodyTop - 10 * scale);
    canvas.drawCircle(headCenter, 11 * scale, Paint()..color = bodyColor);
    // Eye (shows facing direction)
    final eyeX = state.isFacingRight
        ? headCenter.dx + 4 * scale
        : headCenter.dx - 4 * scale;
    canvas.drawCircle(
        Offset(eyeX, headCenter.dy), 3 * scale, Paint()..color = Colors.white);

    // Direction arrow at feet
    final arrowDir = state.isFacingRight ? 1.0 : -1.0;
    final arrowStart = Offset(center.dx, center.dy + 4 * scale);
    canvas.drawLine(
      arrowStart,
      Offset(arrowStart.dx + arrowDir * 14 * scale, arrowStart.dy),
      Paint()
        ..color = bodyColor.withOpacity(0.6)
        ..strokeWidth = 2 * scale,
    );

    // Ball in hand (when holding)
    if (state.playerHasBall) {
      final handX = state.isFacingRight
          ? center.dx + w / 2 + 12 * scale
          : center.dx - w / 2 - 12 * scale;
      final handY = bodyTop + h * 0.3;
      _drawBallAt(canvas, Offset(handX, handY), kBallRadius * 0.85 * scale);
    }
  }

  void _drawBall(Canvas canvas) {
    if (state.playerHasBall) return;
    final pos = _w2c(state.ballX, state.ballY, scale, canvasH);
    final r = kBallRadius * scale;

    // Shadow on floor
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(pos.dx, canvasH - 80 * scale + 2 * scale),
          width: r * 1.4,
          height: 5 * scale),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    _drawBallAt(canvas, pos, r);
  }

  void _drawBallAt(Canvas canvas, Offset center, double r) {
    // Glow
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(0xFFE8600A).withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Ball body
    canvas.drawCircle(center, r,
        Paint()..color = const Color(0xFFE8600A));

    // Seam lines
    final seam = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..strokeWidth = 1.4 * (r / kBallRadius)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r, seam);
    canvas.drawLine(Offset(center.dx, center.dy - r),
        Offset(center.dx, center.dy + r), seam);
    // Curved seam
    canvas.drawArc(
        Rect.fromCenter(center: center, width: r * 1.4, height: r * 2),
        -pi / 2,
        pi,
        false,
        seam);
    canvas.drawArc(
        Rect.fromCenter(center: center, width: r * 1.4, height: r * 2),
        pi / 2,
        pi,
        false,
        seam);
  }

  @override
  bool shouldRepaint(_GameObjectsPainter old) => old.state != state;
}
