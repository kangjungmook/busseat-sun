import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sunseat/main.dart';
import 'package:sunseat/state/app_state.dart';

/// 앱이 뜨는지, 그리고 **들어갈 수 있는 입구가 있는지**.
///
/// 이 테스트는 dart-define 없이 돌기 때문에 앱 입장에서는 키가 없는 빌드다.
/// 그 상태에서는 카카오 로그인이 실패하므로 로그인 화면이 '예시 노선
/// 둘러보기'를 주 버튼으로 내놓는다. 예전 테스트는 '카카오로 3초 만에 시작'을
/// 찾고 있었고, 로그인 화면을 바꾼 뒤로 계속 실패하고 있었다.
void main() {
  testWidgets('앱이 로그인 화면으로 시작하고, 들어갈 입구가 있다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const SunSeatApp(),
      ),
    );
    await tester.pump();

    expect(find.text('햇살좌석'), findsOneWidget);
    // 키 없는 빌드의 입구. 키가 있으면 여기가 카카오 버튼으로 바뀐다.
    expect(find.text('예시 노선 둘러보기'), findsOneWidget);
  });
}
