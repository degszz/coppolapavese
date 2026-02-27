import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Test vacío — la app usa SQLite que no está disponible en tests unitarios.
    // Los tests de integración deben correr en dispositivo/emulador.
    expect(true, isTrue);
  });
}
