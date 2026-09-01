import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

import '../../core/services/baby_service.dart';
import '../../core/services/growth_calculator.dart';
import '../detail/growth/growth_record_service.dart';
import '../../routes/app_routes.dart';

/// 로그인 후 등록된 아이가 없을 때 보여주는 최초 온보딩 화면.
///
/// babies 테이블에 아이를 만들고, 입력받은 키·몸무게는 오늘 날짜의
/// growth_records 한 건으로 함께 저장합니다.
/// (babies에는 키·몸무게 컬럼이 없습니다. 자라면서 변하는 측정값이라
///  성장 기록 쪽이 맞는 자리입니다.)
///
/// 키는 **선택**입니다. 몸무게만 아는 채로 오는 보호자가 많고, WHO 판정은
/// 둘 중 하나만 있어도 됩니다. 다만 키가 있어야 신장 곡선을 그릴 수 있어
/// 비워 두면 그 사실을 알려줍니다.
class ChildInfoPage extends StatefulWidget {
  const ChildInfoPage({super.key});

  @override
  State<ChildInfoPage> createState() => _ChildInfoPageState();
}

class _ChildInfoPageState extends State<ChildInfoPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  DateTime? _birthDate;
  ChildSex? _sex;
  bool _isSaving = false;

  /// 이미 만든 아이. 2단계(성장 기록)에서 실패해 다시 시도할 때, 아이를
  /// 한 번 더 만들지 않으려고 들고 있습니다.
  Baby? _created;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  /// 온보딩을 마쳤을 때 갈 곳.
  ///
  /// 로그인 직후 진입한 경우엔 뒤로 갈 곳이 없으므로 홈으로 보내고,
  /// 다른 화면(예: 성장 기록)에서 등록하러 들어온 경우엔 그 화면으로 돌아갑니다.
  void _leave() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty ||
        _birthDate == null ||
        _sex == null ||
        _weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 정보를 입력해주세요.')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('몸무게는 숫자로 입력해주세요.')),
      );
      return;
    }
    // growth_records.weight_kg의 CHECK 제약(0.5~40)과 같은 범위를 씁니다.
    if (weight < 0.5 || weight > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('몸무게는 0.5~40kg 사이로 입력해주세요.')),
      );
      return;
    }

    // 키는 선택입니다. 적었다면 growth_records.height_cm의 CHECK(20~150)를 지킵니다.
    double? height;
    final heightText = _heightController.text.trim();
    if (heightText.isNotEmpty) {
      height = double.tryParse(heightText);
      if (height == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('키는 숫자로 입력해주세요.')),
        );
        return;
      }
      if (height < 20 || height > 150) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('키는 20~150cm 사이로 입력해주세요.')),
        );
        return;
      }
    }

    try {
      setState(() => _isSaving = true);

      // 아이를 이미 만들었다면 다시 만들지 않습니다.
      //
      // 등록도 두 단계입니다(아이 → 첫 성장 기록). 2단계가 실패했을 때
      // 통째로 다시 하면 **아이가 2행** 생기고, `loadCurrent()`는 늘 첫
      // 행을 고르므로 나중에 적은 값은 어느 화면에도 나오지 않습니다.
      // 중복 행을 지울 수단도 앱에 없습니다.
      final baby = _created ??= await BabyService.create(
        name: _nameController.text.trim(),
        sex: _sex!,
        birthDate: _birthDate!,
      );

      await GrowthRecordService.saveRecord(
        babyId: baby.id,
        date: DateTime.now(),
        weightKg: weight,
        heightCm: height,
      );

      if (!mounted) return;
      _leave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_created == null
              ? '아이 정보를 저장하지 못했습니다. $e'
              : '아이는 등록했지만 키·몸무게를 저장하지 못했습니다. 다시 시도해 주세요.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _leave,
            child: Text('나중에 하기', style: TextStyle(color: context.colors.textSecondary)),
          ),
        ],
      ),
      // **화면이 짧으면 넘쳤습니다.**
      //
      // 본문이 Column + Spacer뿐이라 스크롤이 없었습니다. 키 큰 화면에서는
      // Spacer가 단추를 아래로 밀어 보기 좋지만, 작은 기기나 글씨를 키운
      // 경우에는 그대로 넘쳐 아래가 잘렸습니다(320x640에서 1px, 글씨
      // 1.3배에서 94px). 아이 정보를 처음 적는 화면이라 여기서 막히면
      // 앱을 시작할 수가 없습니다.
      //
      // 자리가 남으면 지금처럼 Spacer가 밀고, 모자라면 스크롤합니다.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                '우리 아이에 대해\n알려주세요',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '입력한 정보로 맞춤 인사이트를 보여드려요',
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '아이 이름',
                  hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '생년월일',
                    labelStyle: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                  ),
                  child: Text(
                    _birthDate == null
                        ? '날짜를 선택해주세요'
                        : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _birthDate == null ? context.colors.textSecondary : context.colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: _buildGenderButton(ChildSex.male, '남아')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGenderButton(ChildSex.female, '여아')),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '키 (cm) — 선택',
                  hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '몸무게 (kg)',
                  hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.border)),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '저장하고 시작하기',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderButton(ChildSex value, String label) {
    final selected = _sex == value;
    return GestureDetector(
      onTap: () => setState(() => _sex = value),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : context.colors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
