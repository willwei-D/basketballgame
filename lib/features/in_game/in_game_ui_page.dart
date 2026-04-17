import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'in_game_ui_bloc.dart';
import '../gameplay_action/gameplay_action_page.dart';
import '../../domain/entities/match_history.dart';

class InGameUiPage extends StatelessWidget {
  const InGameUiPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InGameUiBloc()..add(StartMatchSession()),
      child: Scaffold(
        backgroundColor: const Color(0xFF050044),
        body: BlocConsumer<InGameUiBloc, InGameUiState>(
          listener: (context, state) {
            if (state is MatchEnding) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GameplayActionPage()),
              );
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                const _ParallaxBackground(),
                const _TopAppBar(),
                const _ControlsGuide(),
                const _MatchHistoryPanel(),
                const _CRTScanlineOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CRTScanlineOverlay extends StatelessWidget {
  const _CRTScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withOpacity(0.1),
      ),
    );
  }
}

class _ParallaxBackground extends StatelessWidget {
  const _ParallaxBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF050044),
        child: Center(
          child: Container(
            height: 1,
            width: double.infinity,
            color: const Color(0xFF6664E8).withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6664E8).withOpacity(0.5), blurRadius: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF050044).withOpacity(0.9),
              border: const Border(bottom: BorderSide(color: Color(0xFFDE1A58), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grid_view, color: Color(0xFFDE1A58)),
                    const SizedBox(width: 16),
                    Text(
                      'NEON_CORE_V1.0',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic, letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    context.read<InGameUiBloc>().add(EndMatchSession());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDE1A58).withOpacity(0.2),
                      border: Border.all(color: const Color(0xFFDE1A58)),
                    ),
                    child: Text(
                      'ENTER GAME',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFFDE1A58), fontWeight: FontWeight.bold, fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlsGuide extends StatelessWidget {
  const _ControlsGuide();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 90,
      left: 32,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF070045).withOpacity(0.9),
          border: Border.all(color: const Color(0xFF3631B8).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CONTROLS',
                style: GoogleFonts.pressStart2p(
                    color: const Color(0xFFFF71D8), fontSize: 8, letterSpacing: 2)),
            const SizedBox(height: 12),
            ..._controls.map((c) => _ControlRow(keyLabel: c[0], desc: c[1])),
          ],
        ),
      ),
    );
  }

  static const _controls = [
    ['A / D', 'Move left / right'],
    ['W', 'Jump'],
    ['S (hold)', 'Charge shot'],
    ['W near hoop', 'Dunk'],
    ['Q / E', 'Block jump'],
    ['Z', 'Step back'],
    ['X', 'Crouch'],
    ['C', 'Awakening'],
  ];
}

class _ControlRow extends StatelessWidget {
  final String keyLabel;
  final String desc;
  const _ControlRow({super.key, required this.keyLabel, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF57C30).withOpacity(0.7)),
              color: const Color(0xFFF57C30).withOpacity(0.1),
            ),
            child: Text(keyLabel,
                style: GoogleFonts.spaceMono(
                    color: const Color(0xFFF57C30), fontSize: 9)),
          ),
          const SizedBox(width: 8),
          Text(desc,
              style: GoogleFonts.spaceMono(color: Colors.white60, fontSize: 9)),
        ],
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Body
    final bodyColor = const Color(0xFFFF71D8);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 22, cy - 15, 44, 55),
      const Radius.circular(6),
    );
    canvas.drawRRect(bodyRect, Paint()..color = bodyColor.withOpacity(0.85));

    // Jersey number
    final tp = TextPainter(
      text: TextSpan(
        text: '23',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 2));

    // Head
    canvas.drawCircle(
      Offset(cx, cy - 26),
      16,
      Paint()..color = bodyColor,
    );
    // Eye
    canvas.drawCircle(
      Offset(cx + 5, cy - 27),
      3,
      Paint()..color = Colors.white,
    );

    // Left arm (holding ball)
    final armPath = Path()
      ..moveTo(cx - 22, cy - 5)
      ..lineTo(cx - 38, cy + 10)
      ..lineTo(cx - 34, cy + 14)
      ..lineTo(cx - 18, cy + 2)
      ..close();
    canvas.drawPath(armPath, Paint()..color = bodyColor);

    // Basketball in left hand
    canvas.drawCircle(
      Offset(cx - 40, cy + 18),
      12,
      Paint()..color = const Color(0xFFE8600A),
    );
    canvas.drawCircle(
      Offset(cx - 40, cy + 18),
      12,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(cx - 40, cy + 6),
      Offset(cx - 40, cy + 30),
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..strokeWidth = 1.5,
    );

    // Legs
    final legPaint = Paint()..color = const Color(0xFF6633BB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 20, cy + 38, 18, 30),
        const Radius.circular(4),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 2, cy + 38, 18, 30),
        const Radius.circular(4),
      ),
      legPaint,
    );

    // Shoes
    final shoePaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 22, cy + 64, 22, 10),
        const Radius.circular(3),
      ),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy + 64, 22, 10),
        const Radius.circular(3),
      ),
      shoePaint,
    );

    // Glow outline
    canvas.drawCircle(
      Offset(cx, cy),
      size.width / 2,
      Paint()
        ..color = const Color(0xFFFF71D8).withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(_CharacterPainter old) => false;
}

class _MatchHistoryPanel extends StatelessWidget {
  const _MatchHistoryPanel();

  @override
  Widget build(BuildContext context) {
    final records = MatchHistory.records;
    return Positioned(
      top: 90,
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 角色圖像
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0C0040),
                  border: Border.all(color: const Color(0xFFFF71D8), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFDE1A58), blurRadius: 30),
                  ],
                ),
                child: ClipOval(
                  child: CustomPaint(painter: _CharacterPainter()),
                ),
              ),
              const SizedBox(height: 24),
              // 對戰紀錄卡片
              Container(
                width: 680,
                decoration: BoxDecoration(
                  color: const Color(0xFF070045).withOpacity(0.95),
                  border: Border.all(color: const Color(0xFF6664E8), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF3631B8), blurRadius: 40),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(width: 4, height: 24, color: const Color(0xFFFF71D8)),
                        const SizedBox(width: 12),
                        Text(
                          'MATCH  HISTORY',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFFFF71D8),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${records.length} / 5  RECORDS',
                          style: GoogleFonts.spaceMono(color: Colors.white24, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _headerCell('RANK', 60),
                          _headerCell('FG%', 110),
                          _headerCell('SCORE', 200),
                          _headerCell('SHOTS', 130),
                          _headerCell('TIME', 100),
                        ],
                      ),
                    ),
                    Container(height: 1, color: const Color(0xFF3631B8)),
                    const SizedBox(height: 8),
                    if (records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'NO RECORDS YET\nPLAY YOUR FIRST MATCH',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                                color: Colors.white24, fontSize: 13, height: 2),
                          ),
                        ),
                      )
                    else
                      ...records.asMap().entries.map(
                            (e) => _HistoryRow(result: e.value, index: e.key),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(label,
          style: GoogleFonts.spaceMono(
              color: Colors.white38, fontSize: 10, letterSpacing: 2)),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final MatchResult result;
  final int index;
  const _HistoryRow({required this.result, required this.index});

  Color _rankColor(String rank) {
    switch (rank) {
      case 'S': return const Color(0xFFFFD700);
      case 'A': return const Color(0xFFFF71D8);
      case 'B': return const Color(0xFF6664E8);
      case 'C': return const Color(0xFF4FC3F7);
      default:  return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = result.shotsFired == 0
        ? '--%'
        : '${result.shootingPct.toStringAsFixed(1)}%';
    final rankColor = _rankColor(result.rank);
    final ago = _timeAgo(result.time);
    final isLatest = index == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isLatest
            ? const Color(0xFF1A0060).withOpacity(0.6)
            : Colors.transparent,
        border: Border(
          left: BorderSide(
              color: isLatest ? rankColor : Colors.transparent, width: 3),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 60,
            child: Container(
              width: 40,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: rankColor, width: 2),
                boxShadow: [BoxShadow(color: rankColor.withOpacity(0.3), blurRadius: 8)],
              ),
              child: Text(
                result.rank,
                style: GoogleFonts.pressStart2p(
                    color: rankColor, fontSize: 13,
                    shadows: [Shadow(color: rankColor, blurRadius: 6)]),
              ),
            ),
          ),
          // FG%
          SizedBox(
            width: 110,
            child: Text(
              pct,
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic),
            ),
          ),
          // Score
          SizedBox(
            width: 200,
            child: Text(
              'HOME  ${result.homeScore}  –  ${result.guestScore}  GUEST',
              style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFFF67D31),
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ),
          // Shots
          SizedBox(
            width: 130,
            child: Text(
              '${result.shotsScored} / ${result.shotsFired} shots',
              style: GoogleFonts.spaceMono(color: Colors.white54, fontSize: 11),
            ),
          ),
          // Time
          Text(
            ago,
            style: GoogleFonts.spaceMono(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
