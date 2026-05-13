import 'package:flutter_test/flutter_test.dart';
import 'package:cocomaru_petcam/main.dart';

void main() {
  testWidgets('Home screen shows app title and mode buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CocomaruApp());

    expect(find.text('ココ丸ちゃんねる'), findsOneWidget);
    expect(find.text('カメラモード'), findsOneWidget);
    expect(find.text('ビュワーモード'), findsOneWidget);
  });
}
