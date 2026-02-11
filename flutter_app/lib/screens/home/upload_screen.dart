import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _uploadPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dataService = Provider.of<DataService>(context, listen: false);
      
      if (!authService.isLoggedIn) {
        throw Exception('로그인이 필요합니다.');
      }

      // 이미지 업로드
      final imageUrl = await dataService.uploadImage(
        _selectedImage!,
        authService.user!.uid,
        'posts',
      );

      // 게시물 생성
      await dataService.createPost(
        userId: authService.user!.uid,
        username: authService.userData?['name'] ?? authService.user!.displayName ?? '익명',
        title: _titleController.text.trim(),
        caption: _captionController.text.trim().isEmpty 
            ? null 
            : _captionController.text.trim(),
        imageUrl: imageUrl,
        tags: _tagsController.text.trim().isEmpty
            ? []
            : _tagsController.text.trim().split(',').map((t) => t.trim()).toList(),
      );

      if (!mounted) return;
      
      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물이 업로드되었습니다!')),
      );

      // 폼 초기화
      _titleController.clear();
      _captionController.clear();
      _tagsController.clear();
      setState(() {
        _selectedImage = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('작품 업로드'),
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (!authService.isLoggedIn) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('로그인이 필요합니다.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // 로그인 화면으로 이동
                    },
                    child: const Text('로그인'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 이미지 선택
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48),
                                  SizedBox(height: 8),
                                  Text('이미지 선택'),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 제목
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '제목을 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 설명
                  TextFormField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      labelText: '설명 (선택)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  // 태그
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: '태그 (쉼표로 구분)',
                      border: OutlineInputBorder(),
                      hintText: '예: 그림, 디지털아트, 일러스트',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 업로드 버튼
                  ElevatedButton(
                    onPressed: _isUploading ? null : _uploadPost,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : const Text('업로드'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}



