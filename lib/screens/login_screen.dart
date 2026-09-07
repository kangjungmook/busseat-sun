import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/app_icon.dart';
import '../widgets/common.dart';

class LoginScreen extends StatelessWidget {
  final AppPalette palette;

  const LoginScreen({super.key, required this.palette});

  Future<void> _kakaoLogin(BuildContext context) async {
    final state = context.read<AppState>();
    final error = await state.loginWithKakao();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIconMark(size: 88),
                  const SizedBox(height: 18),
                  Text(
                    '햇살좌석',
                    style: TextStyle(
                      fontFamily: AppTextStyles.family,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.6,
                      height: 1.15,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '버스 타기 직전 3초.\n어느 쪽 창가에 앉을지만 알려드려요.',
                    style: TextStyle(
                      fontFamily: AppTextStyles.family,
                      fontSize: 16,
                      color: palette.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: Material(
                    color: kKakaoYellow,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      onTap: state.locationLoading ? null : () => _kakaoLogin(context),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble, color: kKakaoInk, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '카카오로 3초 만에 시작',
                              style: TextStyle(
                                fontFamily: AppTextStyles.family,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: kKakaoInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GhostButton(text: '먼저 둘러보기', onTap: state.loginAsGuest, palette: palette),
                const SizedBox(height: 10),
                Text(
                  '로그인하면 자주 타는 노선이 기기 간에 동기화돼요.\n위치는 좌석 계산에만 쓰이고 저장되지 않습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 11, color: palette.textMuted, height: 1.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
