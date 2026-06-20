import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

class SkinAnalysisPage extends StatefulWidget {
  const SkinAnalysisPage({super.key});

  @override
  State<SkinAnalysisPage> createState() => _SkinAnalysisPageState();
}

class _SkinAnalysisPageState extends State<SkinAnalysisPage> {
  File? _image; // 사용자가 찍거나 고른 아기 피부 사진이 담길 곳
  final ImagePicker _picker = ImagePicker();
  String _resultText = "발진, 습진, 건조함 같은 상태를 확인하는 기능으로 준비하면 됩니다.";
  bool _isLoading = false;

  // 1. 카메라로 아기 피부 사진 촬영하기
  Future<void> _takePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // 2. 갤러리에서 아기 피부 사진 선택하기
  Future<void> _getFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // 3.  스프링 부트 서버로 사진을 던지는 핵심 통신 함수
  Future<void> _sendToSpringServer() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
      _resultText = "AI가 피부 상태를 분석 중입니다. 잠시만 기다려주세요...";
    });

    Dio dio = Dio();

    String serverUrl = "http://localhost:8080/api/skin/diagnose";

    try {
      // 자바 컨트롤러의 @RequestParam("file")과 매칭되도록 'file' 키값 사용
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(_image!.path, filename: "baby_skin.jpg"),
      });

      // 조장님 스프링 서버로 POST 전송!
      Response response = await dio.post(serverUrl, data: formData);

      if (response.statusCode == 200) {
        var data = response.data;
        setState(() {
          // 서버가 최종 리턴해 준 AI 판독 결과를 화면 문구에 반영!
          _resultText = "진단 결과: ${data['disease']} (${data['probability']}%)";
        });
      }
    } catch (e) {
      setState(() {
        _resultText = "서버 연동 실패: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("피부 AI 판단", style: TextStyle(color: Color(0xFF1A1C1C), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "피부 사진을 업로드하면\nAI가 피부 상태를 알려드립니다.",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4, color: Color(0xFF1A1C1C)),
            ),
            const SizedBox(height: 12),
            Text(_resultText, style: const TextStyle(fontSize: 14, color: Color(0xFF555F6A))),
            const SizedBox(height: 30),

            // 두 번째 스크린샷의 '사진 업로드 UI 예정' 커스텀 박스 영역
            Expanded(
              child: GestureDetector(
                onTap: () => _showImageSourceBottomSheet(),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE3E3E3)),
                  ),
                  child: _image != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  )
                      : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text("사진 업로드 UI 예정\n(클릭하여 촬영 또는 선택)", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 기획서 하단 디자인 그대로 구현한 [분석하기] 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _image != null && !_isLoading ? _sendToSpringServer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFECEFF8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF0059B9))
                    : const Text("분석하기", style: TextStyle(fontSize: 18, color: Color(0xFF0059B9), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 아래서 스윽 올라오는 카메라/갤러리 선택창
  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 아기 피부 촬영하기'),
              onTap: () { _takePhoto(); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 아기 사진 가져오기'),
              onTap: () { _getFromGallery(); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }
}