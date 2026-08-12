import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../advice/ask_action.dart';
import 'assessment/assessment.dart';
import 'skin/skin_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/medical_disclaimer.dart';

/// 피부 사진을 보고 지금 무엇을 하면 좋을지 안내하는 화면.
///
/// **진단하지 않습니다.** 예전에는 "진단 결과: 흑색종 (88.4%)"처럼 병명과
/// 확률을 띄웠습니다. 뒤에 있던 것은 성인 피부암 데이터셋으로 만든 분류기
/// 자리였고, 실제로는 늘 같은 값을 돌려주는 껍데기였습니다. 영유아에게는
/// 거의 없는 질환들이라 기저귀 발진 사진에 '흑색종'이 붙을 수 있었습니다.
///
/// 지금은 서버가 보이는 것과 단계(정상/주의/상담 권장)만 돌려줍니다.
class SkinAnalysisPage extends StatefulWidget {
  const SkinAnalysisPage({super.key});

  @override
  State<SkinAnalysisPage> createState() => _SkinAnalysisPageState();
}

class _SkinAnalysisPageState extends State<SkinAnalysisPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;

  /// 분석 결과. 아직 분석하지 않았으면 null입니다.
  SkinReading? _reading;

  /// 안내 문구. 결과가 없을 때 그 자리에 대신 보여줍니다.
  String _notice = "사진을 고르고 '확인하기'를 눌러 주세요.";

  /// [_notice]가 오류인지. 오류는 다른 색으로 그립니다.
  bool _noticeIsError = false;

  Future<void> _pick(ImageSource source) async {
    try {
      // 여기서 줄여 보냅니다. 요즘 휴대폰 사진은 한 장에 5MB를 넘는데,
      // 서버는 4MB까지만 받습니다(그 너머는 Claude가 받지 않습니다).
      // 긴 변 1568px이면 모델이 보는 해상도와 같아 더 키워도 얻는 것이 없습니다.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1568,
        maxHeight: 1568,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _image = File(picked.path);
        _reading = null;
        _notice = "사진을 담았습니다. '확인하기'를 눌러 주세요.";
        _noticeIsError = false;
      });
    } catch (e) {
      // 예전에는 debugPrint만 하고 넘어가, 권한을 거부한 사용자에게는
      // 아무 일도 일어나지 않는 것처럼 보였습니다.
      debugPrint('사진 선택 실패: $e');
      if (!mounted) return;
      setState(() {
        _notice = source == ImageSource.camera
            ? '카메라를 열지 못했습니다. 설정에서 카메라 권한을 확인해 주세요.'
            : '사진을 가져오지 못했습니다. 설정에서 사진 접근 권한을 확인해 주세요.';
        _noticeIsError = true;
      });
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;

    setState(() {
      _loading = true;
      _reading = null;
      _notice = '사진을 확인하는 중입니다…';
      _noticeIsError = false;
    });

    try {
      final reading = await SkinService.analyze(image.path);
      if (!mounted) return;
      setState(() => _reading = reading);
    } on SkinUnreadable catch (e) {
      // 판독이 안 된 것이지 정상이 아닙니다. 결과 카드를 그리지 않습니다.
      if (!mounted) return;
      setState(() {
        _notice = e.message;
        _noticeIsError = true;
      });
    } on SkinException catch (e) {
      if (!mounted) return;
      setState(() {
        _notice = e.message;
        _noticeIsError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CommonAppBar(
        title: '피부 살펴보기',
        actions: [AskAction(domain: AssessmentDomain.skin)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '아이 피부 사진을 올리면\n무엇이 보이는지 알려드려요.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '병명을 가려내지는 않습니다.',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),

            if (_reading != null)
              _ReadingCard(reading: _reading!)
            else
              _NoticeCard(text: _notice, isError: _noticeIsError),

            const SizedBox(height: 12),
            const MedicalDisclaimer(),
            const SizedBox(height: 18),

            GestureDetector(
              onTap: _loading ? null : _showSourceSheet,
              child: Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                ),
                child: _image == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                size: 48, color: colors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              '터치해서 사진 찍기 또는 고르기',
                              style: TextStyle(
                                  color: colors.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _image != null && !_loading ? _analyze : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primarySurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : const Text(
                        '확인하기',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 찍기'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 고르기'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 결과가 없을 때 그 자리에 놓는 안내.
class _NoticeCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _NoticeCard({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? Colors.orange.withValues(alpha: 0.15)
            : colors.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError) ...[
            const Icon(Icons.error_outline, size: 20, color: Colors.orange),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진을 보고 나온 결과.
///
/// 병명도 확률도 없습니다. 단계, 보이는 것, 지금 할 수 있는 것 셋뿐입니다.
class _ReadingCard extends StatelessWidget {
  final SkinReading reading;

  const _ReadingCard({required this.reading});

  Color get _accent {
    if (reading.urgent) return Colors.red;
    switch (reading.level) {
      case AssessmentLevel.normal:
        return Colors.green;
      case AssessmentLevel.caution:
        return Colors.orange;
      case AssessmentLevel.consult:
        return Colors.deepOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reading.urgent ? Icons.priority_high : Icons.remove_red_eye,
                size: 18,
                color: _accent,
              ),
              const SizedBox(width: 6),
              Text(
                reading.urgent ? '오늘 진료를 받아 보세요' : reading.level.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _accent,
                ),
              ),
            ],
          ),
          if (reading.observations.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final o in reading.observations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· $o',
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                ),
              ),
          ],
          if (reading.advice.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reading.advice,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
