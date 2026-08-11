import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';

class BabyFoodPage extends StatefulWidget {
  const BabyFoodPage({super.key});

  @override
  State<BabyFoodPage> createState() => _BabyFoodPageState();
}

class _BabyFoodPageState extends State<BabyFoodPage> {
  static const Color primaryColor = AppColors.primary;
  Color get backgroundColor => context.colors.background;
  Color get borderColor => context.colors.border;
  Color get textColor => context.colors.textPrimary;
  Color get secondaryTextColor => context.colors.textSecondary;

  final ImagePicker _picker = ImagePicker();

  /// 고른 사진. 미리보기에만 씁니다 — 아직 보낼 곳이 없습니다.
  Uint8List? _imageBytes;
  String? _fileName;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _fileName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했습니다.')));
      debugPrint('이유식 사진 선택 실패: $e');
    }
  }

  Future<void> _showSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 찍기'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 고르기'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) await _pickImage(source);
  }

  /// 분석 서버가 아직 없습니다.
  ///
  /// 피부 분석과 같은 상황입니다. 모델 없이 결과를 만들어 보여주면 그건
  /// 지어낸 값이고, 사용자는 그걸 진단으로 받아들입니다. 그래서 사진을
  /// 고르는 데까지만 동작하고, 여기서는 솔직하게 안내합니다.
  void handleAnalyze() {
    final message = _imageBytes == null
        ? '사진을 먼저 선택해 주세요.'
        : '성분 분석 모델이 아직 준비되지 않았습니다.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '이유식 분석',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이유식 사진을\n업로드해주세요',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  '사진을 기반으로 성분을 분석할 예정입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  '사진 업로드',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 14),

                _buildPhotoArea(),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: primaryColor),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '성분 분석 모델은 아직 준비 중입니다.\n지금은 사진 선택까지 됩니다.',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: handleAnalyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '분석하기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 사진을 고르는 영역. 고른 뒤에는 미리보기로 바뀝니다.
  Widget _buildPhotoArea() {
    final bytes = _imageBytes;

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _showSourceSheet,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: bytes == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 70,
                      color: secondaryTextColor,
                    ),
                    SizedBox(height: 12),
                    Text(
                      '사진 선택하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '카메라 또는 앨범',
                      style: TextStyle(fontSize: 13, color: secondaryTextColor),
                    ),
                  ],
                )
              : Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(19),
                      ),
                      child: Image.memory(
                        bytes,
                        width: double.infinity,
                        height: 260,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fileName ?? '사진을 선택했습니다',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          const Text(
                            '변경',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}