import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'results_bloc.dart';
import '../lobby/lobby_page.dart';
import '../pregame/pregame_page.dart';

class PostGameResultsPage extends StatelessWidget {
  final int shotsFired;
  final int shotsScored;

  const PostGameResultsPage({
    Key? key,
    this.shotsFired = 0,
    this.shotsScored = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PostGameResultsBloc(
        shotsFired: shotsFired,
        shotsScored: shotsScored,
      )..add(LoadResults()),
      child: Scaffold(
        backgroundColor: const Color(0xFF050044),
        body: BlocConsumer<PostGameResultsBloc, PostGameResultsState>(
          listener: (context, state) {
            if (state is NavigatingToLobby) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const BattleLobbyPage()),
              );
            } else if (state is NavigatingToRematch) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const InGameUiPage()),
              );
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                const _BackgroundGrid(),
                const _TopAppBar(),
                if (state is PostGameResultsLoaded)
                  _ResultsContent(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BackgroundGrid extends StatelessWidget {
  const _BackgroundGrid();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3631B8).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            ),
            child: Row(
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
          ),
        ),
      ),
    );
  }
}

class _ResultsContent extends StatelessWidget {
  final PostGameResultsLoaded state;

  const _ResultsContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        child: SingleChildScrollView(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RankDisplay(rank: state.rank),
              _CenterOrb(pct: state.shootingPct, fired: state.shotsFired, scored: state.shotsScored),
              _StatsPanel(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankDisplay extends StatelessWidget {
  final String rank;
  const _RankDisplay({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'CLASSIFICATION_SYNC',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFFFF9A61).withOpacity(0.5), fontSize: 12, letterSpacing: 4,
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              rank,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 180, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic,
                color: const Color(0xFFFF8B9E),
                shadows: [
                  BoxShadow(color: const Color(0xFFDE1A58).withOpacity(0.8), blurRadius: 40)
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: const Color(0xFFFF9A61),
                child: Text(
                  'MASTER_RANK',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF582300), fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CenterOrb extends StatelessWidget {
  final double pct;
  final int fired;
  final int scored;

  const _CenterOrb({required this.pct, required this.fired, required this.scored});

  @override
  Widget build(BuildContext context) {
    final pctStr = fired == 0 ? '--%' : '${pct.toStringAsFixed(1)}%';
    return Container(
      width: 250, height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFFDE1A58), Color(0xFF050044)]),
        boxShadow: [
          BoxShadow(color: const Color(0xFFDE1A58).withOpacity(0.6), blurRadius: 60)
        ],
        border: Border.all(color: const Color(0xFFFF71D8), width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              pctStr,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              'FG%',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFFFA9E1), fontSize: 12, letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$scored / $fired',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final PostGameResultsLoaded state;

  const _StatsPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE_METRICS',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          _StatBar('POINTS (PTS)', state.points.toString(), const Color(0xFFF67D31), (state.points / 50).clamp(0.0, 1.0)),
          if (state.blocks > 0) ...[
            const SizedBox(height: 16),
            _StatBar('BLOCKS (BLK)', state.blocks.toString(), const Color(0xFFDE1A58), (state.blocks / 20).clamp(0.0, 1.0)),
          ],
          if (state.assists > 0) ...[
            const SizedBox(height: 16),
            _StatBar('ASSISTS (AST)', state.assists.toString(), const Color(0xFF8F0177), (state.assists / 20).clamp(0.0, 1.0)),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.read<PostGameResultsBloc>().add(Rematch()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFFFF9A61),
                    alignment: Alignment.center,
                    child: Text(
                      'REMATCH',
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF2E0F00), fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.read<PostGameResultsBloc>().add(ReturnToLobby()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF6664E8), width: 2),
                      color: const Color(0xFF120088).withOpacity(0.6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'RETURN LOBBY',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final String value;
  final Color fill;
  final double percentage;

  const _StatBar(this.label, this.value, this.fill, this.percentage);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.spaceGrotesk(color: fill, fontSize: 10, fontStyle: FontStyle.italic)),
            Text(value, style: GoogleFonts.spaceGrotesk(color: fill, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity, height: 20,
          color: const Color(0xFF120088).withOpacity(0.6),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                boxShadow: [BoxShadow(color: fill.withOpacity(0.6), blurRadius: 10)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
