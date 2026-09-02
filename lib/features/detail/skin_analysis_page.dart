import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'assessment/assessment.dart';
import 'assessment/temperature_rules.dart' show ageInMonthsAt;
import 'skin/skin_service.dart';
import 'temperature_record_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import '../../core/widgets/missing_baby.dart';
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

/// 열이 있다고 볼 체온(℃).
///
/// 연령별 상담 권장 하한(`TemperatureRules.consultThreshold`)이 아니라 이
/// 값을 쓰는 이유: 여기서 묻는 것은 판정이 아니라 **발진에 열이 동반됐는가**
/// 하나입니다. `temperature_rules.dart`의 출처 주석에 적혀 있듯, 연령별
/// 구분값(38.0/38.5/39.0)은 인용한 문서에서 확인되지 않았고 확인된 것은
/// "38.0℃ 이상 병원 권고"뿐입니다. 확인된 쪽을 씁니다.
const double _feverC = 38.0;

/// 이 시간 안에 잰 것만 봅니다. 어제 열은 오늘 발진의 동반 증상이 아닙니다.
const Duration _feverWindow = Duration(hours: 12);

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

  /// 최근에 잰 열이 있으면 함께 보냅니다.
  ///
  /// **열은 사진에 없습니다.** 발진과 발열이 함께 있는 것은 카메라가 담지
  /// 못하는 가장 값진 신호라, 이미 가지고 있는 체온 기록에서 찾아 넘깁니다.
  /// 보호자에게 따로 묻지 않는 것은 걸음을 하나 더 두지 않으려는 것입니다.
  ///
  /// 기록이 없거나 오래됐으면 `'unknown'`입니다. **`'no'`로 접지 마세요** —
  /// 재보지 않은 것과 열이 없는 것은 다른 말입니다.
  static Future<String> _recentFever(String babyId) async {
    try {
      final since = DateTime.now().subtract(_feverWindow);
      final records =
          await TemperatureRecordService.loadRecent(babyId, since: since);
      if (records.isEmpty) return 'unknown';

      // 창 안에 한 번이라도 넘었으면 있음으로 봅니다. 마지막 한 번만 보면
      // 해열제로 잠시 내려간 값이 '없음'이 됩니다.
      final feverish = records.any((r) => r.temperatureC >= _feverC);
      return feverish ? 'yes' : 'no';
    } catch (_) {
      // 조회 실패를 '없음'으로 바꾸지 않습니다.
      return 'unknown';
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
      // 개월 수는 서버가 필수로 받습니다. 나이에 걸린 안전 조항이 여기
      // 달려 있어, 못 읽었으면 보내지 않고 그 사실을 말합니다.
      final baby = await BabyService.loadCurrent();
      if (baby == null) {
        // **"불러오지 못했다"와 "아직 등록하지 않았다"는 다른 말입니다.**
        // loadCurrent()는 로그인이 풀렸으면 예외를 던지므로, null은 조회가
        // 성공했고 아이가 없다는 뜻뿐입니다. '잠시 후 다시 시도해 주세요'는
        // 원인을 틀리게 짚는 데다, 시키는 대로 다시 찍어도 영원히 같습니다.
        // 기록 화면 다섯이 같은 오진을 고칠 때 쓴 자리를 여기서도 씁니다.
        if (!mounted) return;
        // 스낵바에는 '등록하기' 동작이 함께 붙습니다. 화면 문구도 같은
        // 말을 해야 둘이 어긋나지 않습니다.
        notifyMissingBaby(context, state: BabyLookup.none);
        setState(() {
          _notice = '먼저 아이 정보를 등록해 주세요.\n'
              '개월 수를 알아야 사진을 볼 수 있습니다.';
          _noticeIsError = true;
        });
        return;
      }

      final reading = await SkinService.analyze(
        image.path,
        ageInMonths: ageInMonthsAt(baby.birthDate, DateTime.now()),
        hasFever: await _recentFever(baby.id),
      );
      if (!mounted) return;
      setState(() => _reading = reading);
    } on SkinUnreadable catch (e) {
      // 판독이 안 된 것이지 정상이 아닙니다. 결과 카드를 그리지 않고,
      // **못 봤다는 것이 안심으로 읽히지 않게** 한 줄을 덧붙입니다.
      // 새벽에 어두운 방에서 한 손으로 아이를 잡고 찍은 사진이 예외가 아니라
      // 표준이고, 그때 "다시 찍어 주세요"로만 끝나면 그것이 안심이 됩니다.
      if (!mounted) return;
      setState(() {
        _notice = '${e.message}\n\n'
            '확인하지 못했다는 것은 괜찮다는 뜻이 아닙니다. '
            '걱정되시면 사진과 관계없이 진료를 받아 주세요.';
        _noticeIsError = true;
      });
    } on SkinException catch (e) {
      // 서버에 닿지 못한 것도 **결과를 못 받은 것**입니다. 판독 불가와 같은
      // 이유로 한 줄을 덧붙입니다 — 새벽에 서버가 죽어 오류만 뜨면 그것도
      // 안심으로 읽힙니다.
      if (!mounted) return;
      setState(() {
        _notice = '${e.message}\n\n'
            '확인하지 못했다는 것은 괜찮다는 뜻이 아닙니다. '
            '걱정되시면 사진과 관계없이 진료를 받아 주세요.';
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
            const SizedBox(height: 4),
            const _EmergencyNotice(),
            const SizedBox(height: 14),

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
      // 초록은 쓰지 않습니다. 사진 한 장으로 '괜찮다'고 말할 근거가 없고,
      // 초록을 본 보호자는 그 화면을 근거로 자기 판단을 멈춥니다.
      case AssessmentLevel.caution:
        return Colors.blueGrey;
      case AssessmentLevel.consult:
        return Colors.deepOrange;
      case AssessmentLevel.normal:
        // 서버가 보내지 않는 값입니다. 혹시 오더라도 초록이 되지 않게.
        return Colors.blueGrey;
    }
  }

  /// 화면에 적을 단계 이름.
  ///
  /// `AssessmentLevel.label`('주의'/'상담 권장')을 쓰지 않습니다. 그 말은
  /// 체온·성장처럼 **공인 임계값으로 계산한** 판정의 이름입니다. 사진은
  /// 판정이 아니라 관찰이라, 판정처럼 보이지 않는 말을 씁니다.
  String get _headline {
    if (reading.urgent) return '지금 진료를 받아 주세요';
    return reading.level == AssessmentLevel.consult
        ? '진료를 받아 보세요'
        : '사진에서는 급해 보이는 신호가 보이지 않습니다';
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                reading.urgent ? Icons.priority_high : Icons.remove_red_eye,
                size: 18,
                color: _accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _headline,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          if (reading.urgent)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                '밤이라면 응급실로 가 주세요.',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _accent),
              ),
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
          // **접지 않습니다.** 이 앱이 진단하지 않는다는 사실을 보호자에게
          // 보여주는 유일한 자리입니다.
          if (reading.unknown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reading.unknown,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '사진으로는 병을 가려내지 않습니다. 이 안내는 진단이 아닙니다.',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 사진과 관계없이 항상 보이는 응급 안내.
///
/// 문구는 서버 상담 프롬프트(`advice.py`)의 응급 목록과 **같은 문장**입니다.
/// 앱 안에서 같은 말이 화면마다 다르게 적히면 안 됩니다.
///
/// 접히지만 제목은 늘 보입니다. 결과가 무엇이든, 결과를 받기 전이든 자리를
/// 지킵니다 — 사진에 안 찍히는 신호가 사진에 찍히는 것보다 급한 경우가
/// 있기 때문입니다.
class _EmergencyNotice extends StatelessWidget {
  const _EmergencyNotice();

  static const _signs = [
    '생후 3개월이 안 된 아기에게 열이 있을 때',
    '경련하거나, 의식이 흐리거나, 숨쉬기 힘들어할 때',
    '심하게 늘어져 있거나 깨우기 어려울 때',
    '소변이 거의 없거나, 입술이 마르거나, 울어도 눈물이 없을 때',
    '보호자가 보시기에 평소와 확실히 다를 때',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Theme(
      // ExpansionTile의 기본 구분선을 지웁니다.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
        leading: const Icon(Icons.local_hospital_outlined,
            size: 20, color: Colors.red),
        title: const Text(
          '사진과 관계없이 지금 바로 진료를 받아 주세요',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
        ),
        children: [
          for (final sign in _signs)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ',
                      style: TextStyle(color: colors.textSecondary)),
                  Expanded(
                    child: Text(
                      sign,
                      style: TextStyle(
                          fontSize: 13, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
