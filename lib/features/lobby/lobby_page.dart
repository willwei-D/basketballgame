import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lobby_bloc.dart';
import '../pregame/pregame_page.dart';

class BattleLobbyPage extends StatelessWidget {
  const BattleLobbyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BattleLobbyBloc()..add(LoadLobbyInfo()),
      child: Scaffold(
        backgroundColor: const Color(0xFF050044),
        body: BlocConsumer<BattleLobbyBloc, BattleLobbyState>(
          listener: (context, state) {
            if (state is GameStarting) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const InGameUiPage()),
              );
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                const _NeonGridBackground(),
                const _TopAppBar(),
                if (state is BattleLobbyLoading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFFDE1A58)))
                else if (state is BattleLobbyLoaded)
                  _MainContent(playerName: state.playerName),
                const _DigitalMatrixHud(),
                const _SideDataStrip(),
                const _DigitalNoiseOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DigitalNoiseOverlay extends StatelessWidget {
  const _DigitalNoiseOverlay();

  @override
  Widget build(BuildContext context) {
    // simplified noise using a semi-transparent black overlay for atmosphere
    return IgnorePointer(
      child: Container(
        color: Colors.black.withOpacity(0.05),
      ),
    );
  }
}

class _NeonGridBackground extends StatelessWidget {
  const _NeonGridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NeonGridPainter(),
      child: Container(),
    );
  }
}

class _NeonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6664E8).withOpacity(0.15)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
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
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF050044).withOpacity(0.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDE1A58).withOpacity(0.3),
                  blurRadius: 15,
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view, color: Color(0xFFDE1A58)),
                const SizedBox(width: 16),
                Text(
                  'NEON_CORE_V1.0',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
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

class _MainContent extends StatelessWidget {
  final String playerName;
  const _MainContent({required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CONNECTED_TO_SYSTEM_ALPHA',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFFFF9659), // tertiary-fixed
              fontSize: 12,
              letterSpacing: 5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE5E3FF), Color(0xFF6664E8), Color(0xFFE5E3FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              'CORE\nCRUSHER',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                height: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'WELCOME, $playerName',
            style: GoogleFonts.manrope(
              color: const Color(0xFFE5E3FF).withOpacity(0.8),
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 48),
          _NeonActionButton(
            label: 'START BATTLE',
            color: const Color(0xFFF57C30),
            sublabel: '[CLICK TO START]',
            onPressed: () {
              context.read<BattleLobbyBloc>().add(StartGame());
            },
          ),
        ],
      ),
    );
  }
}

class _NeonActionButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onPressed;

  const _NeonActionButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border(
            top: BorderSide(color: color, width: 2),
            bottom: BorderSide(color: color, width: 2),
            left: BorderSide(color: color, width: 2),
            right: BorderSide(color: color, width: 2),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              style: GoogleFonts.spaceMono(
                color: color.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitalMatrixHud extends StatelessWidget {
  const _DigitalMatrixHud();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 320,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF120088).withOpacity(0.4),
            border: Border.all(color: const Color(0xFF3631B8).withOpacity(0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SYSTEM_HUB_ONLINE',
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFFF57C30),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HudItem(title: 'CPU_TEMP', value: '42°C'),
                  _HudItem(title: 'SYNC_RT', value: '98%'),
                  _HudItem(title: 'LATENCY', value: '12MS'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _HudItem extends StatelessWidget {
  final String title;
  final String value;

  const _HudItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFFF71D8),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SideDataStrip extends StatelessWidget {
  const _SideDataStrip();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 24,
      top: MediaQuery.of(context).size.height / 2 - 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _DataStripItem('PILOT_ID', 'XERO_ONE', const Color(0xFFFF9A61)),
          const SizedBox(height: 24),
          _DataStripItem('RANK_SCORE', '882,100', const Color(0xFFFF71D8)),
          const SizedBox(height: 24),
          _DataStripItem('GLOBAL_POS', '#004', const Color(0xFF6664E8)),
        ],
      ),
    );
  }
}

class _DataStripItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _DataStripItem(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: color, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceMono(
              color: color.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
