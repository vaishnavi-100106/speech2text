import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:greenvoice/providers/audio_recorder_provider.dart';
import 'package:greenvoice/providers/theme_provider.dart';
import 'package:greenvoice/providers/settings_provider.dart';
import 'package:greenvoice/screens/splash_screen.dart';
import 'package:greenvoice/screens/home_screen.dart';
import 'package:greenvoice/screens/history_screen.dart';
import 'package:greenvoice/screens/settings_screen.dart';
import 'package:greenvoice/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioRecorderProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const GreenVoiceApp(),
    ),
  );
}

class GreenVoiceApp extends StatelessWidget {
  const GreenVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'GreenVoice',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
          routes: {
            '/home': (context) => const HomeScreen(),
            '/history': (context) => const HistoryScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
