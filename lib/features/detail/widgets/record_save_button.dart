import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// 기록 화면 아래의 '기록하기' 버튼.
///
/// 수유·배변·수면·체온·약이 같은 버튼을 각각 30줄씩 들고 있었습니다.
/// 체온만 `ButtonStyle`로 쓰고 나머지는 `ElevatedButton.styleFrom`을 써서
/// 코드가 미묘하게 갈려 있기도 했습니다.
///
/// 저장 중에는 눌리지 않습니다. 두 번 눌러 두 건이 들어가는 일을 막습니다.
class RecordSaveButton extends StatelessWidget {
  /// 저장 중이면 null을 넘기지 말고 [saving]을 켜세요. 이 버튼이 스스로
  /// 비활성화하고 진행 표시를 띄웁니다.
  final VoidCallback onPressed;

  final bool saving;

  /// 기본은 '기록하기'입니다. 다른 말이 필요한 화면만 넘깁니다.
  final String label;

  const RecordSaveButton({
    super.key,
    required this.onPressed,
    required this.saving,
    this.label = '기록하기',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  // 강조색 버튼 위라 두 테마 모두 흰색입니다.
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
