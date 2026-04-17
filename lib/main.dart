import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/battle_lobby/battle_lobby_page.dart';

void main() {
  runApp(const NeonCoreApp());
}

class NeonCoreApp extends StatelessWidget {
  const NeonCoreApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Core 2D Strike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050044), // Matches Tailwind bg
        primaryColor: const Color(0xFFFF8B9E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF8B9E),
          secondary: Color(0xFFFF71D8),
          surface: Color(0xFF050044),
          error: Color(0xFFFF716C),
        ),
        textTheme: GoogleFonts.manropeTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: const Color(0xFFE5E3FF)),
        ).copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(),
          displayMedium: GoogleFonts.spaceGrotesk(),
          displaySmall: GoogleFonts.spaceGrotesk(),
          headlineLarge: GoogleFonts.spaceGrotesk(),
          headlineMedium: GoogleFonts.spaceGrotesk(),
          headlineSmall: GoogleFonts.spaceGrotesk(),
          titleLarge: GoogleFonts.spaceGrotesk(),
          titleMedium: GoogleFonts.spaceGrotesk(),
          titleSmall: GoogleFonts.spaceGrotesk(),
          labelLarge: GoogleFonts.spaceGrotesk(),
          labelMedium: GoogleFonts.spaceGrotesk(),
          labelSmall: GoogleFonts.spaceGrotesk(),
        ),
      ),
      // To strictly enforce Landscape / Desktop web view, we can wrap the home in a layout builder
      home: const DesktopLayoutWrapper(child: BattleLobbyPage()),
    );
  }
}

/// Enforces a landscape-like layout, preventing portrait weirdness on mobile web.
class DesktopLayoutWrapper extends StatelessWidget {
  final Widget child;
  const DesktopLayoutWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < constraints.maxHeight || constraints.maxWidth < 800) {
          // If in portrait or small screen, show a message advising to rotate or use desktop
          return Scaffold(
            backgroundColor: const Color(0xFF050044),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Please rotate your device or use a desktop browser for the optimal Neon Core experience.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFFFF8B9E),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
