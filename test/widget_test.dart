import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photo_editor_ai/src/app.dart';

void main() {
  testWidgets('app shows editor title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PhotoEditorAiApp(),
      ),
    );

    expect(find.text('AI Photo Editor'), findsOneWidget);
  });
}
