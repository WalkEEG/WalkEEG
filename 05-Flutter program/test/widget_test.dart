import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_walkeeg/main.dart';

void main() {
  testWidgets('WalkEEG home shows title and channel chips', (tester) async {
    await tester.pumpWidget(const WalkEegApp());

    expect(find.text('WalkEEG'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('CH0'), findsOneWidget);
    expect(find.text('CH7'), findsOneWidget);
  });
}
