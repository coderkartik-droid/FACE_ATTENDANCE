import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:face_attendance_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FaceAttendanceApp(),
      ),
    );
    expect(find.byType(FaceAttendanceApp), findsOneWidget);
  });
}
