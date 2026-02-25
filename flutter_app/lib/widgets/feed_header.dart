import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FeedHeader extends StatefulWidget {
  const FeedHeader({super.key});

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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
        ],
      ),
    );
  }
}