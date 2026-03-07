import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import 'ban_dialog.dart';

class UploadModal extends StatefulWidget {
  const UploadModal({super.key});

  @override
  State<UploadModal> createState() => _UploadModalState();
}

class _UploadModalState extends State<UploadModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  String _postType = 'original'; // 'original' 또는 'recreation'
  File? _selectedImage;
  File? _originalImage;
  bool _isUploading = false;

  bool _uploadCompleted = false;
  String? _uploadError;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _pickOriginalImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _originalImage = File(image.path);
      });
    }
  }

  Future<void> _performUpload() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dataService = Provider.of<DataService>(context, listen: false);
    if (!authService.isLoggedIn) throw Exception('로그인이 필요합니다.');

    final imageResult = await dataService.uploadImageWithCompression(
      _selectedImage!,
      authService.user!.uid,
      'posts',
    );

    String? originalImageUrl;
    if (_postType == 'recreation' && _originalImage != null) {
      final originalResult = await dataService.uploadImageWithCompression(
        _originalImage!,
        authService.user!.uid,
        'posts',
      );
      originalImageUrl = originalResult['compressed'];
    }

    await dataService.createPost(
      userId: authService.user!.uid,
      username: authService.userData?['name'] ?? authService.user!.displayName ?? '익명',
      title: _titleController.text.trim(),
      caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      imageUrl: imageResult['compressed']!,
      tags: _tagsController.text.trim().isEmpty
          ? []
          : _tagsController.text.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).take(5).toList(),
      type: _postType,
      originalImageUrl: originalImageUrl,
      compressedImageUrl: imageResult['compressed'],
    );

    if (mounted) await dataService.getAllPosts();
  }

  void _checkFinish() {
    if (!_uploadCompleted) return;
    if (!mounted) return;

    setState(() => _isUploading = false);
    if (_uploadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $_uploadError')),
      );
    } else {
      // 업로드 성공 시 별도 알림 없이 업로드 모달만 닫음
      Navigator.pop(context);
    }
  }

  Future<void> _uploadPost() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인이 그린 그림을 선택해주세요.')),
      );
      return;
    }
    if (_postType == 'recreation' && _originalImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원본 그림을 선택해주세요.')),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    if (authService.isBanned) {
      showBanDialog(context, authService.banUntil);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadCompleted = false;
      _uploadError = null;
    });

    final uploadFuture = _performUpload();

    uploadFuture.then((_) {
      if (mounted) {
        setState(() => _uploadCompleted = true);
        _checkFinish();
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _uploadCompleted = true;
          _uploadError = e.toString();
        });
        _checkFinish();
      }
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _captionController.clear();
    _tagsController.clear();
    setState(() {
      _postType = 'original';
      _selectedImage = null;
      _originalImage = null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // 모달 배경 투명
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9, // CSS: max-height: 90vh
          maxWidth: 600, // CSS: width: min(90%, 600px)
        ),
        decoration: BoxDecoration(
          color: Colors.white, // CSS: background-color: white
          borderRadius: BorderRadius.circular(15), // CSS: border-radius: 15px
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3), // CSS: rgba(0, 0, 0, 0.3)
              blurRadius: 40, // CSS: 40px
              offset: const Offset(0, 10), // CSS: 0 10px
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더 (CSS: .modal-content h2)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 24, // CSS: clamp(1.5rem, 4vw, 2rem)
                vertical: 24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '새 그림 업로드',
                    style: TextStyle(
                      fontSize: 24, // CSS: h2 크기
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary, // CSS: color: #333
                    ),
                  ),
                  // 닫기 버튼 (CSS: .close)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _resetForm();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text(
                          '×',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF999999), // CSS: color: #999
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 폼 내용
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 24, // CSS: clamp(1.5rem, 4vw, 2rem)
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작품 유형 선택 (박스 없이)
                      Text(
                        '작품 유형',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8ECF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TypeTab(
                                label: '창작',
                                isSelected: _postType == 'original',
                                onTap: () {
                                  setState(() {
                                    _postType = 'original';
                                    _originalImage = null;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _TypeTab(
                                label: '모작',
                                isSelected: _postType == 'recreation',
                                onTap: () {
                                  setState(() => _postType = 'recreation');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 본인이 그린 그림 업로드 (CSS: .upload-area)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 레이블 (CSS: .upload-label-text)
                          Text(
                            '그림',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8), // CSS: margin-bottom: 0.5rem
                          // 업로드 라벨 (CSS: .upload-label)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: double.infinity,
                              padding: _selectedImage != null
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.all(48),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFF8F9FF),
                              ),
                              child: _selectedImage != null
                                  ? SizedBox(
                                      height: 240,
                                      width: double.infinity,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.file(
                                              _selectedImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedImage = null;
                                                  });
                                                },
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE74C3C),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 아이콘 (CSS: .upload-icon)
                                        Icon(
                                          Icons.image,
                                          size: 48, // CSS: 3rem = 48px
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(height: 8), // CSS: margin-bottom: 0.5rem
                                        const Text(
                                          '이미지를 선택하세요',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24), // CSS: margin-bottom: 1rem
                      // 원본 그림 업로드 (모작인 경우만)
                      if (_postType == 'recreation') ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '원본 그림',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickOriginalImage,
                              child: Container(
                                width: double.infinity,
                                padding: _originalImage != null
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.all(48),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppTheme.primaryColor,
                                    width: 2,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  color: const Color(0xFFF8F9FF),
                                ),
                                child: _originalImage != null
                                    ? SizedBox(
                                        height: 240,
                                        width: double.infinity,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.file(
                                                _originalImage!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _originalImage = null;
                                                    });
                                                  },
                                                  borderRadius: BorderRadius.circular(20),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFE74C3C),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.image,
                                            size: 48,
                                            color: AppTheme.primaryColor,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            '이미지를 선택하세요',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24), // CSS: margin-bottom: 1rem
                      ],
                      // 제목 (CSS: .form-group)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24), // CSS: margin-bottom: 1.5rem
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '제목',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8), // CSS: margin-bottom: 0.5rem
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: '작품 제목을 입력하세요',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  color: Color(0xFF9CA3AF),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10), // CSS: border-radius: 10px
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0), // CSS: border: 2px solid #e0e0e0
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryColor, // CSS: border-color: #667eea (focus)
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(12), // CSS: padding: 0.75rem
                              ),
                              style: const TextStyle(
                                fontSize: 16, // CSS: font-size: 1rem
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '제목을 입력해주세요.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      // 설명 (CSS: textarea)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24), // CSS: margin-bottom: 1rem
                        child: TextField(
                          controller: _captionController,
                          decoration: InputDecoration(
                            hintText: '그림 설명을 입력하세요',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF9CA3AF),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10), // CSS: border-radius: 10px
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E0E0), // CSS: border: 2px solid #e0e0e0
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E0E0),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor, // CSS: border-color: #667eea (focus)
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16), // CSS: padding: 1rem
                          ),
                          style: const TextStyle(
                            fontSize: 16, // CSS: font-size: 1rem
                          ),
                          maxLines: 3,
                        ),
                      ),
                      // 태그 (CSS: .form-group)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24), // CSS: margin-bottom: 1.5rem
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '태그',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600, // CSS: font-weight: 600
                                color: AppTheme.textPrimary, // CSS: color: #333
                                fontSize: 16, // CSS: 1rem
                              ),
                            ),
                            const SizedBox(height: 8), // CSS: margin-bottom: 0.5rem
                            TextFormField(
                              controller: _tagsController,
                              decoration: InputDecoration(
                                hintText: '그림,일러스트,캐릭터,손그림...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  color: Color(0xFF9CA3AF),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10), // CSS: border-radius: 10px
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0), // CSS: border: 2px solid #e0e0e0
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryColor, // CSS: border-color: #667eea (focus)
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(12), // CSS: padding: 0.75rem
                              ),
                              style: const TextStyle(
                                fontSize: 16, // CSS: font-size: 1rem
                              ),
                              maxLength: 100,
                            ),
                            // 힌트 (CSS: .form-hint)
                            Padding(
                              padding: const EdgeInsets.only(top: 8), // CSS: margin-top: 0.5rem
                              child: Text(
                                '쉼표(,)로 구분하여 5개 까지만 입력해주세요',
                                style: TextStyle(
                                  color: AppTheme.textSecondary, // CSS: color: #666
                                  fontSize: 13.6, // CSS: 0.85rem ≈ 13.6px
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 업로드 버튼 (아이템 사용하기 버튼과 동일 스타일)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _uploadPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isUploading ? '업로드 중... (약 10초 소요)' : '업로드',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 작품 유형 탭 (상용 앱 세그먼트 스타일)
class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// 라디오 옵션 위젯 (CSS: .radio-label)
class _RadioOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          Container(
            width: 18, // CSS: width: 18px
            height: 18, // CSS: height: 18px
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF999999),
                width: 2,
              ),
              color: isSelected ? AppTheme.primaryColor : Colors.white,
            ),
            child: isSelected
                ? const Center(
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8), // CSS: gap
          Text(
            label,
            style: const TextStyle(
              fontSize: 16, // CSS: font-size: 1rem
              color: AppTheme.textPrimary, // CSS: color: #333
            ),
          ),
        ],
      ),
    );
  }
}