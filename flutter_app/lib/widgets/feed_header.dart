import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FeedHeader extends StatefulWidget {
  final VoidCallback? onUploadTap;

  const FeedHeader({
    super.key,
    this.onUploadTap,
  });

  @override
  State<FeedHeader> createState() => _FeedHeaderState();
}

class _FeedHeaderState extends State<FeedHeader> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.pushNamed(
        context,
        '/search',
        arguments: query,
      );
    }
  }

  void _handleUpload() {
    if (widget.onUploadTap != null) {
      widget.onUploadTap!();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          // 검색바 (기존 CSS: .search-container)
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 16, right: 4, top: 0, bottom: 0), // 오른쪽 패딩 최소화
              decoration: BoxDecoration(
                color: Colors.white, // CSS: background: white
                borderRadius: BorderRadius.circular(25), // CSS: border-radius: 25px
                border: Border.all(
                  color: const Color(0x0F000000), // CSS: rgba(0, 0, 0, 0.06)
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06), // CSS: rgba(0, 0, 0, 0.06)
                    blurRadius: 8, // CSS: 8px
                    offset: const Offset(0, 2), // CSS: 0 2px
                  ),
                ],
              ),
              child: Row(
                children: [
                  // CSS: .search-input - width: 200px는 Expanded로 자동 조정
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8), // 검색 버튼과 간격
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: '작품 검색',
                        hintStyle: TextStyle(
                          color: AppTheme.textTertiary, // CSS: color: #999
                          fontSize: 15.2, // CSS: 0.95rem ≈ 15.2px
                        ),
                        border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                      ),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15.2,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _handleSearch(),
                    ),
                  ),
                  ),
                  // 검색 버튼 (CSS: .search-btn) - 오른쪽 끝에 붙임
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleSearch,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40, // CSS: 2.5rem = 40px
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0F2FF), // CSS: background: #f0f2ff
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search,
                          color: AppTheme.primaryColor, // CSS: color: #667eea
                          size: 20, // 아이콘 크기
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 업로드 버튼 (기존 CSS: .upload-btn)
          Material(
            color: Colors.white, // CSS: background: white
            borderRadius: BorderRadius.circular(25), // CSS: border-radius: 25px
            child: InkWell(
              onTap: _handleUpload,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // CSS: 0.75rem 1.5rem
                decoration: BoxDecoration(
                  // "완전 흰색"으로 보이도록 테두리/그림자는 제거
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '작품 업로드',
                      style: TextStyle(
                        color: AppTheme.textPrimary, // CSS: color: #333
                        fontSize: 16, // CSS: 1rem = 16px
                        fontWeight: FontWeight.w600, // CSS: font-weight: 600
                      ),
                    ),
                    const SizedBox(width: 8), // CSS: gap: 0.5rem
                    // 업로드 버튼 아이콘 (CSS: .upload-btn-icon) - 오른쪽 끝으로 이동
                    Container(
                      width: 32, // CSS: 2rem = 32px
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient, // CSS: linear-gradient(135deg, #667eea 0%, #764ba2 100%)
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 19.2, // CSS: 1.2rem ≈ 19.2px
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}