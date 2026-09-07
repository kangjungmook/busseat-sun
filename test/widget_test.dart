import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sunseat/main.dart';
import 'package:sunseat/state/app_state.dart';

void main() {
  testWidgets('앱이 로그인 화면으로 시작한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const SunSeatApp(),
      ),
    );
    await tester.pump();

    expect(find.text('햇살좌석'), findsOneWidget);
    expect(find.text('카카오로 3초 만에 시작'), findsOneWidget);
  });
}
