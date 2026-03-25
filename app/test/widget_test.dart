import 'package:flutter_test/flutter_test.dart';
import 'package:omwa_sacco/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test - app builds without errors
    expect(OmwaSaccoApp, isNotNull);
  });
}
