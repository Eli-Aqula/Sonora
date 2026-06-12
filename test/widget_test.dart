import 'package:flutter_test/flutter_test.dart';

void main() {
  // App smoke test нужен MediaKit с нативными библиотеками, который в
  // unit-окружении flutter_test не доступен. Реальный запуск UI
  // проверяется через `flutter build windows --release` + ручной smoke
  // на собранном EXE.
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
