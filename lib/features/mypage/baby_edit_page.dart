import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
import '../../core/services/growth_calculator.dart' show ChildSex;
import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/common_button.dart';

/// 아이 정보 수정.
///
/// 예전에는 등록만 있고 고칠 길이 없었습니다. 오타를 냈거나 생년월일을 잘못
/// 넣으면 되돌릴 방법이 앱 안에 없었고, 생년월일은 체온·성장 판정의 기준이라
/// 틀린 채로 두면 판정도 계속 틀립니다.
///
/// 키·몸무게는 여기서 고치지 않습니다. 자라면서 변하는 측정값이라 성장 기록
/// 쪽이 맞는 자리이고, 여기서 고치면 "언제 잰 값인지"가 사라집니다.
class BabyEditPage extends StatefulWidget {
  final Baby baby;

  const BabyEditPage({super.key, required this.baby});

  @override
  State<BabyEditPage> createState() => _BabyEditPageState();
}

class _BabyEditPageState extends State<BabyEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.baby.name);
  late ChildSex _sex = widget.baby.sex;
  late DateTime _birthDate = widget.baby.birthDate;

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 지금 값이 처음과 다른지. 바뀐 것이 없으면 저장 버튼을 잠급니다.
  bool get _changed =>
      _name.text.trim() != widget.baby.name ||
      _sex != widget.baby.sex ||
      _birthDate != widget.baby.birthDate;

  bool get _birthDateChanged => _birthDate != widget.baby.birthDate;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _notify('이름을 입력해 주세요.');
      return;
    }
    // babies.name의 CHECK 제약과 같은 범위입니다.
    if (name.length > 20) {
      _notify('이름은 20자 이하로 입력해 주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await BabyService.update(
        id: widget.baby.id,
        name: name,
        sex: _sex,
        birthDate: _birthDate,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      _notify('저장하지 못했습니다. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const CommonAppBar(title: '아이 정보 수정'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            TextField(
              controller: _name,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '이름',
                counterText: '',
                filled: true,
                fillColor: context.colors.surface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            InkWell(
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '생년월일',
                  filled: true,
                  fillColor: context.colors.surface,
                ),
                child: Text(
                  '${_birthDate.year}.'
                  '${_birthDate.month.toString().padLeft(2, '0')}.'
                  '${_birthDate.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 16,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ),

            // 생년월일은 체온·성장 판정의 기준입니다. 바꾸면 앞으로의 판정이
            // 달라진다는 것을 미리 알려줍니다.
            if (_birthDateChanged) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: context.colors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '생년월일은 체온·성장 판정의 기준이 됩니다. '
                      '앞으로의 판정이 달라지며, 이미 남은 판정은 그대로 둡니다 '
                      '— 잴 때의 개월 수로 계산한 값이기 때문입니다.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(child: _sexButton(ChildSex.male, '남아')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _sexButton(ChildSex.female, '여아')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '성별은 WHO 성장 표준에서 남녀 곡선이 달라 판정에 쓰입니다.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            CommonButton(
              text: '저장',
              isLoading: _saving,
              // 바뀐 것이 없으면 누를 이유가 없습니다.
              onPressed: _changed ? _save : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '키와 몸무게는 성장 기록에서 고칩니다. 잰 날짜와 함께 남아야 '
              '곡선을 그릴 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sexButton(ChildSex sex, String label) {
    final selected = _sex == sex;
    return InkWell(
      onTap: () => setState(() => _sex = sex),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
