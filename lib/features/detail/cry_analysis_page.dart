import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:dio/dio.dart';
import 'package:desktop_drop/desktop_drop.dart'; // 👈 추가 필요

class CryAnalysisPage extends StatefulWidget {
  const CryAnalysisPage({super.key});

  @override
  State<CryAnalysisPage> createState() => _CryAnalysisPageState();
}

class _CryAnalysisPageState extends State<CryAnalysisPage> {
  XFile? _selectedFile;
  String _resultSubtitle = '다른 .wav 파일을 선택해도 실시간 분석이 가능합니다.';
  bool _isLoading = false;
  bool _isDragging = false; //  드래그 중 UI 표시용

  Future<void> _pickAudioFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'audios',
        extensions: <String>['wav', 'mp3', 'm4a'],
        uniformTypeIdentifiers: <String>[
          'com.microsoft.waveform-audio',
          'public.mp3',
          'public.mpeg-4-audio'
        ],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file != null) _applyFile(file);
    } catch (e) {
      setState(() {
        _resultSubtitle = "파일 선택 에러: $e";
      });
    }
  }

  //  파일 적용 로직을 공통 함수로 분리
  void _applyFile(XFile file) {
    final ext = file.name.split('.').last.toLowerCase();
    if (!['wav', 'mp3', 'm4a'].contains(ext)) {
      setState(() {
        _resultSubtitle = " .wav / .mp3 / .m4a 파일만 지원합니다.";
      });
      return;
    }
    setState(() {
      _selectedFile = file;
      _resultSubtitle = " 선택된 파일: ${file.name}\n이제 하단의 분석하기 버튼을 눌러주세요.";
    });
  }

  Future<void> _sendAudioToSpringServer() async {
    if (_selectedFile == null) return;
    setState(() {
      _isLoading = true;
      _resultSubtitle = 'AI가 실제 울음소리 파형을 분석 중입니다. 잠시만 기다려주세요...';
    });

    try {
      final fileBytes = await _selectedFile!.readAsBytes();
      FormData formData = FormData.fromMap({
        "file": MultipartFile.fromBytes(fileBytes, filename: _selectedFile!.name),
      });
      Response response = await Dio().post("http://localhost:8080/api/cry/analyze", data: formData);
      if (response.statusCode == 200) {
        String aiAnalysis = response.data['analysis'] ?? 'unknown';
        setState(() {
          _resultSubtitle = " AI 분석 결과: 현재 아기는 [ $aiAnalysis ] 상태입니다.";
        });
      }
    } catch (e) {
      setState(() {
        _resultSubtitle = "울음소리 서버 연동 실패: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('울음소리 분석', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '아이의 울음소리를 분석해\n어떤 의미인지 알려드립니다.',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.3),
            ),
            const SizedBox(height: 12),
            Text(
              _resultSubtitle,
              style: TextStyle(
                fontSize: 14,
                color: _resultSubtitle.contains('분석 결과') ? Colors.deepOrange : Colors.black54,
                fontWeight: _resultSubtitle.contains('분석 결과') ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 28),

            Expanded(
              child: DropTarget(
                onDragDone: (detail) {
                  // 드롭 완료 시 첫 번째 파일 사용
                  if (detail.files.isNotEmpty) {
                    _applyFile(detail.files.first);
                  }
                },
                onDragEntered: (detail) => setState(() => _isDragging = true),
                onDragExited: (detail) => setState(() => _isDragging = false),
                child: GestureDetector(
                  onTap: _pickAudioFile,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _isDragging ? const Color(0xFFFFEDE8) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isDragging ? Colors.deepOrange : const Color(0xFFE5E7EB),
                        width: _isDragging ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.deepOrange)
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isDragging
                                ? Icons.download_rounded
                                : _selectedFile != null
                                ? Icons.audiotrack
                                : Icons.mic,
                            size: 48,
                            color: Colors.deepOrange,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isDragging
                                ? '여기에 놓으세요!'
                                : _selectedFile != null
                                ? '오디오 파일 로드 완료!\n(${_selectedFile!.name})'
                                : '클릭하거나 파일을 드래그하여\n울음소리 파일(.wav) 선택',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedFile != null && !_isLoading ? _sendAudioToSpringServer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0059B9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Text(_isLoading ? '분석 중...' : '분석하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}