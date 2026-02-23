import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/upload_modal.dart';
import 'home_screen.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  bool _isLoadingMissions = true;
  String? _lastUserId;
  int _completedMissionCount = 0;
  int _totalMissionReward = 0;
  int _userPostCount = 0; // 사용자가 업로드한 게시물 수
  StreamSubscription? _notificationSubscription;
  bool _isPopupOpen = false; // 팝업 중복 방지

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMissions();
      _listenForMissionNotifications();
    });
  }


  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // 미션 완료 알림 감지하여 통계 업데이트
  void _listenForMissionNotifications() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) return;

    final dataService = Provider.of<DataService>(context, listen: false);
    
    // 미션 완료 알림을 감지하기 위해 알림 목록을 주기적으로 확인
    // 또는 실시간 스트림 사용
    _notificationSubscription = Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) async {
          try {
            final notifications = await dataService.getUserNotifications(authService.user!.uid, limit: 10);
            // 최근 미션 완료 알림이 있는지 확인
            final missionNotifications = notifications.where((n) => 
              n.type == 'mission_complete' && 
              !n.read &&
              n.createdAt.isAfter(DateTime.now().subtract(const Duration(seconds: 5)))
            ).toList();
            
            if (missionNotifications.isNotEmpty && mounted) {
              // 미션 완료 알림이 있으면 통계 업데이트
              _updateStatistics();
            }
          } catch (e) {
            debugPrint('알림 확인 오류 (무시): $e');
          }
        })
        .listen((_) {});
  }

  // 통계만 업데이트하는 함수
  Future<void> _updateStatistics() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dataService = Provider.of<DataService>(context, listen: false);
    
    if (authService.user == null) return;
    
    try {
      final completedCount = await dataService.getCompletedMissionCount(authService.user!.uid);
      final totalReward = await dataService.getTotalMissionReward(authService.user!.uid);
      
      if (mounted) {
        setState(() {
          _completedMissionCount = completedCount;
          _totalMissionReward = totalReward;
        });
      }
    } catch (e) {
      debugPrint('통계 업데이트 오류 (무시): $e');
    }
  }

  // 동기적으로 사용 가능한 미션 목록 가져오기 (Consumer 내에서 사용)
  List<Mission> _getAvailableMissionsSync(DataService dataService, AuthService authService) {
    try {
      if (authService.user == null) {
        // 로그인하지 않은 경우 첫 작품 업로드 미션만 표시
        return dataService.missions.where((m) => m.type == 'first_upload').toList();
      }

      final List<Mission> result = [];
      
      // 표시할 미션 타입 목록
      final allowedMissionTypes = ['first_upload', 'like_click'];
      
      // 모든 미션 필터링
      for (final mission in dataService.missions) {
        // 허용된 미션 타입만 표시
        if (!allowedMissionTypes.contains(mission.type)) {
          continue;
        }
        
        // 첫 작품 업로드 미션 필터링
        if (mission.type == 'first_upload') {
          final userMission = dataService.userMissions[mission.id];
          // 완료한 first_upload 미션은 표시하지 않음
          if (userMission != null && userMission.completed) {
            continue;
          }
          // 사용자가 이미 게시물을 1개 이상 업로드한 경우도 표시하지 않음
          if (_userPostCount >= 1) {
            continue;
          }
        }
        
        result.add(mission);
      }
      
      return result;
    } catch (e) {
      debugPrint('동기 미션 목록 가져오기 오류: $e');
      return [];
    }
  }

  Future<void> _loadMissions() async {
    try {
      final dataService = Provider.of<DataService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // 로그인한 사용자의 미션 상태를 실시간으로 감시 (다른 기기에서 진행도가 변경되어도 즉시 반영)
      if (authService.user != null) {
        dataService.listenUserMissions(authService.user!.uid);
      }

      // 미션 목록 가져오기
      await dataService.getMissions();
      
      // 잠시 대기하여 _missions 리스트가 업데이트되도록 함
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 사용자 미션 상태 가져오기
      if (authService.user != null) {
        try {
          await dataService.getUserMissions(authService.user!.uid);
        } catch (e) {
          debugPrint('사용자 미션 상태 가져오기 오류 (무시): $e');
        }
      }
      
      // 완료한 미션 수와 획득한 코인 수 가져오기 (coinHistory 기반)
      int completedCount = 0;
      int totalReward = 0;
      int userPostCount = 0;
      if (authService.user != null) {
        try {
          completedCount = await dataService.getCompletedMissionCount(authService.user!.uid);
          totalReward = await dataService.getTotalMissionReward(authService.user!.uid);
          
          // 사용자가 업로드한 게시물 수 확인
          final username = authService.userData?['name'] as String? ?? '';
          if (username.isNotEmpty) {
            final userPosts = await dataService.getUserPosts(username);
            userPostCount = userPosts.length;
          }
        } catch (e) {
          debugPrint('미션 통계 가져오기 오류 (무시): $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _completedMissionCount = completedCount;
          _totalMissionReward = totalReward;
          _userPostCount = userPostCount;
          _isLoadingMissions = false;
        });
      }
    } catch (e) {
      debugPrint('미션 로딩 오류: $e');
      if (mounted) {
        setState(() {
          _isLoadingMissions = false;
        });
      }
    }
  }

  void _navigateToFeedAndOpenUpload(BuildContext context) {
    // HomeScreen 찾기
    final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
    if (homeScreenState != null) {
      // 피드 페이지로 이동 (인덱스 0)
      homeScreenState.setCurrentIndex(0);
      
      // 약간의 딜레이 후 업로드 모달 열기 (화면 전환 애니메이션 완료 대기)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final authService = Provider.of<AuthService>(context, listen: false);
          if (!authService.isLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('로그인이 필요합니다.'),
              ),
            );
            return;
          }
          // 업로드 모달 표시
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => const UploadModal(),
          );
        }
      });
    }
  }

  void _showTimeLimitedMissionPopup(BuildContext context, Mission mission) {
    // 팝업이 이미 열려있으면 중복 방지
    if (_isPopupOpen) {
      return;
    }
    
    _isPopupOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Consumer<DataService>(
        builder: (context, dataService, _) {
          final authService = Provider.of<AuthService>(context, listen: false);
          
          bool isParticipated = false;
          int progress = 0;
          DateTime? startTime;
          
          // 미션 상태 확인
          if (authService.user != null) {
            final userMission = dataService.userMissions[mission.id];
            if (userMission != null && userMission.startTime != null) {
              isParticipated = true;
              progress = userMission.progress;
              startTime = userMission.startTime;
            }
          }
          
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 설명 문구
                Text(
                  mission.type == 'like_click' 
                      ? '일주일 동안 좋아요 3개를 누르세요'
                      : '7일 동안 작품이 7번 인기작품으로 선정되세요',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                
                if (!isParticipated) ...[
                  // 미션 참가하기 버튼
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: AppTheme.gradientButtonDecoration,
                      child: ElevatedButton(
                        onPressed: () async {
                          debugPrint('🎯 [MissionScreen] 미션 참가하기 버튼 클릭: missionId=${mission.id}');
                          
                          if (authService.user == null) {
                            debugPrint('❌ [MissionScreen] 사용자가 로그인하지 않음');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('로그인이 필요합니다.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          debugPrint('✅ [MissionScreen] 사용자 확인: ${authService.user!.uid}');
                          
                          // 좋아요 3개 누르기 미션: 참가비 50코인 사전 확인
                          if (mission.type == 'like_click') {
                            final coins = authService.userData?['coins'];
                            final coinCount = coins is int ? coins : int.tryParse('$coins') ?? 0;
                            if (coinCount < 50) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('50코인이 필요합니다. 코인이 부족합니다.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              return;
                            }
                          }
                          
                          try {
                            // 시간 제한 미션 시작
                            debugPrint('🚀 [MissionScreen] startMission 호출 시작');
                            final success = await dataService.startMission(
                              userId: authService.user!.uid,
                              missionId: mission.id,
                            );
                            debugPrint('📊 [MissionScreen] startMission 결과: $success');
                            
                            if (success) {
                              debugPrint('✅ [MissionScreen] 미션 시작 성공');
                              // 팝업 닫기
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                              
                              // 미션 상태 새로고침
                              await dataService.getUserMissions(authService.user!.uid);
                              
                              // 미션 목록 새로고침
                              await _loadMissions();
                            } else {
                              debugPrint('❌ [MissionScreen] 미션 시작 실패 (success=false)');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      mission.type == 'like_click'
                                          ? '50코인이 부족하여 미션에 참가할 수 없습니다.'
                                          : '미션 시작에 실패했습니다.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e, stackTrace) {
                            debugPrint('❌ [MissionScreen] 예외 발생: $e');
                            debugPrint('❌ [MissionScreen] 스택 트레이스: $stackTrace');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('미션 시작 중 오류가 발생했습니다: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: mission.type == 'like_click'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '미션 참가하기 ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'C',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '50',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                '미션 참가하기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ] else ...[
                  // 진행척도 표시
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '진행도',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '$progress / ${mission.targetCount ?? 3}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (progress / (mission.targetCount ?? 3)).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 7일 카운트다운
                      if (startTime != null)
                        StreamBuilder<DateTime>(
                          stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                          builder: (context, snapshot) {
                            final now = snapshot.data ?? DateTime.now();
                            final endTime = startTime!.add(const Duration(days: 7));
                            final remaining = endTime.difference(now);
                            
                            if (remaining.isNegative) {
                              return const Text(
                                '미션 기간이 종료되었습니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }
                            
                            final days = remaining.inDays;
                            final hours = remaining.inHours % 24;
                            final minutes = remaining.inMinutes % 60;
                            final seconds = remaining.inSeconds % 60;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '남은 시간',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${days}일 ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      // 팝업이 닫히면 플래그 리셋
      _isPopupOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 768;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: null, // 상단 네비게이션은 HomeScreen에서 처리
      body: SafeArea(
        bottom: false, // 하단 SafeArea는 하단바가 처리
        child: Consumer2<DataService, AuthService>(
          builder: (context, dataService, authService, _) {
            // 사용자 변경 시 미션 목록 자동 새로고침
            final currentUserId = authService.user?.uid;
            if (currentUserId != _lastUserId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _lastUserId = currentUserId;
                  });
                  _loadMissions();
                }
              });
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                await _loadMissions();
              },
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // 통계 카드
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 32,
                        vertical: 16,
                      ),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              icon: null,
                              label: '완료한 미션',
                              value: '$_completedMissionCount개',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: const Color(0xFFF0F0F0),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          Expanded(
                            child: _StatItem(
                              icon: null,
                              label: '획득한 코인',
                              value: '${NumberFormat('#,###').format(_totalMissionReward)}C',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 미션 리스트
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 32,
                        vertical: 16,
                      ),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '고정 미션',
                            style: TextStyle(
                              fontSize: 20.8, // 1.3rem ≈ 20.8px
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Builder(
                            builder: (context) {
                              // Consumer 내에서 실시간으로 미션 목록 가져오기
                              final availableMissions = _isLoadingMissions 
                                  ? <Mission>[]
                                  : _getAvailableMissionsSync(dataService, authService);
                              
                              if (_isLoadingMissions) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(48),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text(
                                          '미션을 불러오는 중...',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              if (availableMissions.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(48),
                                    child: Text(
                                      '진행 가능한 미션이 없습니다.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              
                              return Column(
                                children: availableMissions.map((mission) {
                              final userMission = dataService.userMissions[mission.id];
                              final isCompleted = userMission?.completed ?? false;
                              final progress = userMission?.progress ?? 0;
                              final targetCount = mission.targetCount ?? 1;
                              // 미션을 시작했는지 확인 (startTime이 있어야 진행도 표시)
                              final hasStarted = userMission?.startTime != null;
                              final progressPercent = (progress / targetCount).clamp(0.0, 1.0);

                              // 디버그: UI에서 사용 중인 미션 진행도 로그
                              debugPrint('🧩 [MissionScreen] missionId=${mission.id}, type=${mission.type}, uiProgress=$progress/$targetCount, completed=$isCompleted, hasStarted=$hasStarted');

                              return _MissionCard(
                                mission: mission,
                                isCompleted: isCompleted,
                                progress: progress,
                                targetCount: targetCount,
                                progressPercent: progressPercent,
                                hasStarted: hasStarted,
                                onTap: authService.user != null && mission.type != 'first_upload'
                                    ? () async {
                                        // 첫 작품 업로드 미션은 수동 완료 불가 (자동 완료만 가능)
                                        // like_click 미션의 경우, 미션이 시작되었고 완료되지 않았을 때만 수동 완료 가능
                                        if (mission.type == 'like_click') {
                                          final userMission = dataService.userMissions[mission.id];
                                          if (userMission == null || userMission.startTime == null || userMission.completed) {
                                            // 미션이 시작되지 않았거나 이미 완료된 경우 아무것도 하지 않음
                                            return;
                                          }
                                        }
                                        
                                        if (!isCompleted || (mission.isRepeatable && !isCompleted)) {
                                          final success = await dataService.completeMission(
                                            userId: authService.user!.uid,
                                            missionId: mission.id,
                                            missionType: mission.type,
                                          );
                                          
                                          if (success && mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('미션 완료'),
                                                backgroundColor: AppTheme.primaryColor,
                                              ),
                                            );
                                            // 미션 목록 새로고침
                                            await _loadMissions();
                                            
                                            // coinHistory 반영을 위해 약간의 딜레이 후 통계만 다시 업데이트
                                            await Future.delayed(const Duration(milliseconds: 500));
                                            if (mounted && authService.user != null) {
                                              try {
                                                final updatedCount = await dataService.getCompletedMissionCount(authService.user!.uid);
                                                final updatedReward = await dataService.getTotalMissionReward(authService.user!.uid);
                                                if (mounted) {
                                                  setState(() {
                                                    _completedMissionCount = updatedCount;
                                                    _totalMissionReward = updatedReward;
                                                  });
                                                }
                                              } catch (e) {
                                                debugPrint('통계 업데이트 오류 (무시): $e');
                                              }
                                            }
                                          }
                                        }
                                      }
                                    : null,
                                onRewardTap: mission.type == 'first_upload'
                                    ? () => _navigateToFeedAndOpenUpload(context)
                                    : mission.type == 'like_click'
                                        ? () => _showTimeLimitedMissionPopup(context, mission)
                                        : null,
                              );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 하단 여백
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;

  const _StatItem({
    this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.6, // 0.85rem ≈ 13.6px
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20.8, // 1.3rem ≈ 20.8px
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Mission mission;
  final bool isCompleted;
  final int progress;
  final int targetCount;
  final double progressPercent;
  final bool hasStarted;
  final VoidCallback? onTap;
  final VoidCallback? onRewardTap;

  const _MissionCard({
    required this.mission,
    required this.isCompleted,
    required this.progress,
    required this.targetCount,
    required this.progressPercent,
    required this.hasStarted,
    this.onTap,
    this.onRewardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: const Color(0xFFF8F9FF), // CSS: #f8f9ff
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onRewardTap != null ? null : onTap, // 300코인 버튼이 있으면 카드 클릭 비활성화
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 20, 20, 20), // 왼쪽 패딩 제거
            child: Row(
              children: [
                // 내용 (들여쓰기 없이)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20), // 제목만 왼쪽 패딩
                        child: Text(
                          mission.title,
                          style: const TextStyle(
                            fontSize: 16, // 1rem
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (mission.type == 'first_upload') ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 20), // 제목과 동일한 왼쪽 패딩
                          child: Text(
                            '첫번째 작품을 업로드하세요',
                            style: TextStyle(
                              fontSize: 12, // 더 작은 사이즈
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      // 미션을 시작했고 완료하지 않았을 때만 진행도 표시
                      if (targetCount > 1 && !isCompleted && hasStarted) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressPercent,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(
                            '$progress / $targetCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // 보상 (300 + 코인 아이콘) - 클릭 가능, 입체감 추가
                GestureDetector(
                  onTap: onRewardTap != null
                      ? () {
                          // 이벤트 전파 방지 및 중복 클릭 방지
                    if (onRewardTap != null) {
                      onRewardTap!();
                    }
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${NumberFormat('#,###').format(mission.reward)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'C',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
    );
  }

  IconData _getMissionIcon(String type) {
    switch (type) {
      case 'upload':
        return Icons.upload;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'popular':
        return Icons.star;
      case 'attendance':
        return Icons.calendar_today;
      default:
        return Icons.assignment;
    }
  }
}

