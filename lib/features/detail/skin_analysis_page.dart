import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_config.dart';
import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/medical_disclaimer.dart';

class SkinAnalysisPage extends StatefulWidget {
  const SkinAnalysisPage({super.key});

  @override
  State<SkinAnalysisPage> createState() => _SkinAnalysisPageState();
}

class _SkinAnalysisPageState extends State<SkinAnalysisPage> {
  File? _image;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  String _resultText = "사진을 선택한 후 '분석하기' 버튼을 눌러주세요.";
  bool _isLoading = false;
  bool _isNormal = false;

  final Map<String, String> _koDiseases = {
    "normal": "정상 피부",
    "Atopic Dermatitis": "아토피성 피부염",
    "Contact Dermatitis": "접촉성 피부염",
    "Seborrheic Dermatitis": "지루성 피부염",
    "Diaper Rash": "기저귀 발진",
    "Infantile Eczema": "유아 습진",
    "Urticaria": "두드러기",
  };

  // 1. 카메라로 촬영
  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _image = File(pickedFile.path);
          _imageBytes = bytes;
          _resultText = "사진이 정상 등록되었습니다. '분석하기'를 누르세요.";
          _isNormal = false;
        });
      }
    } catch (e) {
      debugPrint("카메라 에러: $e");
    }
  }

  // 2. 갤러리에서 가져오기 (image_picker 사용)
  Future<void> _getFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _image = File(pickedFile.path);
          _imageBytes = bytes;
          _resultText = "사진이 정상 등록되었습니다. '분석하기'를 누르세요.";
          _isNormal = false;
        });
      }
    } catch (e) {
      debugPrint("갤러리 선택 에러: $e");
    }
  }

  // 3. AI 서버(FastAPI) 분석 요청
  Future<void> _sendToAiServer() async {
    if (_image == null && _imageBytes == null) return;

    setState(() {
      _isLoading = true;
      _resultText = "AI가 피부 상태를 분석 중입니다. 잠시만 기다려주세요...";
    });

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    String serverUrl = ApiConfig.skinDiagnose;

    try {
      final Uint8List uploadBytes = _imageBytes ?? await _image!.readAsBytes();

      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(
          uploadBytes,
          filename: "baby_skin.jpg",
        ),
      });

      Response response = await dio.post(serverUrl, data: formData);
      if (!mounted) return;

      if (response.statusCode == 200) {
        var data = response.data;

        if (data['is_skin'] == false) {
          setState(() {
            _isNormal = false;
            _resultText = data['message'] ?? '피부 사진이 아닙니다. 환부를 다시 촬영해 주세요.';
          });
          return;
        }

        if (data['status'] == 'low_confidence') {
          setState(() {
            _isNormal = false;
            _resultText = data['message'] ??
                '정확한 판독이 어렵습니다. 깨끗한 조명에서 환부를 다시 촬영해 주세요.';
          });
          return;
        }

        String rawDisease = data['disease'] ?? "normal";
        double prob = (data['probability'] as num).toDouble();

        String translatedDisease = _koDiseases[rawDisease] ?? rawDisease;
        String message = data['message'] ?? "";

        setState(() {
          _isNormal = (rawDisease.toLowerCase() == "normal");
          _resultText = message.isNotEmpty
              ? "진단 결과: $translatedDisease (${prob.toStringAsFixed(1)}%)\n\n$message"
              : "진단 결과: $translatedDisease (${prob.toStringAsFixed(1)}%)";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultText = "서버 연동 실패: $e";
        _isNormal = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const CommonAppBar(title: '피부 AI 판단'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "피부 사진을 업로드하면\nAI가 피부 상태를 알려드립니다.",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // 결과 안내 박스
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isNormal
                    ? Colors.green.withValues(alpha: 0.15)
                    : context.colors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _resultText,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const MedicalDisclaimer(),
            const SizedBox(height: 18),

            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : () => _showImageSourceBottomSheet(),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isNormal
                          ? Colors.green.withValues(alpha: 0.5)
                          : context.colors.border,
                      width: _isNormal ? 2 : 1,
                    ),
                  ),
                  child: (_imageBytes != null)
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  )
                      : (_image != null)
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  )
                      : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 48, color: context.colors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          "터치하여 사진 촬영 또는 선택",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: context.colors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 분석하기 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: (_image != null || _imageBytes != null) && !_isLoading
                    ? _sendToAiServer
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isNormal
                      ? Colors.green
                      : context.colors.primarySurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: AppColors.primary)
                    : Text(
                  "분석하기",
                  style: TextStyle(
                    fontSize: 18,
                    color: _isNormal ? Colors.white : AppColors.primary,
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

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 아기 피부 촬영하기'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 아기 사진 가져오기'),
              onTap: () {
                Navigator.pop(context);
                _getFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }
}