import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/db_config.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite en Windows/Linux/macOS requiere la implementación FFI
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Cargar configuración de ruta de BD (local o red)
  await DbConfig.instance.cargar();

  // Inicializar datos de locale para formateo de fechas en español
  await initializeDateFormatting('es_AR', null);

  runApp(const InmobiliariaApp());
}

class InmobiliariaApp extends StatelessWidget {
  const InmobiliariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coppola Pavese Inmobiliaria',
      debugShowCheckedModeBanner: false,
      // Localización en español para DatePicker y otros widgets de Material
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es', 'AR'),
      theme: ThemeData(
        // Paleta extraída del logo Coppola Pavese Inmobiliaria:
        // Primary  → Fucsia/Magenta #C2185B  (texto "COPPOLA PAVESE")
        // Secondary→ Negro         #212121   (llave, "INMOBILIARIA")
        // Surface  → Blanco        #FFFFFF   (fondo del logo)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC2185B),
          primary: const Color(0xFFC2185B),
          secondary: const Color(0xFF212121),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFC2185B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2185B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF212121),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFC2185B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFC2185B), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFC2185B)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE0E0E0),
          thickness: 1,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFF212121),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          headlineMedium: TextStyle(
            color: Color(0xFF212121),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF212121),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          bodyLarge: TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF666666),
            fontSize: 12,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
