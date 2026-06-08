import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/db_config.dart';
import 'screens/home_screen.dart';

/// Zoom global de la app (0.8 a 1.2)
final zoomNotifier = ValueNotifier<double>(1.0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite en Windows/Linux/macOS requiere la implementación FFI
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Cargar configuración de ruta de BD (local o red)
  await DbConfig.instance.cargar();

  // Restaurar zoom guardado
  zoomNotifier.value = DbConfig.instance.zoom;

  // Inicializar datos de locale para formateo de fechas en español
  await initializeDateFormatting('es_AR', null);

  runApp(const InmobiliariaApp());
}

class InmobiliariaApp extends StatelessWidget {
  const InmobiliariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: zoomNotifier,
      builder: (context, zoom, _) {
        return MaterialApp(
          title: 'Coppola Pavese Inmobiliaria',
          debugShowCheckedModeBanner: false,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                borderSide:
                    const BorderSide(color: Color(0xFFC2185B), width: 2),
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
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(zoom),
              ),
              child: child!,
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
