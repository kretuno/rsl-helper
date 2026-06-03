import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/theme/app_colors.dart';
import 'src/ui/screens/shard_overview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isFirebaseSupported = kIsWeb || (!Platform.isWindows && !Platform.isLinux);
  if (isFirebaseSupported) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        size: Size(1280, 850),
        minimumSize: Size(960, 700),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'RSL Shard Memory',
      );
      
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setResizable(false);
      });
    } catch (e) {
      debugPrint('WindowManager initialization failed: $e');
    }
  }

  runApp(const ShardMercyApp());
}

class ShardMercyApp extends StatelessWidget {
  const ShardMercyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RSL Shard Memory',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
          surface: AppColors.panel,
          surfaceContainer: AppColors.card,
          onSurface: Colors.white,
          outline: AppColors.border,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardThemeData(
          color: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      home: const ShardOverviewScreen(),
    );
  }
}
