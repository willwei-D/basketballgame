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

  // ── 角色顏色 ──────────────────────────────────────────────
  Color _bodyColor() {
    switch (state.action) {
      case PlayerAction.chargeShoot: return const Color(0xFFFF6600); // 純橘
      case PlayerAction.awakening:   return const Color(0xFFFF0044); // 純紅
      case PlayerAction.blockLeft:
      case PlayerAction.blockRight:  return const Color(0xFF0055FF); // 純藍
      case PlayerAction.crouch:      return const Color(0xFFBB00FF); // 純紫
      case PlayerAction.dunk:        return const Color(0xFFFF0022); // 深紅
      default:                       return const Color(0xFFFF00CC); // 飽和粉紅
    }
  }

  // ── 畫四肢（大腿→膝→小腿） ───────────────────────────────
  void _drawLimb(Canvas canvas, Offset hip, Offset knee, Offset foot, Paint p) {
    canvas.drawLine(hip, knee, p);
    canvas.drawLine(knee, foot, p);
    // 膝關節圓點
    canvas.drawCircle(knee, p.strokeWidth * 0.65,
        Paint()..color = p.color..style = PaintingStyle.fill);
  }

  // ── 主角色繪製 ────────────────────────────────────────────
  void _drawPlayer(Canvas canvas) {
    final s = scale;
    final foot = _w2c(state.playerX + 25, state.playerY, s, canvasH);
    final fx = foot.dx;
    final fy = foot.dy; // 腳底（畫布座標，y 向下）

    final color = _bodyColor();
    final bool onGround = state.playerY <= kFloorY + 1;
    final bool isMoving = state.velocityX.abs() > 0.5 && onGround;
    final double phase = state.animFrame * 0.22; // 跑步相位（弧度）

    // ── 身體各節點位置 ──
    final hipL  = Offset(fx - 7*s, fy - 30*s);
    final hipR  = Offset(fx + 7*s, fy - 30*s);
    final waist = Offset(fx, fy - 32*s);
    final chest = Offset(fx, fy - 54*s);
    final shlL  = Offset(fx - 13*s, fy - 58*s);
    final shlR  = Offset(fx + 13*s, fy - 58*s);
    final head  = Offset(fx, fy - 74*s);

    // ── 腿部 ──
    double lKx, lKy, lFx, lFy;
    double rKx, rKy, rFx, rFy;

    if (state.action == PlayerAction.dunk) {
      // 灌籃：雙腳張開往後
      lKx = fx - 18*s; lKy = fy - 18*s; lFx = fx - 22*s; lFy = fy - 6*s;
      rKx = fx + 18*s; rKy = fy - 18*s; rFx = fx + 22*s; rFy = fy - 6*s;
    } else if (state.action == PlayerAction.crouch) {
      // 蹲下：膝蓋彎曲
      lKx = fx - 12*s; lKy = fy - 12*s; lFx = fx - 8*s; lFy = fy;
      rKx = fx + 12*s; rKy = fy - 12*s; rFx = fx + 8*s; rFy = fy;
    } else if (!onGround) {
      // 跳躍/空中：腳往後縮
      lKx = fx - 10*s; lKy = fy - 22*s; lFx = fx - 14*s; lFy = fy - 12*s;
      rKx = fx + 10*s; rKy = fy - 22*s; rFx = fx + 14*s; rFy = fy - 12*s;
    } else if (isMoving) {
      // 跑步：左右腳交替擺動
      final swing = sin(phase) * 16*s;
      lKx = fx - 8*s + swing*0.7; lKy = fy - 18*s - swing.abs()*0.2;
      lFx = fx - 6*s + swing;     lFy = fy - (sin(phase) > 0 ? sin(phase)*6*s : 0);
      rKx = fx + 8*s - swing*0.7; rKy = fy - 18*s - swing.abs()*0.2;
      rFx = fx + 6*s - swing;     rFy = fy - (sin(phase) < 0 ? -sin(phase)*6*s : 0);
    } else {
      // 站立：腿直直的
      lKx = fx - 9*s; lKy = fy - 17*s; lFx = fx - 9*s; lFy = fy;
      rKx = fx + 9*s; rKy = fy - 17*s; rFx = fx + 9*s; rFy = fy;
    }

    // ── 手臂 ──
    double lAx, lAy, rAx, rAy;
    final dir = state.isFacingRight ? 1.0 : -1.0;

    if (state.action == PlayerAction.dunk) {
      // 灌籃：雙手高舉
      lAx = fx - 18*s; lAy = fy - 80*s;
      rAx = fx + 18*s; rAy = fy - 80*s;
    } else if (state.isCharging) {
      // 蓄力：拉手準備投
      lAx = shlL.dx - dir*8*s;  lAy = shlL.dy + 16*s;
      rAx = shlR.dx + dir*20*s; rAy = shlR.dy + 6*s;
    } else if (state.action == PlayerAction.blockLeft ||
               state.action == PlayerAction.blockRight) {
      // 阻擋：雙臂張開
      lAx = fx - 26*s; lAy = fy - 52*s;
      rAx = fx + 26*s; rAy = fy - 52*s;
    } else if (!onGround) {
      // 空中：手稍微外展
      lAx = fx - 22*s; lAy = fy - 50*s;
      rAx = fx + 22*s; rAy = fy - 50*s;
    } else if (isMoving) {
      // 跑步：手臂前後擺（與腿反向）
      final armSwing = sin(phase) * 12*s;
      lAx = shlL.dx - armSwing; lAy = shlL.dy + 14*s + armSwing.abs()*0.3;
      rAx = shlR.dx + armSwing; rAy = shlR.dy + 14*s + armSwing.abs()*0.3;
    } else {
      // 自然站立
      lAx = shlL.dx - 12*s; lAy = shlL.dy + 18*s;
      rAx = shlR.dx + 12*s; rAy = shlR.dy + 18*s;
    }

    // ── 開始繪製 ──

    // 地面陰影
    canvas.drawOval(
      Rect.fromCenter(center: Offset(fx, canvasH - 80*s + 3*s), width: 38*s, height: 8*s),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    final limbPaint = Paint()
      ..color = color
      ..strokeWidth = 9*s   // 腿加粗
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 腿（先畫，在軀幹後面）
    _drawLimb(canvas, hipL, Offset(lKx, lKy), Offset(lFx, lFy), limbPaint);
    _drawLimb(canvas, hipR, Offset(rKx, rKy), Offset(rFx, rFy), limbPaint);

    // 軀幹
    canvas.drawLine(waist, chest, limbPaint..strokeWidth = 14*s);

    // 手臂
    final armPaint = Paint()
      ..color = color
      ..strokeWidth = 7*s   // 手臂加粗
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(shlL, Offset(lAx, lAy), armPaint);
    canvas.drawLine(shlR, Offset(rAx, rAy), armPaint);

    // 球衣軀幹（填色）
    final jerseyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(fx, fy - 46*s), width: 24*s, height: 28*s),
      Radius.circular(4*s),
    );
    canvas.drawRRect(jerseyRect, Paint()..color = color.withOpacity(0.88));
    canvas.drawRRect(jerseyRect, Paint()
      ..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5*s);

    // 球衣號碼 #23
    final tp = TextPainter(
      text: TextSpan(
        text: '23',
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontSize: 9*s,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(fx - tp.width/2, fy - 54*s));

    // 頭
    canvas.drawCircle(head, 11*s, Paint()..color = color);
    // 眼睛（方向）
    final eyeX = head.dx + dir * 4*s;
    canvas.drawCircle(Offset(eyeX, head.dy - 1*s), 3*s, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(eyeX + dir*1.5*s, head.dy - 1*s), 1.5*s, Paint()..color = Colors.black87);

    // 球（持球中）
    if (state.playerHasBall) {
      final ballPos = state.isCharging
          ? Offset(shlR.dx + dir*14*s, shlR.dy + 8*s)   // 蓄力時球拉到側面
          : Offset(rAx + dir*2*s, rAy);                   // 跟著右手末端
      _drawBallAt(canvas, ballPos, kBallRadius * 0.9 * s);
    }

    // 光暈效果
    if (state.isCharging) {
      canvas.drawRRect(jerseyRect, Paint()
        ..color = Colors.orangeAccent.withOpacity(0.25 + state.chargeLevel * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14*s));
    }
    if (state.action == PlayerAction.dunk) {
      canvas.drawCircle(head, 22*s, Paint()
        ..color = const Color(0xFFFF2266).withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20*s));
    }
    if (state.action == PlayerAction.awakening) {
      canvas.drawCircle(head, 18*s, Paint()
        ..color = const Color(0xFFDE1A58).withOpacity(0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16*s));
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
