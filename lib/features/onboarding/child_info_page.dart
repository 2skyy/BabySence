import 'package:flutter/material.dart';

import '../../core/services/baby_service.dart';
import '../../core/services/growth_calculator.dart';
import '../detail/growth/growth_record_service.dart';
import '../../routes/app_routes.dart';

/// 로그인 후 등록된 아이가 없을 때 보여주는 최초 온보딩 화면.
///
/// babies 테이블에 아이를 만들고, 입력받은 몸무게는 오늘 날짜의
/// growth_records 한 건으로 함께 저장합니다.
/// (babies에는 몸무게 컬럼이 없습니다. 몸무게는 시간에 따라 변하는
///  측정값이라 성장 기록 쪽이 맞는 자리입니다.)
class ChildInfoPage extends StatefulWidget {
  const ChildInfoPage({super.key});

  @override
  State<ChildInfoPage> createState() => _ChildInfoPageState();
}

class _ChildInfoPageState extends State<ChildInfoPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  DateTime? _birthDate;
  ChildSex? _sex;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
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

    try {
      setState(() => _isSaving = true);

      final baby = await BabyService.create(
        name: _nameController.text.trim(),
        sex: _sex!,
        birthDate: _birthDate!,
      );

      await GrowthRecordService.saveRecord(
        babyId: baby.id,
        date: DateTime.now(),
        weightKg: weight,
      );

      if (!mounted) return;
      _leave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장하지 못했습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _leave,
            child: Text('나중에 하기', style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                '우리 아이에 대해\n알려주세요',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '입력한 정보로 맞춤 인사이트를 보여드려요',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '아이 이름',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '생년월일',
                    labelStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Text(
                    _birthDate == null
                        ? '날짜를 선택해주세요'
                        : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _birthDate == null ? Colors.grey[400] : Colors.black87,
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
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '몸무게 (kg)',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
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
                    backgroundColor: const Color(0xFF3182F6),
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
          color: selected ? const Color(0xFF3182F6).withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF3182F6) : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF3182F6) : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
