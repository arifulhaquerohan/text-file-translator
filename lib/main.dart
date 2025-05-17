import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// Create this file or place ThemeNotifier in main.dart
// import 'package:text_file_translator/theme_provider.dart'; // If in a separate file
import 'package:text_file_translator/translator_page.dart'; // Adjust path to your translator_page.dart

// --- ThemeNotifier Class ---
// You can place this in a separate file like 'theme_provider.dart' and import it.
// For simplicity here, it's included in main.dart.

// const String _themePrefKey = 'appThemeMode'; // For shared_preferences persistence

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme

  ThemeNotifier() {
    // _loadThemeMode(); // Call this if you implement persistence
  }

  ThemeMode get currentThemeMode => _themeMode;

  void toggleTheme(bool isCurrentlyDark) {
    _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    // _saveThemeMode(_themeMode); // Call this if you implement persistence
    notifyListeners();
  }

  // More advanced cycle: Light -> Dark -> System -> Light
  void cycleThemeMode() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    // _saveThemeMode(_themeMode); // Call this if you implement persistence
    notifyListeners();
  }

  /*
  // --- Optional: Persistence with shared_preferences ---
  // Don't forget to add shared_preferences to pubspec.yaml and initialize WidgetsFlutterBinding
  // in main() if you load preferences in ThemeNotifier constructor.

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themePrefKey);
    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    // No need to call notifyListeners() here if called after _loadThemeMode in constructor
    // or if ThemeNotifier() constructor is async and main awaits it.
    // For simplicity, if loaded in constructor, MaterialApp will pick it up on first build.
    // If you call this method separately, then notifyListeners();
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, mode.index);
  }
  */
}

// --- Main Application Setup ---
void main() {
  // WidgetsFlutterBinding.ensureInitialized(); // Needed for some plugins if initialized before runApp
  // await dotenv.load(fileName: ".env"); // If using dotenv
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    const seedColor = Colors.deepPurple; // Or your preferred seed color

    return MaterialApp(
      title: 'Text File Translator',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.currentThemeMode,

      // --- Light Theme ---
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.latoTextTheme(
          ThemeData.light().textTheme,
        ).copyWith(
          titleLarge: GoogleFonts.montserrat(
            textStyle: ThemeData.light().textTheme.titleLarge,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: GoogleFonts.montserrat(
            textStyle: ThemeData.light().textTheme.headlineSmall,
            fontWeight: FontWeight.w600,
          ),
          labelLarge: GoogleFonts.lato(
            textStyle: ThemeData.light().textTheme.labelLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor:
              Colors
                  .transparent, // Example: Make AppBar transparent to use scaffold background
          elevation: 0,
          iconTheme: IconThemeData(
            color:
                ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.light,
                ).onPrimaryContainer,
          ),
          titleTextStyle: GoogleFonts.montserrat(
            color:
                ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.light,
                ).onPrimaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          color: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
          ).surfaceVariant.withOpacity(0.5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: seedColor, width: 1.5),
          ),
          filled: true,
          fillColor: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
          ).surface.withOpacity(0.9),
        ),
        scaffoldBackgroundColor:
            ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
            ).background,
        useMaterial3: true,
      ),

      // --- Dark Theme ---
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.latoTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(
          titleLarge: GoogleFonts.montserrat(
            textStyle: ThemeData.dark().textTheme.titleLarge,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: GoogleFonts.montserrat(
            textStyle: ThemeData.dark().textTheme.headlineSmall,
            fontWeight: FontWeight.w600,
          ),
          labelLarge: GoogleFonts.lato(
            textStyle: ThemeData.dark().textTheme.labelLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor:
              Colors.transparent, // Example: Make AppBar transparent
          elevation: 0,
          iconTheme: IconThemeData(
            color:
                ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.dark,
                ).onPrimaryContainer,
          ),
          titleTextStyle: GoogleFonts.montserrat(
            color:
                ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.dark,
                ).onPrimaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          color: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          ).surfaceVariant.withOpacity(0.3),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: seedColor, width: 1.5),
          ),
          filled: true,
          fillColor: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          ).surface.withOpacity(0.9),
        ),
        scaffoldBackgroundColor:
            ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
            ).background,
        useMaterial3: true,
      ),
      home: const FileTranslatorPage(),
    );
  }
}
