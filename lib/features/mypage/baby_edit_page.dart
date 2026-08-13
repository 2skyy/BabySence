import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
import '../../core/services/growth_calculator.dart' show ChildSex;
import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/common_button.dart';
import '../detail/growth/growth_record.dart';
import '../detail/growth/growth_record_service.dart';

/// 아이 정보 수정.
///
/// 예전에는 등록만 있고 고칠 길이 없었습니다. 오타를 냈거나 생년월일을 잘못
/// 넣으면 되돌릴 방법이 앱 안에 없었고, 생년월일은 체온·성장 판정의 기준이라
/// 틀린 채로 두면 판정도 계속 틀립니다.
///
/// 키·몸무게도 여기서 넣을 수 있습니다. 다만 이 둘은 `babies`의 칸이
/// 아니라 **날짜와 함께 남는 성장 기록**입니다 — 자라면서 변하는 값이라
/// "언제 잰 것인지"가 없으면 곡선을 그릴 수 없습니다.
///
/// 그래서 여기서 적은 값은 **오늘 잰 것으로** 남습니다. 화면에도 그렇게
/// 적어 두었고, 지금 값 옆에는 마지막으로 잰 날짜를 함께 보여줍니다.
/// 과거 날짜를 고치는 것은 성장 기록 화면에서 합니다.
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

  final _height = TextEditingController();
  final _weight = TextEditingController();

  /// 마지막으로 남긴 성장 기록. 지금 값과 잰 날짜를 보여주는 데 씁니다.
  GrowthRecord? _latestGrowth;

  /// 성장 기록을 못 읽었는지. **못 읽은 것과 기록이 없는 것은 다릅니다** —
  /// 못 읽었는데 빈 칸을 보여주면 "아직 안 쟀구나"로 읽히고, 저장하면
  /// 오늘 값으로 덮어씁니다.
  bool _growthFailed = false;
  bool _loadingGrowth = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadGrowth();
  }

  Future<void> _loadGrowth() async {
    try {
      final records = await GrowthRecordService.loadRecords(widget.baby.id);
      if (!mounted) return;
      setState(() {
        // 오름차순이라 마지막이 가장 최근입니다.
        _latestGrowth = records.isEmpty ? null : records.last;
        _loadingGrowth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _growthFailed = true;
        _loadingGrowth = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// 지금 값이 처음과 다른지. 바뀐 것이 없으면 저장 버튼을 잠급니다.
  bool get _changed =>
      _name.text.trim() != widget.baby.name ||
      _sex != widget.baby.sex ||
      _birthDate != widget.baby.birthDate ||
      _height.text.trim().isNotEmpty ||
      _weight.text.trim().isNotEmpty;

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

    // growth_records의 CHECK 제약과 같은 범위입니다. 여기서 안 막으면
    // `numeric field overflow` 영문 예외가 그대로 스낵바에 뜹니다.
    final height = double.tryParse(_height.text.trim());
    if (_height.text.trim().isNotEmpty &&
        (height == null || height < 20 || height > 150)) {
      _notify('키는 20~150cm 사이로 입력해 주세요.');
      return;
    }
    final weight = double.tryParse(_weight.text.trim());
    if (_weight.text.trim().isNotEmpty &&
        (weight == null || weight < 0.5 || weight > 40)) {
      _notify('몸무게는 0.5~40kg 사이로 입력해 주세요.');
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

      // 키·몸무게는 **오늘 잰 성장 기록**으로 남깁니다. babies의 칸이
      // 아니라서 날짜가 함께 있어야 곡선을 그릴 수 있습니다.
      //
      // 아이 정보는 이미 저장됐으므로, 여기서 실패해도 통째로 실패했다고
      // 말하면 안 됩니다 — 다시 눌러 이름을 또 저장하게 됩니다.
      if (height != null || weight != null) {
        try {
          final now = DateTime.now();
          await GrowthRecordService.saveRecord(
            babyId: widget.baby.id,
            date: DateTime(now.year, now.month, now.day),
            heightCm: height,
            weightKg: weight,
          );
        } catch (e) {
          if (!mounted) return;
          _notify('아이 정보는 저장했지만 키·몸무게는 남기지 못했습니다. $e');
          Navigator.pop(context, updated);
          return;
        }
      }

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
            _buildGrowthSection(),

            const SizedBox(height: AppSpacing.xxl),
            CommonButton(
              text: '저장',
              isLoading: _saving,
              // 바뀐 것이 없으면 누를 이유가 없습니다.
              onPressed: _changed ? _save : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '지난 날짜의 키·몸무게를 고치려면 홈의 성장 기록 화면에서 '
              '하세요. 여기서 적은 값은 오늘 잰 것으로 남습니다.',
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

  /// 키·몸무게 칸.
  ///
  /// 지금 값을 **미리 채우지 않습니다.** 채워 두면 저장 버튼을 누르는 것만으로
  /// 지난달에 잰 값이 오늘 값으로 다시 남습니다. 빈 칸으로 두고, 적었을 때만
  /// 오늘 기록을 만듭니다.
  Widget _buildGrowthSection() {
    final latest = _latestGrowth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '키 · 몸무게',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 지금 값과 잰 날짜. 못 읽었으면 그렇게 말합니다 — 빈 칸을 보여주면
        // "아직 안 쟀구나"로 읽힙니다.
        Text(
          _loadingGrowth
              ? '지난 기록을 불러오는 중이에요…'
              : _growthFailed
                  ? '지난 기록을 불러오지 못했어요. 지금 적으면 오늘 기록으로 남습니다.'
                  : latest == null
                      ? '아직 남긴 기록이 없어요.'
                      : '${_formatDate(latest.date)}에 잰 값: ${_describe(latest)}',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: _growthFailed
                ? Colors.orange.shade700
                : context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '키 (cm)',
                  hintText: '오늘 잰 값',
                  filled: true,
                  fillColor: context.colors.surface,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '몸무게 (kg)',
                  hintText: '오늘 잰 값',
                  filled: true,
                  fillColor: context.colors.surface,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.'
      '${d.day.toString().padLeft(2, '0')}';

  static String _describe(GrowthRecord r) => [
        if (r.heightCm != null) '키 ${r.heightCm!.toStringAsFixed(1)}cm',
        if (r.weightKg != null) '몸무게 ${r.weightKg!.toStringAsFixed(1)}kg',
      ].join(' · ');

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
