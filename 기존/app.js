// 메인 페이지 초기화 및 업로드 모달 관리

let currentUser = null;
let isInitialLoad = true; // 초기 로드 여부 플래그

// 페이지 초기화 함수
async function initializePage() {
    // Firebase 초기화 대기
    await waitForFirebase();
    
    // 사용자 캐시 초기화 (최신 상태 확인)
    if (window.dataManager && window.dataManager.clearUserCache) {
        window.dataManager.clearUserCache();
    }
    
    // 현재 사용자 확인
    checkAuthState();
    
    // 업로드 모달 설정
    if (window.setupUploadModal) {
        window.setupUploadModal();
    }
    
    // 코인 모달 설정
    setupCoinModal();
    
    // 검색 기능 설정
    setupSearch();
    
    // 피드 로드
    const feedContainer = document.getElementById('feedContainer');
    if (feedContainer) {
        await loadFeed();
        isInitialLoad = false;
    }
}

// 페이지 로드 시 초기화 (DOMContentLoaded 또는 즉시 실행)
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializePage);
} else {
    // DOM이 이미 로드된 경우 즉시 실행
    initializePage();
}
// Firebase 초기화 대기
async function waitForFirebase() {
    return new Promise((resolve) => {
        let attempts = 0;
        const maxAttempts = 50;
        
        const checkInterval = setInterval(() => {
            attempts++;
            if (db && storage && firebaseAuth) {
                clearInterval(checkInterval);
                resolve();
            } else if (attempts >= maxAttempts) {
                clearInterval(checkInterval);
                console.error('Firebase 초기화 실패');
                resolve();
            }
        }, 100);
    });
}

// 마지막으로 네비게이션을 업데이트한 사용자 ID 저장
let lastNavigationUserId = null;
let lastNavigationState = null; // 'logged_in' or 'logged_out'

// 인증 상태 확인
function checkAuthState() {
    if (!firebaseAuth) {
        setTimeout(checkAuthState, 100);
        return;
    }

    // onAuthStateChanged는 한 번만 등록 (중복 등록 방지)
    if (window.authStateListenerRegistered) {
        return;
    }
    window.authStateListenerRegistered = true;

    firebaseAuth.onAuthStateChanged(async function(user) {
        const previousUserId = currentUser ? currentUser.uid : null;
        const newUserId = user ? user.uid : null;
        
        currentUser = user;
        
        // 사용자가 변경되었을 때 피드 새로고침 (계정 전환 또는 로그아웃)
        // 단, 초기 로드 시에는 제외 (이미 DOMContentLoaded에서 로드됨)
        if (!isInitialLoad && previousUserId !== newUserId) {
            const feedContainer = document.getElementById('feedContainer');
            if (feedContainer) {
                // 피드가 있는 페이지에서만 새로고침
                await loadFeed();
            }
        }
        
        // 라우터를 통해 페이지 전환 중이면 네비게이션 업데이트 건너뛰기
        if (window.isRouterNavigation) {
            return;
        }
        
        // 네비게이션 업데이트는 사용자가 변경되었을 때만 수행
        const currentState = user ? 'logged_in' : 'logged_out';
        const shouldUpdateNavigation = (newUserId !== lastNavigationUserId) || 
                                      (currentState !== lastNavigationState);
        
        if (shouldUpdateNavigation) {
            if (user) {
                // 사용자 정보 가져오기
                const userInfo = await getUserInfo(user.uid);
                if (userInfo) {
                    currentUser.username = userInfo.name;
                    currentUser.uid = user.uid;
                } else {
                    currentUser.username = user.displayName || user.email.split('@')[0];
                    currentUser.uid = user.uid;
                }
                
                updateNavigation(user);
            } else {
                updateNavigation(null);
            }
            
            // 마지막 업데이트 상태 저장
            lastNavigationUserId = newUserId;
            lastNavigationState = currentState;
        }
    });
}

// 사용자 정보 가져오기
async function getUserInfo(uid) {
    try {
        if (!db) {
            await waitForFirebase();
        }
        
        const doc = await db.collection('users').doc(uid).get();
        if (doc.exists) {
            return doc.data();
        }
        return null;
    } catch (error) {
        console.error('사용자 정보 가져오기 오류:', error);
        return null;
    }
}

// 네비게이션 업데이트
// 전역 함수로 export
window.updateNavigation = function(user) {
    // 라우터를 통해 페이지 전환 중이면 네비게이션 업데이트 완전히 건너뛰기
    if (window.isRouterNavigation) {
        return;
    }
    
    const loginLink = document.getElementById('loginLink');
    const profileDropdown = document.getElementById('profileDropdown');
    const uploadBtn = document.getElementById('uploadBtn');
    const notificationWrapper = document.getElementById('notificationWrapper');
    const pointsDisplay = document.getElementById('pointsDisplay');
    
    // 라우터에 의해 잠긴 요소는 업데이트하지 않음
    if (profileDropdown && profileDropdown.getAttribute('data-router-locked') === 'true') {
        return;
    }
    if (notificationWrapper && notificationWrapper.getAttribute('data-router-locked') === 'true') {
        return;
    }
    if (pointsDisplay && pointsDisplay.getAttribute('data-router-locked') === 'true') {
        return;
    }
    if (loginLink && loginLink.getAttribute('data-router-locked') === 'true') {
        return;
    }
    
    // 이미 업데이트 중이면 건너뛰기 (중복 업데이트 방지)
    if (window.isUpdatingNavigation) {
        return;
    }
    
    // 현재 상태 확인 (깜빡임 방지)
    // 코인도 프로필/알림과 동일하게 체크
    const isCurrentlyLoggedIn = profileDropdown && 
                                profileDropdown.style.display === 'block' &&
                                notificationWrapper &&
                                notificationWrapper.style.display === 'block' &&
                                pointsDisplay &&
                                (pointsDisplay.style.display === 'flex' || pointsDisplay.classList.contains('coins-visible'));
    
    const isCurrentlyLoggedOut = loginLink && 
                                loginLink.style.display === 'block' &&
                                (!profileDropdown || profileDropdown.style.display === 'none');
    
    // 이미 올바른 상태면 업데이트하지 않음 (깜빡임 방지)
    if (user && isCurrentlyLoggedIn) {
        return; // 이미 로그인 상태로 올바르게 표시됨
    }
    if (!user && isCurrentlyLoggedOut) {
        return; // 이미 로그아웃 상태로 올바르게 표시됨
    }
    
    window.isUpdatingNavigation = true;
    
    // 업데이트 완료 후 플래그 해제 (비동기로)
    setTimeout(() => {
        window.isUpdatingNavigation = false;
    }, 100);

    if (user) {
        // 로그인된 경우
        // display 변경을 최소화하여 깜빡임 방지
        if (loginLink) {
            // 이미 숨겨져 있으면 변경하지 않음
            if (loginLink.style.display !== 'none') {
                loginLink.style.display = 'none';
                loginLink.style.visibility = 'hidden';
                loginLink.style.opacity = '0';
                loginLink.style.position = 'absolute';
                loginLink.style.left = '-9999px';
                loginLink.setAttribute('hidden', '');
            }
        }
        if (profileDropdown) {
            // 이미 표시되어 있으면 변경하지 않음
            if (profileDropdown.style.display !== 'block') {
                // 깜빡임 방지를 위해 transition 제거 후 설정
                profileDropdown.style.transition = 'none';
                profileDropdown.style.display = 'block';
                profileDropdown.style.visibility = 'visible';
                profileDropdown.style.opacity = '1';
            }
        }
        if (uploadBtn && uploadBtn.style.display !== 'flex') {
            uploadBtn.style.display = 'flex';
        }
        // 알림 아이콘 표시 (이미 표시되어 있으면 스타일 변경하지 않음)
        if (notificationWrapper) {
            const isAlreadyVisible = notificationWrapper.style.display === 'block' || 
                                     notificationWrapper.classList.contains('notification-visible');
            if (!isAlreadyVisible) {
                // 깜빡임 방지를 위해 transition 제거 후 설정
                notificationWrapper.style.transition = 'none';
                notificationWrapper.style.display = 'block';
                notificationWrapper.style.visibility = 'visible';
                notificationWrapper.style.opacity = '1';
                notificationWrapper.classList.add('notification-visible');
            }
        }
        
        // 프로필 드롭다운 설정 (즉시 실행)
        setupProfileDropdown();
        
        // 알림 설정 (비동기로 처리하여 상단바 표시를 차단하지 않음)
        // 이미 설정되어 있으면 다시 설정하지 않음
        // 라우터 네비게이션 중이면 설정하지 않음
        if (user.uid && !window.notificationUnsubscribe && !window.isRouterNavigation) {
            const notificationWrapper = document.getElementById('notificationWrapper');
            // 알림 래퍼가 잠겨있지 않을 때만 설정
            if (!notificationWrapper || notificationWrapper.getAttribute('data-router-locked') !== 'true') {
                setTimeout(() => {
                    setupNotifications(user.uid);
                }, 0);
            }
        }
        
        // 코인 표시 (프로필/알림과 동일한 방식으로 즉시 표시)
        const pointsDisplay = document.getElementById('pointsDisplay');
        if (pointsDisplay) {
            // 라우터에 의해 잠겨있으면 완전히 건너뛰기 (깜빡임 방지)
            if (pointsDisplay.getAttribute('data-router-locked') === 'true') {
                // 코인 요소가 잠겨있으면 아무것도 하지 않음
            } else {
                // 이미 표시되어 있으면 변경하지 않음 (프로필/알림과 동일한 로직)
                if (pointsDisplay.style.display !== 'flex') {
                    // 깜빡임 방지를 위해 transition 제거 후 설정
                    pointsDisplay.style.transition = 'none';
                    pointsDisplay.style.display = 'flex';
                    pointsDisplay.style.visibility = 'visible';
                    pointsDisplay.style.opacity = '1';
                    // CSS 클래스 추가로 표시 강제
                    pointsDisplay.classList.add('coins-visible');
                    pointsDisplay.classList.remove('coins-hidden');
                }
                
                // localStorage에서 마지막 코인 잔액 확인 (즉시 표시, 값이 없을 때만)
                const coinsValue = pointsDisplay.querySelector('.point-value');
                if (coinsValue) {
                    // 값이 없거나 0이면 localStorage에서 가져오기
                    if (!coinsValue.textContent || coinsValue.textContent === '0' || coinsValue.textContent.trim() === '') {
                        try {
                            const lastCoinBalance = localStorage.getItem('lastCoinBalance');
                            if (lastCoinBalance) {
                                coinsValue.textContent = lastCoinBalance;
                            }
                        } catch (e) {
                            // localStorage 접근 실패 시 무시
                        }
                    }
                }
            }
        }
        
        // 백그라운드에서 최신 코인 잔액 업데이트 (상단바 표시를 차단하지 않음)
        // 이미 업데이트 중이면 다시 업데이트하지 않음
        // 코인 요소가 잠겨있지 않을 때만 업데이트
        const pointsDisplayForUpdate = document.getElementById('pointsDisplay');
        if (!window.isUpdatingCoinBalance && 
            pointsDisplayForUpdate && 
            pointsDisplayForUpdate.getAttribute('data-router-locked') !== 'true') {
            window.isUpdatingCoinBalance = true;
            // 즉시 실행 (비동기로 처리하여 블로킹하지 않음)
            updateCoinBalance().then(() => {
                // 업데이트된 코인 잔액을 localStorage에 저장
                const coinsValue = document.querySelector('#pointsDisplay .point-value');
                if (coinsValue) {
                    try {
                        localStorage.setItem('lastCoinBalance', coinsValue.textContent);
                    } catch (e) {
                        // localStorage 저장 실패 시 무시
                    }
                }
                window.isUpdatingCoinBalance = false;
            }).catch(err => {
                console.warn('코인 잔액 업데이트 실패 (무시):', err);
                window.isUpdatingCoinBalance = false;
            });
        }
        
        // 로그아웃 버튼 설정
        const logoutBtn = document.getElementById('logoutBtn');
        if (logoutBtn) {
            logoutBtn.onclick = async function(e) {
                e.preventDefault();
                await signOut();
            };
        }
    } else {
        // 로그인되지 않은 경우 - 작품은 볼 수 있지만 업로드는 불가
        if (profileDropdown) profileDropdown.style.display = 'none';
        if (notificationWrapper) notificationWrapper.style.display = 'none';
        if (loginLink) {
            loginLink.style.display = 'block';
            loginLink.style.visibility = 'visible';
            loginLink.style.opacity = '1';
            loginLink.style.position = 'static';
            loginLink.style.left = 'auto';
            loginLink.removeAttribute('hidden');
        }
        if (uploadBtn) uploadBtn.style.display = 'none';
        
        // 코인 표시 숨기기
        const pointsDisplay = document.getElementById('pointsDisplay');
        if (pointsDisplay) {
            pointsDisplay.style.display = 'none';
            pointsDisplay.classList.add('coins-hidden');
            pointsDisplay.classList.remove('coins-visible');
        }
        
        // 알림 리스너 제거
        if (window.notificationUnsubscribe) {
            window.notificationUnsubscribe();
            window.notificationUnsubscribe = null;
        }
    }
};

// 호환성을 위해 기존 함수명도 유지
function updateNavigation(user) {
    return window.updateNavigation(user);
}

// 검색 기능 설정
function setupSearch() {
    const searchInput = document.getElementById('searchInput');
    const searchBtn = document.getElementById('searchBtn');
    
    if (searchInput && searchBtn) {
        // 검색 버튼 클릭
        searchBtn.addEventListener('click', function() {
            const query = searchInput.value.trim();
            if (query) {
                window.location.href = `search.html?q=${encodeURIComponent(query)}`;
            }
        });
        
        // Enter 키로 검색
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                const query = searchInput.value.trim();
                if (query) {
                    window.location.href = `search.html?q=${encodeURIComponent(query)}`;
                }
            }
        });
    }
    
    // 피드 페이지 모바일 검색바
    const feedSearchInput = document.getElementById('feedSearchInput');
    const feedSearchBtn = document.getElementById('feedSearchBtn');
    
    if (feedSearchInput && feedSearchBtn) {
        feedSearchBtn.addEventListener('click', function() {
            const query = feedSearchInput.value.trim();
            if (query) {
                window.location.href = `search.html?q=${encodeURIComponent(query)}`;
            }
        });
        
        feedSearchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                const query = feedSearchInput.value.trim();
                if (query) {
                    window.location.href = `search.html?q=${encodeURIComponent(query)}`;
                }
            }
        });
    }
}

// 프로필 드롭다운 설정
function setupProfileDropdown() {
    const profileIcon = document.getElementById('profileIcon');
    const dropdownMenu = document.getElementById('dropdownMenu');
    
    if (profileIcon && dropdownMenu) {
        profileIcon.onclick = function(e) {
            e.stopPropagation();
            const isVisible = dropdownMenu.style.display === 'block';
            dropdownMenu.style.display = isVisible ? 'none' : 'block';
        };
        
        // 외부 클릭 시 드롭다운 닫기
        document.onclick = function(e) {
            const profileDropdown = document.getElementById('profileDropdown');
            if (profileDropdown && !profileDropdown.contains(e.target)) {
                dropdownMenu.style.display = 'none';
            }
        };
    }
}

// 로그아웃
async function signOut() {
    try {
        if (!firebaseAuth) {
            await waitForFirebase();
        }
        
        // 알림 리스너 제거
        if (window.notificationUnsubscribe) {
            window.notificationUnsubscribe();
            window.notificationUnsubscribe = null;
        }
        
        // 현재 사용자의 본 게시물 정보 삭제
        clearViewedPosts();
        
        await firebaseAuth.signOut();
        window.location.href = 'index.html';
    } catch (error) {
        console.error('로그아웃 오류:', error);
    }
}

// 알림 설정
function setupNotifications(userId) {
    const notificationIcon = document.getElementById('notificationIcon');
    const notificationBadge = document.getElementById('notificationBadge');
    const notificationModal = document.getElementById('notificationModal');
    const notificationClose = document.getElementById('notificationClose');
    const notificationList = document.getElementById('notificationList');
    const noNotifications = document.getElementById('noNotifications');
    const markAllReadBtn = document.getElementById('markAllReadBtn');
    
    if (!notificationIcon || !userId) return;
    
    // 알림 아이콘 클릭 시 모달 열기
    notificationIcon.onclick = function() {
        if (notificationModal) {
            notificationModal.style.display = 'block';
            loadNotifications(userId);
        }
    };
    
    // 모달 닫기
    if (notificationClose) {
        notificationClose.onclick = function() {
            if (notificationModal) {
                notificationModal.style.display = 'none';
            }
        };
    }
    
    // 모달 외부 클릭 시 닫기
    if (notificationModal) {
        window.onclick = function(e) {
            if (e.target === notificationModal) {
                notificationModal.style.display = 'none';
            }
        };
    }
    
    // 모두 읽음 처리
    if (markAllReadBtn) {
        markAllReadBtn.onclick = async function() {
            try {
                await window.dataManager.markAllNotificationsAsRead(userId);
                await loadNotifications(userId);
                await updateNotificationBadge(userId);
            } catch (error) {
                console.error('모두 읽음 처리 오류:', error);
            }
        };
    }
    
    // 알림 로드 함수
    async function loadNotifications(uid) {
        try {
            console.log('🔔 알림 로드 시작:', uid);
            const notifications = await window.dataManager.getUserNotifications(uid);
            console.log('📋 가져온 알림 개수:', notifications.length);
            console.log('📋 알림 데이터:', notifications);
            
            if (notifications.length === 0) {
                if (notificationList) notificationList.innerHTML = '';
                if (noNotifications) noNotifications.style.display = 'block';
                if (markAllReadBtn) markAllReadBtn.style.display = 'none';
                console.log('ℹ️ 알림이 없습니다.');
                return;
            }
            
            if (noNotifications) noNotifications.style.display = 'none';
            
            const unreadCount = notifications.filter(n => !n.read).length;
            if (markAllReadBtn) {
                markAllReadBtn.style.display = unreadCount > 0 ? 'inline-block' : 'none';
            }
            
            if (notificationList) {
                notificationList.innerHTML = '';
                notifications.forEach((notification, index) => {
                    console.log(`📝 알림 ${index + 1} 처리:`, notification);
                    const notificationItem = document.createElement('div');
                    notificationItem.className = `notification-item ${notification.read ? 'read' : 'unread'}`;
                    
                    const typeText = notification.type === 'like' ? '좋아요' : '댓글';
                    const typeIcon = notification.type === 'like' 
                        ? '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="#ff6b6b" style="width: 1.5rem; height: 1.5rem; display: inline-block;"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>'
                        : '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="#667eea" style="width: 1.5rem; height: 1.5rem; display: inline-block;"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg>';
                    let createdAt;
                    try {
                        if (notification.createdAt) {
                            if (notification.createdAt.toDate) {
                                createdAt = notification.createdAt.toDate();
                            } else if (notification.createdAt.seconds) {
                                createdAt = new Date(notification.createdAt.seconds * 1000);
                            } else {
                                createdAt = new Date(notification.createdAt);
                            }
                        } else {
                            createdAt = new Date();
                        }
                    } catch (e) {
                        console.warn('날짜 변환 오류:', e);
                        createdAt = new Date();
                    }
                    const timeAgo = getTimeAgo(createdAt);
                    
                    // 알림 텍스트 생성
                    let notificationText = '';
                    const firstAuthor = notification.authors && notification.authors.length > 0 
                        ? notification.authors[0] 
                        : (notification.author || '익명');
                    
                    // 대댓글 알림인지 확인
                    const isReply = notification.isReply === true;
                    
                    if (notification.count > 1) {
                        // 여러 명이 반응한 경우
                        const othersCount = notification.count - 1;
                        if (isReply) {
                            notificationText = `<strong>${firstAuthor}</strong>님 외 ${othersCount}명이 "${notification.postTitle || '제목 없음'}"에 답글을 달았습니다`;
                        } else {
                            notificationText = `<strong>${firstAuthor}</strong>님 외 ${othersCount}명이 "${notification.postTitle || '제목 없음'}"에 ${typeText}${notification.type === 'comment' ? '을 달았습니다' : '를 눌렀습니다'}`;
                        }
                    } else {
                        // 한 명만 반응한 경우
                        if (isReply) {
                            notificationText = `<strong>${firstAuthor}</strong>님이 "${notification.postTitle || '제목 없음'}"에 답글을 달았습니다`;
                        } else {
                            notificationText = `<strong>${firstAuthor}</strong>님이 "${notification.postTitle || '제목 없음'}"에 ${typeText}${notification.type === 'comment' ? '을 달았습니다' : '를 눌렀습니다'}`;
                        }
                    }
                    
                    notificationItem.innerHTML = `
                        <div class="notification-content">
                            <div class="notification-icon-badge">${typeIcon}</div>
                            <div class="notification-text-wrapper">
                                <div class="notification-text">
                                    ${notificationText}
                                    ${notification.type === 'comment' && notification.commentText ? `<br><span style="color: #666; font-size: 0.9rem;">"${notification.commentText.substring(0, 50)}${notification.commentText.length > 50 ? '...' : ''}"</span>` : ''}
                                </div>
                                <div class="notification-time">${timeAgo}</div>
                            </div>
                        </div>
                    `;
                    
                    notificationItem.onclick = async function() {
                        // 알림 읽음 처리
                        if (!notification.read) {
                            await window.dataManager.markNotificationAsRead(notification.id);
                            notificationItem.classList.remove('unread');
                            notificationItem.classList.add('read');
                            await updateNotificationBadge(uid);
                        }
                        
                        // 게시물 상세 페이지로 이동 (라우터 사용)
                        if (window.router && window.router.navigate) {
                            window.router.navigate('post-detail', { id: notification.postId });
                        } else {
                            window.location.href = `post-detail.html?id=${notification.postId}`;
                        }
                    };
                    
                    notificationList.appendChild(notificationItem);
                });
                console.log('✅ 알림 목록 표시 완료');
            } else {
                console.error('❌ notificationList 요소를 찾을 수 없습니다.');
            }
        } catch (error) {
            console.error('❌ 알림 로드 오류:', error);
            console.error('오류 상세:', {
                message: error.message,
                code: error.code,
                stack: error.stack
            });
        }
    }
    
    // 시간 표시 함수
    function getTimeAgo(date) {
        const now = new Date();
        const diff = now - date;
        const seconds = Math.floor(diff / 1000);
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        
        if (days > 0) return `${days}일 전`;
        if (hours > 0) return `${hours}시간 전`;
        if (minutes > 0) return `${minutes}분 전`;
        return '방금 전';
    }
    
    // 알림 배지 업데이트 (이미 같은 값이면 업데이트하지 않음)
    async function updateNotificationBadge(uid) {
        // 라우터 네비게이션 중이면 업데이트 건너뛰기
        if (window.isRouterNavigation) {
            return;
        }
        
        // 알림 래퍼가 잠겨있으면 업데이트 건너뛰기
        const notificationWrapper = document.getElementById('notificationWrapper');
        if (notificationWrapper && notificationWrapper.getAttribute('data-router-locked') === 'true') {
            return;
        }
        
        try {
            const count = await window.dataManager.getUnreadNotificationCount(uid);
            if (notificationBadge) {
                const currentText = notificationBadge.textContent;
                const newText = count > 99 ? '99+' : count.toString();
                const currentDisplay = notificationBadge.style.display;
                
                // 값이 같고 표시 상태도 같으면 업데이트하지 않음
                if (currentText === newText && 
                    ((count > 0 && currentDisplay === 'flex') || (count === 0 && currentDisplay === 'none'))) {
                    return;
                }
                
                if (count > 0) {
                    notificationBadge.textContent = newText;
                    notificationBadge.style.display = 'flex';
                } else {
                    notificationBadge.textContent = '';
                    notificationBadge.style.display = 'none';
                }
            }
        } catch (error) {
            console.error('알림 배지 업데이트 오류:', error);
        }
    }
    
    // 실시간 알림 리스너
    if (db) {
        try {
            const notificationsRef = db.collection('notifications')
                .where('userId', '==', userId)
                .where('read', '==', false)
                .orderBy('createdAt', 'desc')
                .limit(1);
            
            window.notificationUnsubscribe = notificationsRef.onSnapshot(async (snapshot) => {
                await updateNotificationBadge(userId);
            }, (error) => {
                console.error('알림 리스너 오류:', error);
                // orderBy 없이 시도
                try {
                    const fallbackRef = db.collection('notifications')
                        .where('userId', '==', userId)
                        .where('read', '==', false);
                    
                    window.notificationUnsubscribe = fallbackRef.onSnapshot(async () => {
                        await updateNotificationBadge(userId);
                    });
                } catch (fallbackError) {
                    console.error('알림 리스너 fallback 오류:', fallbackError);
                }
            });
        } catch (error) {
            console.error('알림 리스너 설정 오류:', error);
        }
    }
    
    // 초기 알림 배지 업데이트
    updateNotificationBadge(userId);
}

// 코인 모달 설정
function setupCoinModal() {
    // DOM이 완전히 로드될 때까지 대기
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setupCoinModal);
        return;
    }
    
    const coinItem = document.getElementById('coinItem');
    const coinModal = document.getElementById('coinModal');
    const coinModalClose = document.getElementById('coinModalClose');
    
    console.log('🔍 코인 모달 요소 확인:', {
        coinItem: coinItem ? '있음' : '없음',
        coinModal: coinModal ? '있음' : '없음',
        coinModalClose: coinModalClose ? '있음' : '없음'
    });
    
    // 코인 아이템 클릭 시 모달 열기
    if (coinItem && coinModal) {
        coinItem.addEventListener('click', function() {
            console.log('💰 코인 모달 열기');
            coinModal.style.display = 'block';
            document.body.style.overflow = 'hidden';
            // 코인 잔액 업데이트
            updateCoinBalance();
            // 코인 내역 초기 로드 (5개만)
            console.log('📝 코인 내역 로드 시작');
            loadCoinHistory(false).catch(error => {
                console.error('❌ 코인 내역 로드 실패:', error);
            });
        });
        console.log('✅ 코인 모달 이벤트 리스너 설정 완료');
    } else {
        console.warn('⚠️ 코인 모달 요소를 찾을 수 없습니다:', {
            coinItem: coinItem ? '있음' : '없음',
            coinModal: coinModal ? '있음' : '없음',
            page: window.location.pathname
        });
        
        // 요소가 없으면 나중에 다시 시도 (동적 로드 대응)
        setTimeout(() => {
            const retryCoinItem = document.getElementById('coinItem');
            const retryCoinModal = document.getElementById('coinModal');
            if (retryCoinItem && retryCoinModal) {
                console.log('✅ 코인 모달 요소 재확인 성공, 이벤트 리스너 설정');
                retryCoinItem.addEventListener('click', function() {
                    console.log('💰 코인 모달 열기 (재시도)');
                    retryCoinModal.style.display = 'block';
                    document.body.style.overflow = 'hidden';
                    updateCoinBalance();
                    loadCoinHistory(false).catch(error => {
                        console.error('❌ 코인 내역 로드 실패:', error);
                    });
                });
            }
        }, 1000);
    }
    
    // 모달 닫기
    if (coinModalClose && coinModal) {
        coinModalClose.addEventListener('click', function() {
            coinModal.style.display = 'none';
            document.body.style.overflow = 'auto';
        });
    }
    
    // 모달 외부 클릭 시 닫기
    if (coinModal) {
        window.addEventListener('click', function(e) {
            if (e.target === coinModal) {
                coinModal.style.display = 'none';
                document.body.style.overflow = 'auto';
            }
        });
    }
}

// 코인 잔액 업데이트 (비동기, 블로킹하지 않음)
async function updateCoinBalance() {
    // 라우터 네비게이션 중이면 업데이트 건너뛰기
    if (window.isRouterNavigation) {
        return;
    }
    
    // DOM이 아직 로드되지 않았으면 즉시 반환 (상단바 표시 차단 방지)
    const pointsDisplay = document.getElementById('pointsDisplay');
    
    // 코인 표시가 잠겨있으면 업데이트 건너뛰기
    if (pointsDisplay && pointsDisplay.getAttribute('data-router-locked') === 'true') {
        return;
    }
    
    const coinsValue = pointsDisplay ? pointsDisplay.querySelector('.point-value') : null;
    if (!pointsDisplay || !coinsValue) {
        return;
    }
    
    // currentUser가 없으면 firebaseAuth.currentUser 확인
    let userId = null;
    if (currentUser && currentUser.uid) {
        userId = currentUser.uid;
    } else if (firebaseAuth && firebaseAuth.currentUser) {
        userId = firebaseAuth.currentUser.uid;
    }
    
    if (!userId) {
        console.log('ℹ️ 코인 잔액 업데이트: 로그인된 사용자가 없습니다.');
        return;
    }
    
    try {
        // Firestore에서 사용자 코인 정보 가져오기
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
            const userData = userDoc.data();
            const coins = userData.coins || 0;
            
            // 코인 표시 업데이트
            const coinsValue = document.getElementById('coinsValue');
            const coinModalBalance = document.getElementById('coinModalBalance');
            
            const coinsFormatted = coins.toLocaleString();
            
            // 이미 같은 값이면 업데이트하지 않음 (깜빡임 방지)
            if (coinsValue && coinsValue.textContent === coinsFormatted) {
                // 값이 같으면 업데이트하지 않지만, localStorage는 업데이트
                try {
                    localStorage.setItem('lastCoinBalance', coins.toString());
                } catch (e) {
                    // localStorage 저장 실패 시 무시
                }
                return;
            }
            
            if (coinsValue) coinsValue.textContent = coinsFormatted;
            if (coinModalBalance) coinModalBalance.textContent = coinsFormatted;
            
            // localStorage에 저장 (다음 로드 시 빠른 표시)
            try {
                localStorage.setItem('lastCoinBalance', coins.toString());
            } catch (e) {
                // localStorage 저장 실패 시 무시
            }
            
            console.log('✅ 코인 잔액 업데이트 완료:', { userId, coins });
        } else {
            console.warn('⚠️ 코인 잔액 업데이트: 사용자 문서가 없습니다.', userId);
        }
    } catch (error) {
        console.error('❌ 코인 잔액 업데이트 오류:', error);
    }
}

// 전역 함수로 등록
window.updateCoinBalance = updateCoinBalance;

// 코인 내역 페이지네이션 변수
let coinHistoryLastDoc = null;
let coinHistoryHasMore = true;
let coinHistoryLoading = false;
let coinHistoryCache = null; // 캐시: 최근 로드한 데이터
let coinHistoryCacheTime = 0; // 캐시 시간
const COIN_HISTORY_CACHE_DURATION = 30000; // 30초 캐시

// 코인 내역 로드 (페이지네이션)
async function loadCoinHistory(loadMore = false) {
    console.log('🔄 loadCoinHistory 호출:', { loadMore, currentUser: currentUser ? currentUser.uid : null });
    
    if (!currentUser) {
        console.error('❌ 코인 내역 로드: currentUser가 없습니다.');
        return;
    }
    
    const coinHistoryList = document.getElementById('coinHistoryList');
    if (!coinHistoryList) {
        console.error('❌ 코인 내역 로드: coinHistoryList 요소를 찾을 수 없습니다.');
        return;
    }
    
    // 로딩 중이면 중복 실행 방지
    if (coinHistoryLoading) {
        console.log('ℹ️ 코인 내역 로드: 이미 로딩 중입니다.');
        return;
    }
    
    // 초기 로드 시 캐시 확인 (30초 이내면 캐시 사용 - 서버 비용 절감)
    if (!loadMore) {
        const now = Date.now();
        // 캐시가 있고, 캐시 시간이 설정되어 있고, 30초 이내면 캐시 사용
        if (coinHistoryCache && coinHistoryCacheTime > 0 && (now - coinHistoryCacheTime) < COIN_HISTORY_CACHE_DURATION) {
            coinHistoryList.innerHTML = coinHistoryCache;
            setupCoinHistoryScroll();
            return; // 캐시 사용, 서버 요청 없음
        }
        
        // 초기화
        coinHistoryLastDoc = null;
        coinHistoryHasMore = true;
        coinHistoryList.innerHTML = '';
    }
    
    // 더 이상 로드할 데이터가 없으면 중단 (추가 로드 시에만)
    if (!coinHistoryHasMore && loadMore) return;
    
    coinHistoryLoading = true;
    
    try {
        if (!db) {
            throw new Error('Firestore가 초기화되지 않았습니다.');
        }
        
        if (!currentUser.uid) {
            throw new Error('사용자 UID가 없습니다.');
        }
        
        console.log('📝 코인 내역 쿼리 준비:', {
            userId: currentUser.uid,
            loadMore: loadMore,
            hasLastDoc: coinHistoryLastDoc !== null
        });
        
        // Firestore에서 코인 내역 가져오기 (최신순 정렬, 초기: 5개, 추가: 10개씩)
        const limit = loadMore ? 10 : 5;
        let historyRef = db.collection('coinHistory')
            .where('userId', '==', currentUser.uid)
            .orderBy('timestamp', 'desc') // 최신순 정렬
            .limit(limit + 1); // 하나 더 가져와서 다음 페이지 존재 여부 확인
        
        // 추가 로드 시 마지막 문서부터 시작
        if (loadMore && coinHistoryLastDoc) {
            historyRef = historyRef.startAfter(coinHistoryLastDoc);
        }
        
        console.log('📤 Firestore 쿼리 실행 중...');
        const snapshot = await historyRef.get();
        console.log('✅ Firestore 쿼리 완료:', {
            size: snapshot.size,
            limit: limit
        });
        
        // 다음 페이지 존재 여부 확인
        const hasMore = snapshot.size > limit;
        if (hasMore) {
            // 마지막 문서 저장 (다음 로드용)
            coinHistoryLastDoc = snapshot.docs[limit - 1];
        } else {
            coinHistoryHasMore = false;
        }
        
        // 실제 표시할 문서만 처리
        const docsToShow = snapshot.docs.slice(0, limit);
        
        if (docsToShow.length === 0 && !loadMore) {
            // 초기 로드 시 데이터가 없으면
            coinHistoryList.innerHTML = `
                <div class="coin-history-empty">
                    <p>아직 코인 내역이 없습니다.</p>
                    <p class="coin-history-hint">미션을 완료하거나 출석체크를 하면 코인을 획득할 수 있습니다.</p>
                </div>
            `;
            coinHistoryLoading = false;
            return;
        }
        
        let historyHTML = '';
        docsToShow.forEach(doc => {
            const history = doc.data();
            const date = history.timestamp.toDate();
            const dateStr = date.toLocaleDateString('ko-KR', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
            
            const amountClass = history.amount > 0 ? 'positive' : 'negative';
            const amountSign = history.amount > 0 ? '+' : '';
            
            historyHTML += `
                <div class="coin-history-item">
                    <div class="coin-history-info">
                        <div class="coin-history-type">${history.type}</div>
                        <div class="coin-history-date">${dateStr}</div>
                    </div>
                    <div class="coin-history-amount ${amountClass}">
                        ${amountSign}${history.amount.toLocaleString()} 코인
                    </div>
                </div>
            `;
        });
        
        // 기존 내용에 추가 (추가 로드) 또는 교체 (초기 로드)
        if (loadMore) {
            coinHistoryList.insertAdjacentHTML('beforeend', historyHTML);
        } else {
            coinHistoryList.innerHTML = historyHTML;
            // 초기 로드 시 캐시 저장
            coinHistoryCache = historyHTML;
            coinHistoryCacheTime = Date.now();
        }
        
        // 더 불러올 데이터가 있으면 스크롤 감지 활성화
        if (coinHistoryHasMore) {
            setupCoinHistoryScroll();
        }
        
        console.log('✅ 코인 내역 로드 완료:', {
            loaded: docsToShow.length,
            hasMore: coinHistoryHasMore,
            totalItems: coinHistoryList.children.length
        });
    } catch (error) {
        console.error('❌ 코인 내역 로드 오류:', error);
        console.error('오류 상세:', {
            message: error.message,
            code: error.code,
            stack: error.stack,
            currentUser: currentUser ? currentUser.uid : null,
            db: db ? '초기화됨' : '초기화 안 됨',
            loadMore: loadMore
        });
        
        if (!loadMore) {
            coinHistoryList.innerHTML = `
                <div class="coin-history-empty">
                    <p>코인 내역을 불러오는 중 오류가 발생했습니다.</p>
                    <p class="coin-history-hint" style="color: #f44336; margin-top: 0.5rem; font-size: 0.85rem;">오류: ${error.message}</p>
                    <p class="coin-history-hint" style="margin-top: 0.5rem; font-size: 0.85rem;">브라우저 콘솔(F12)을 확인하세요.</p>
                </div>
            `;
        }
    } finally {
        coinHistoryLoading = false;
        console.log('🏁 코인 내역 로드 프로세스 종료');
    }
}

// 코인 내역 스크롤 감지 설정
function setupCoinHistoryScroll() {
    const coinHistoryList = document.getElementById('coinHistoryList');
    if (!coinHistoryList) return;
    
    // 기존 스크롤 리스너 제거 (중복 방지)
    if (coinHistoryList._scrollHandler) {
        coinHistoryList.removeEventListener('scroll', coinHistoryList._scrollHandler);
    }
    
    let scrollTimeout = null;
    
    // 스크롤 이벤트 핸들러 (디바운싱 적용 - 서버 비용 절감)
    coinHistoryList._scrollHandler = function() {
        // 디바운싱: 100ms마다 한 번만 체크 (불필요한 체크 방지)
        if (scrollTimeout) {
            clearTimeout(scrollTimeout);
        }
        
        scrollTimeout = setTimeout(() => {
            // 스크롤이 하단 근처에 도달했는지 확인 (하단 150px 이내)
            const scrollBottom = coinHistoryList.scrollHeight - coinHistoryList.scrollTop - coinHistoryList.clientHeight;
            
            if (scrollBottom < 150 && coinHistoryHasMore && !coinHistoryLoading) {
                // 추가 데이터 로드
                loadCoinHistory(true);
            }
        }, 100);
    };
    
    coinHistoryList.addEventListener('scroll', coinHistoryList._scrollHandler);
}

// 인기작품 선정 체크 및 코인 지급 (전역 함수)
window.checkAndRewardPopularPost = async function(postId, postData = null) {
    try {
        // 이미 처리 중이면 중복 실행 방지
        if (window.processingPopularPost && window.processingPopularPost[postId]) {
            console.log('ℹ️ 이미 처리 중인 게시물:', postId);
            return;
        }
        
        if (!window.processingPopularPost) {
            window.processingPopularPost = {};
        }
        window.processingPopularPost[postId] = true;
        
        console.log('🔍 인기작품 선정 체크 시작 (전역 함수)...', {
            postId: postId
        });
        
        // db가 없으면 대기
        if (!db) {
            await waitForFirebase();
        }
        
        // 게시물 다시 가져와서 최신 상태 확인
        const updatedPost = postData || await window.dataManager.getPost(postId);
        if (!updatedPost) {
            console.error('❌ 게시물을 찾을 수 없습니다:', postId);
            return;
        }
        
        const currentLikes = updatedPost.likes ? updatedPost.likes.length : 0;
        
        console.log('📊 게시물 상태 확인:', {
            currentLikes: currentLikes,
            isPopular: updatedPost.isPopular,
            postId: postId
        });
        
        // 좋아요가 2개 이상이고, 아직 인기작품으로 선정되지 않은 경우
        if (currentLikes >= 2 && !updatedPost.isPopular) {
            console.log('🎉 인기작품 선정! 코인 지급 시작...', {
                postId: postId,
                author: updatedPost.author,
                likers: updatedPost.likes
            });
            
            // 게시물에 isPopular 플래그 설정
            await db.collection('posts').doc(postId).update({
                isPopular: true,
                popularDate: firebase.firestore.FieldValue.serverTimestamp()
            });
            console.log('✅ isPopular 플래그 설정 완료');
            
            // 좋아요를 누른 사람들에게 3코인씩 지급 (글쓴이 본인 제외)
            const likers = updatedPost.likes || [];
            const authorName = updatedPost.author;
            console.log('💰 좋아요 누른 사용자들에게 코인 지급 시작...', {
                likers: likers,
                author: authorName,
                note: '글쓴이 본인은 제외됩니다'
            });
            
            for (const likerUsername of likers) {
                // 글쓴이 본인은 좋아요 보상에서 제외 (글쓴이는 10코인만 받음)
                if (likerUsername === authorName) {
                    console.log(`ℹ️ 글쓴이 본인 (${likerUsername})은 좋아요 보상에서 제외됩니다. 글쓴이 보상(10코인)만 받습니다.`);
                    continue;
                }
                
                try {
                    console.log(`🔍 사용자 UID 찾기: ${likerUsername}`);
                    const likerUid = await window.dataManager.getUserIdByUsername(likerUsername);
                    if (likerUid) {
                        console.log(`✅ UID 찾음: ${likerUid}, 코인 지급 시작...`);
                        await window.dataManager.addCoins(
                            likerUid,
                            3,
                            '인기작품 선정 보상 (좋아요)',
                            postId
                        );
                        console.log(`✅ 코인 지급 완료: ${likerUsername} (${likerUid})`);
                    } else {
                        console.warn(`⚠️ UID를 찾을 수 없음: ${likerUsername}`);
                    }
                } catch (error) {
                    console.error(`❌ 좋아요 누른 사용자 코인 지급 오류 (${likerUsername}):`, error);
                }
            }
            
            // 글쓴이에게 10코인 지급 (반드시 지급)
            console.log('💰 글쓴이에게 코인 지급 시작...', {
                author: updatedPost.author,
                authorUid: updatedPost.authorUid,
                postId: postId
            });
            
            let authorUidForCoins = null;
            
            // 방법 1: 게시물에 authorUid가 저장되어 있으면 사용
            if (updatedPost.authorUid) {
                authorUidForCoins = updatedPost.authorUid;
                console.log(`✅ authorUid 사용: ${authorUidForCoins}`);
            } else {
                // 방법 2: username으로 찾기
                console.log(`⚠️ authorUid 없음, username으로 찾기: ${updatedPost.author}`);
                try {
                    authorUidForCoins = await window.dataManager.getUserIdByUsername(updatedPost.author);
                    if (authorUidForCoins) {
                        console.log(`✅ UID 찾음: ${authorUidForCoins}`);
                    } else {
                        console.warn(`⚠️ username으로 UID를 찾을 수 없음: ${updatedPost.author}`);
                    }
                } catch (error) {
                    console.error(`❌ getUserIdByUsername 오류:`, error);
                }
            }
            
            // 방법 3: 게시물 문서에서 직접 authorUid 가져오기 (최후의 수단)
            if (!authorUidForCoins) {
                try {
                    console.log(`⚠️ 다른 방법으로 UID 찾기 시도: 게시물 문서 직접 조회`);
                    const postDoc = await db.collection('posts').doc(postId).get();
                    if (postDoc.exists) {
                        const postData = postDoc.data();
                        if (postData.authorUid) {
                            authorUidForCoins = postData.authorUid;
                            console.log(`✅ 게시물 문서에서 authorUid 찾음: ${authorUidForCoins}`);
                        }
                    }
                } catch (error) {
                    console.error(`❌ 게시물 문서 조회 오류:`, error);
                }
            }
            
            // 글쓴이에게 코인 지급 (UID를 찾았으면 반드시 지급)
            if (authorUidForCoins) {
                try {
                    console.log(`💰 글쓴이 코인 지급 시작: ${authorUidForCoins}, 10코인`);
                    const result = await window.dataManager.addCoins(
                        authorUidForCoins,
                        10,
                        '인기작품 선정 보상 (작성자)',
                        postId
                    );
                    console.log(`✅ 글쓴이 코인 지급 완료: ${authorUidForCoins} (${updatedPost.author})`, result);
                } catch (error) {
                    console.error(`❌ 글쓴이 코인 지급 오류:`, error);
                    console.error('오류 상세:', {
                        authorUid: authorUidForCoins,
                        author: updatedPost.author,
                        postId: postId,
                        error: error.message,
                        code: error.code,
                        stack: error.stack
                    });
                }
            } else {
                console.error(`❌ 글쓴이 UID를 찾을 수 없어 코인을 지급할 수 없음: ${updatedPost.author}`);
                console.error('게시물 정보:', {
                    author: updatedPost.author,
                    authorUid: updatedPost.authorUid,
                    postId: postId,
                    updatedPostKeys: Object.keys(updatedPost)
                });
            }
            
            console.log('✅ 인기작품 코인 지급 완료');
        } else {
            console.log('ℹ️ 인기작품 선정 조건 불만족:', {
                currentLikes: currentLikes,
                isPopular: updatedPost.isPopular,
                needLikes: currentLikes >= 2,
                needNotPopular: !updatedPost.isPopular
            });
        }
        
        // 처리 완료 표시 제거 (5초 후)
        setTimeout(() => {
            if (window.processingPopularPost) {
                delete window.processingPopularPost[postId];
            }
        }, 5000);
    } catch (error) {
        console.error('❌ 인기작품 코인 지급 오류 (전역 함수):', error);
        console.error('오류 상세:', {
            message: error.message,
            code: error.code,
            stack: error.stack,
            postId: postId
        });
        
        // 오류 발생 시에도 처리 완료 표시 제거
        if (window.processingPopularPost) {
            delete window.processingPopularPost[postId];
        }
    }
};

// 코인 획득 처리 (사용자가 직접 구현할 함수)
// 이 함수는 사용자가 보상 로직을 구현할 수 있도록 인터페이스만 제공합니다.
async function handleCoinEarn(action, buttonElement) {
    // TODO: 사용자가 보상 로직을 여기에 구현하세요
    // 예시:
    // - action: 'attendance', 'mission', 'ad', 'upload' 등
    // - buttonElement: 클릭된 버튼 요소
    
    console.log('코인 획득 요청:', action);
    
    // 사용자가 구현할 부분:
    // 1. 보상 금액 결정
    // 2. 중복 획득 방지 체크
    // 3. Firestore에 코인 업데이트
    // 4. 코인 내역 추가
    // 5. UI 업데이트
    
    // 예시 구조:
    /*
    if (!currentUser) {
        alert('로그인이 필요합니다.');
        return;
    }
    
    // 보상 로직 구현
    const coinAmount = getCoinAmount(action); // 사용자가 구현
    const coinType = getCoinType(action); // 사용자가 구현
    
    // 코인 추가
    await addCoins(currentUser.uid, coinAmount, coinType);
    
    // UI 업데이트
    await updateCoinBalance();
    await loadCoinHistory();
    */
}

// 업로드 모달 설정 (전역 함수로 export)
window.setupUploadModal = function() {
    const uploadBtn = document.getElementById('uploadBtn');
    const uploadModal = document.getElementById('uploadModal');
    const closeBtn = uploadModal ? uploadModal.querySelector('.close') : null;
    const uploadForm = document.getElementById('uploadForm');
    
    // 업로드 버튼 클릭
    if (uploadBtn) {
        uploadBtn.onclick = function() {
            if (!currentUser) {
                alert('로그인이 필요합니다.');
                window.location.href = 'login.html';
                return;
            }
            if (uploadModal) {
                uploadModal.style.display = 'block';
            }
        };
    }
    
    // 모달 닫기
    if (closeBtn) {
        closeBtn.onclick = function() {
            if (uploadModal) {
                uploadModal.style.display = 'none';
                resetUploadForm();
            }
        };
    }
    
    // 모달 외부 클릭 시 닫기
    if (uploadModal) {
        window.onclick = function(e) {
            if (e.target === uploadModal) {
                uploadModal.style.display = 'none';
                resetUploadForm();
            }
        };
    }
    
    // 작품 유형 선택에 따른 UI 변경
    const postTypeInputs = document.querySelectorAll('input[name="postType"]');
    postTypeInputs.forEach(input => {
        input.onchange = function() {
            const originalImageSection = document.getElementById('originalImageSection');
            if (this.value === 'recreation') {
                if (originalImageSection) {
                    originalImageSection.style.display = 'block';
                    originalImageSection.querySelector('#originalImageInput').required = true;
                }
            } else {
                if (originalImageSection) {
                    originalImageSection.style.display = 'none';
                    originalImageSection.querySelector('#originalImageInput').required = false;
                }
            }
        };
    });
    
    // 이미지 미리보기
    const imageInput = document.getElementById('imageInput');
    if (imageInput) {
        imageInput.onchange = function(e) {
            previewImage(e.target.files[0], 'imagePreview');
        };
    }
    
    const originalImageInput = document.getElementById('originalImageInput');
    if (originalImageInput) {
        originalImageInput.onchange = function(e) {
            previewImage(e.target.files[0], 'originalImagePreview');
        };
    }
    
    // 폼 제출
    if (uploadForm) {
        uploadForm.onsubmit = async function(e) {
            e.preventDefault();
            await handleUpload();
        };
    }
};

// 이미지 미리보기
function previewImage(file, previewId) {
    const preview = document.getElementById(previewId);
    if (!preview || !file) return;
    
    // 해당하는 라벨 찾기
    let uploadLabel = null;
    if (previewId === 'imagePreview') {
        uploadLabel = document.querySelector('label[for="imageInput"]');
    } else if (previewId === 'originalImagePreview') {
        uploadLabel = document.querySelector('label[for="originalImageInput"]');
    }
    
    const reader = new FileReader();
    reader.onload = function(e) {
        // 미리보기 표시
        preview.innerHTML = `
            <div style="position: relative; display: inline-block; width: 100%;">
                <img src="${e.target.result}" alt="미리보기" style="max-width: 100%; max-height: 400px; border-radius: 10px; display: block; margin: 0 auto;">
                <button type="button" class="remove-image-btn" onclick="removeImage('${previewId}')" title="이미지 제거">×</button>
            </div>
        `;
        
        // 라벨 숨기기 (이미지 선택 후)
        if (uploadLabel) {
            uploadLabel.style.display = 'none';
        }
    };
    reader.readAsDataURL(file);
}

// 이미지 제거
function removeImage(previewId) {
    const preview = document.getElementById(previewId);
    if (preview) {
        preview.innerHTML = '';
    }
    
    // 라벨 다시 표시
    let uploadLabel = null;
    if (previewId === 'imagePreview') {
        const imageInput = document.getElementById('imageInput');
        if (imageInput) {
            imageInput.value = '';
            uploadLabel = document.querySelector('label[for="imageInput"]');
        }
    } else if (previewId === 'originalImagePreview') {
        const originalImageInput = document.getElementById('originalImageInput');
        if (originalImageInput) {
            originalImageInput.value = '';
            uploadLabel = document.querySelector('label[for="originalImageInput"]');
        }
    }
    
    // 라벨 다시 표시
    if (uploadLabel) {
        uploadLabel.style.display = 'block';
    }
}

// 업로드 폼 리셋
function resetUploadForm() {
    const uploadForm = document.getElementById('uploadForm');
    if (uploadForm) {
        uploadForm.reset();
    }
    
    // 미리보기 초기화
    const imagePreview = document.getElementById('imagePreview');
    const originalImagePreview = document.getElementById('originalImagePreview');
    if (imagePreview) imagePreview.innerHTML = '';
    if (originalImagePreview) originalImagePreview.innerHTML = '';
    
    // 라벨 다시 표시
    const imageLabel = document.querySelector('label[for="imageInput"]');
    const originalImageLabel = document.querySelector('label[for="originalImageInput"]');
    if (imageLabel) imageLabel.style.display = 'block';
    if (originalImageLabel) originalImageLabel.style.display = 'block';
    
    // 원본 이미지 섹션 숨기기
    const originalImageSection = document.getElementById('originalImageSection');
    if (originalImageSection) originalImageSection.style.display = 'none';
}

// 업로드 처리 중 상태 관리
let isUploading = false;

// 업로드 처리
async function handleUpload() {
    // 중복 업로드 방지
    if (isUploading) {
        alert('업로드 중입니다. 잠시만 기다려주세요.');
        return;
    }
    
    try {
        if (!currentUser) {
            alert('로그인이 필요합니다.');
            window.location.href = 'login.html';
            return;
        }
        
        const titleInput = document.getElementById('titleInput');
        const captionInput = document.getElementById('captionInput');
        const imageInput = document.getElementById('imageInput');
        const originalImageInput = document.getElementById('originalImageInput');
        const postTypeInputs = document.querySelectorAll('input[name="postType"]:checked');
        const uploadForm = document.getElementById('uploadForm');
        const submitBtn = uploadForm ? uploadForm.querySelector('button[type="submit"]') : null;
        
        // 입력값 확인
        if (!titleInput.value.trim()) {
            alert('제목을 입력해주세요.');
            return;
        }
        
        if (!imageInput.files[0]) {
            alert('이미지를 선택해주세요.');
            return;
        }
        
        if (!postTypeInputs.length) {
            alert('작품 유형을 선택해주세요.');
            return;
        }
        
        const postType = postTypeInputs[0].value;
        
        // 모작인 경우 원본 이미지 확인
        if (postType === 'recreation' && !originalImageInput.files[0]) {
            alert('원본 그림을 선택해주세요.');
            return;
        }
        
        // 업로드 시작 - 버튼 비활성화
        isUploading = true;
        if (submitBtn) {
            submitBtn.disabled = true;
            submitBtn.textContent = '업로드 중... (약 10초 소요)';
        }
        
        // 사용자 정보 가져오기 (캐시 활용, 비동기로 처리)
        let username;
        const usernamePromise = (async () => {
            try {
                const userInfo = await getUserInfo(currentUser.uid);
                if (userInfo && userInfo.name) {
                    return userInfo.name.trim();
                }
            } catch (error) {
                console.error('사용자 정보 가져오기 오류:', error);
            }
            // Fallback: displayName 또는 email 사용
            return (currentUser.displayName || currentUser.email.split('@')[0]).trim();
        })();
        
        // 이미지 업로드 (병렬 처리로 속도 향상)
        // 압축된 이미지와 원본 이미지를 모두 저장 (비용 절감을 위해 기본은 압축된 이미지 사용)
        const imagePath = `posts/${currentUser.uid}/${Date.now()}`;
        const uploadPromises = [
            window.storageManager.uploadImage(imageInput.files[0], imagePath, true, true) // 압축 활성화 + 원본 저장
        ];
        
        let originalImageUrl = null;
        let originalImageOriginalUrl = null;
        
        if (postType === 'recreation' && originalImageInput.files[0]) {
            const originalImagePath = `posts/${currentUser.uid}/original_${Date.now()}`;
            uploadPromises.push(
                window.storageManager.uploadImage(originalImageInput.files[0], originalImagePath, true, true) // 압축 활성화 + 원본 저장
            );
        }
        
        // 이미지들을 병렬로 업로드
        const uploadResults = await Promise.all(uploadPromises);
        
        // 업로드 결과 처리 (객체일 수도 있고 문자열일 수도 있음)
        let imageUrl = uploadResults[0];
        if (typeof imageUrl === 'object' && imageUrl.compressed) {
            // 원본도 저장된 경우
            imageUrl = imageUrl.compressed; // 기본적으로 압축된 이미지 사용
            originalImageUrl = imageUrl.original || null;
        }
        
        if (uploadResults[1]) {
            const originalImageResult = uploadResults[1];
            if (typeof originalImageResult === 'object' && originalImageResult.compressed) {
                originalImageUrl = originalImageResult.compressed;
                originalImageOriginalUrl = originalImageResult.original || null;
            } else {
                originalImageUrl = originalImageResult;
            }
        }
        
        // 사용자 이름 가져오기 (이미지 업로드와 병렬 처리)
        username = await usernamePromise;
        
        // 태그 처리 (최대 5개)
        const tagsInput = document.getElementById('tagsInput');
        let tags = [];
        if (tagsInput && tagsInput.value.trim()) {
            tags = tagsInput.value
                .split(',')
                .map(tag => tag.trim())
                .filter(tag => tag.length > 0)
                .slice(0, 5); // 최대 5개만
        }
        
        // 게시물 데이터 생성
        // image: 압축된 이미지 URL (기본 표시용)
        // originalImageUrl: 원본 이미지 URL (원본 보기 버튼 클릭 시 사용)
        const postData = {
            title: titleInput.value.trim(),
            caption: captionInput.value.trim(),
            image: imageUrl, // 압축된 이미지 (기본 표시)
            originalImageUrl: originalImageUrl || null, // 원본 이미지 URL (원본 보기용)
            originalImage: originalImageUrl, // 모작의 원본 그림 (기존 호환성 유지)
            originalImageOriginalUrl: originalImageOriginalUrl || null, // 모작 원본의 원본 이미지
            author: username,
            authorUid: currentUser.uid, // 알림 기능을 위해 UID도 저장
            type: postType,
            tags: tags, // 태그 배열 추가
            likes: [],
            comments: [],
            recreations: [],
            views: 0
        };
        
        // Firestore에 저장
        await window.dataManager.createPost(postData);
        
        // 사용자 게시물 수 업데이트 (비동기로 처리, 블로킹하지 않음)
        window.dataManager.updateUserPostCount(username).catch(error => {
            console.error('게시물 수 업데이트 오류:', error);
        });
        
        // 모달 닫기 및 폼 리셋
        const uploadModal = document.getElementById('uploadModal');
        if (uploadModal) {
            uploadModal.style.display = 'none';
        }
        resetUploadForm();
        
        // 캐시 무효화 (새 게시물이 추가되었으므로)
        if (window.dataManager && window.dataManager.clearPostsCache) {
            window.dataManager.clearPostsCache();
        }
        
        // 피드 새로고침 (비동기로 처리, 사용자는 즉시 알림 받음)
        loadFeed().catch(error => {
            console.error('피드 새로고침 오류:', error);
        });
    } catch (error) {
        console.error('업로드 오류:', error);
        alert('업로드 중 오류가 발생했습니다: ' + error.message);
    } finally {
        // 업로드 완료 - 버튼 활성화
        isUploading = false;
        const uploadForm = document.getElementById('uploadForm');
        const submitBtn = uploadForm ? uploadForm.querySelector('button[type="submit"]') : null;
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.textContent = '업로드';
        }
    }
}

// 피드 로드 (로그인하지 않은 사용자도 볼 수 있음)
async function loadFeed() {
    const feedContainer = document.getElementById('feedContainer');
    if (!feedContainer) return;
    
    try {
        feedContainer.innerHTML = '<p style="text-align: center; padding: 2rem;">로딩 중...</p>';
        
        // 로그인 여부와 관계없이 게시물 가져오기
        const posts = await window.dataManager.getAllPosts();
        
        if (posts.length === 0) {
            feedContainer.innerHTML = '<div class="no-posts"><p>아직 게시물이 없습니다.</p></div>';
            return;
        }
        
        // 성능 최적화: 사용자 정보를 병렬로 가져오기 (게시물 로딩과 독립적으로)
        let userInfoPromise = Promise.resolve(null);
        if (currentUser && currentUser.uid) {
            userInfoPromise = getUserInfo(currentUser.uid).catch(error => {
                console.error('사용자 정보 가져오기 오류:', error);
                return null;
            });
        }
        
        feedContainer.innerHTML = '';
        
        // 현재 사용자 정보 가져오기 (없어도 작동)
        const userInfo = await userInfoPromise;
        const currentUsername = userInfo ? userInfo.name : (currentUser ? (currentUser.displayName || currentUser.email?.split('@')[0]) : null);
        
        // 성능 최적화: DocumentFragment 사용하여 DOM 조작 최소화
        const fragment = document.createDocumentFragment();
        posts.forEach(post => {
            const postCard = createPostCard(post, currentUsername);
            fragment.appendChild(postCard);
        });
        feedContainer.appendChild(fragment);
    } catch (error) {
        console.error('피드 로드 오류:', error);
        feedContainer.innerHTML = '<div class="no-posts"><p>피드를 불러오는 중 오류가 발생했습니다.</p></div>';
    }
}

// 본 게시물 목록 가져오기 (로컬 스토리지 - 사용자별로 분리)
function getViewedPosts() {
    try {
        // 현재 사용자 ID 가져오기
        const userId = getCurrentUserId();
        if (!userId) {
            // 로그인하지 않은 사용자는 본 게시물 정보 없음
            return [];
        }
        
        const key = `viewedPosts_${userId}`;
        const viewed = localStorage.getItem(key);
        return viewed ? JSON.parse(viewed) : [];
    } catch (error) {
        console.error('본 게시물 목록 가져오기 오류:', error);
        return [];
    }
}

// 본 게시물로 표시 (로컬 스토리지 - 사용자별로 분리)
function markAsViewed(postId) {
    try {
        // 현재 사용자 ID 가져오기
        const userId = getCurrentUserId();
        if (!userId) {
            // 로그인하지 않은 사용자는 본 게시물 정보 저장 안 함
            return;
        }
        
        const key = `viewedPosts_${userId}`;
        const viewed = getViewedPosts();
        if (!viewed.includes(postId)) {
            viewed.push(postId);
            // 최대 1000개까지만 저장 (메모리 절약)
            if (viewed.length > 1000) {
                viewed.shift();
            }
            localStorage.setItem(key, JSON.stringify(viewed));
        }
    } catch (error) {
        console.error('본 게시물 표시 오류:', error);
    }
}

// 현재 사용자 ID 가져오기
function getCurrentUserId() {
    try {
        if (currentUser && currentUser.uid) {
            return currentUser.uid;
        }
        if (firebaseAuth && firebaseAuth.currentUser) {
            return firebaseAuth.currentUser.uid;
        }
        return null;
    } catch (error) {
        return null;
    }
}

// 현재 사용자의 본 게시물 정보 삭제 (로그아웃 시)
function clearViewedPosts() {
    try {
        const userId = getCurrentUserId();
        if (userId) {
            const key = `viewedPosts_${userId}`;
            localStorage.removeItem(key);
        }
        // 이전 형식의 데이터도 삭제 (마이그레이션)
        localStorage.removeItem('viewedPosts');
    } catch (error) {
        console.error('본 게시물 정보 삭제 오류:', error);
    }
}

// 게시물 카드 생성 (로그인하지 않은 사용자도 볼 수 있음)
function createPostCard(post, currentUsername) {
    const postCard = document.createElement('div');
    const postCardClass = 'post-card';
    
    // 본 게시물인지 확인
    const viewedPosts = getViewedPosts();
    const isViewed = viewedPosts.includes(post.id);
    
    // 본 게시물이면 클래스 추가
    postCard.className = isViewed ? `${postCardClass} viewed-post` : postCardClass;
    
    const isOwner = currentUsername && post.author === currentUsername;
    const likesCount = post.likes ? post.likes.length : 0;
    // 댓글 수 계산 (대댓글 포함)
    function countReplies(replies) {
        if (!replies || !Array.isArray(replies)) return 0;
        let count = replies.length;
        replies.forEach(reply => {
            if (reply.replies && Array.isArray(reply.replies)) {
                count += countReplies(reply.replies);
            }
        });
        return count;
    }
    
    let commentsCount = 0;
    if (post.comments && Array.isArray(post.comments)) {
        commentsCount = post.comments.length;
        post.comments.forEach(comment => {
            if (comment.replies && Array.isArray(comment.replies)) {
                commentsCount += countReplies(comment.replies);
            }
        });
    }
    // 날짜 파싱 (모바일 및 PC 호환성 개선 - 더 강력한 파싱)
    let postDate;
    try {
        if (post.date) {
            // 1. Firestore Timestamp 객체인 경우 (toDate 메서드가 있는 경우)
            if (post.date && typeof post.date === 'object' && typeof post.date.toDate === 'function') {
                try {
                    postDate = post.date.toDate();
                    if (isNaN(postDate.getTime())) {
                        throw new Error('toDate() 결과가 유효하지 않음');
                    }
                } catch (e) {
                    // toDate() 실패 시 다른 방법 시도
                    if (post.date.seconds !== undefined) {
                        postDate = new Date(post.date.seconds * 1000 + (post.date.nanoseconds || 0) / 1000000);
                    } else {
                        throw e;
                    }
                }
            }
            // 2. seconds와 nanoseconds 속성이 있는 경우 (직렬화된 Timestamp)
            else if (post.date && typeof post.date === 'object' && typeof post.date.seconds === 'number') {
                const seconds = post.date.seconds;
                const nanoseconds = post.date.nanoseconds || 0;
                postDate = new Date(seconds * 1000 + nanoseconds / 1000000);
            }
            // 3. 일반 Date 객체인 경우
            else if (post.date instanceof Date) {
                postDate = post.date;
            }
            // 4. 숫자 타임스탬프인 경우 (밀리초)
            else if (typeof post.date === 'number' && !isNaN(post.date)) {
                // 초 단위인지 밀리초 단위인지 확인 (일반적으로 10자리면 초, 13자리면 밀리초)
                if (post.date < 10000000000) {
                    // 초 단위로 보임
                    postDate = new Date(post.date * 1000);
                } else {
                    // 밀리초 단위
                    postDate = new Date(post.date);
                }
            }
            // 5. 문자열인 경우
            else if (typeof post.date === 'string') {
                // ISO 문자열 시도
                postDate = new Date(post.date);
                // 실패하면 다른 형식 시도
                if (isNaN(postDate.getTime())) {
                    // 숫자 문자열인 경우
                    const numDate = Number(post.date);
                    if (!isNaN(numDate)) {
                        if (numDate < 10000000000) {
                            postDate = new Date(numDate * 1000);
                        } else {
                            postDate = new Date(numDate);
                        }
                    } else {
                        throw new Error('문자열 날짜 파싱 실패');
                    }
                }
            }
            // 6. 그 외의 경우 - 현재 날짜 사용
            else {
                console.warn('알 수 없는 날짜 형식:', typeof post.date, post.date);
                postDate = new Date();
            }
        } else {
            // post.date가 없는 경우 - 현재 날짜 사용
            postDate = new Date();
        }

        // 최종 유효성 검사
        if (!postDate || !(postDate instanceof Date) || isNaN(postDate.getTime())) {
            console.warn('유효하지 않은 날짜 파싱 결과:', post.date, '->', postDate);
            postDate = new Date(); // 폴백: 현재 날짜
        }
    } catch (error) {
        console.error('날짜 파싱 오류:', error, 'post.date:', post.date, '타입:', typeof post.date);
        postDate = new Date(); // 폴백: 현재 날짜
    }
    
    // 날짜 포맷팅 함수 (모바일 및 PC 호환성 - 더 안전한 버전)
    function formatDate(date) {
        try {
            // 날짜 객체 유효성 검사
            if (!date) {
                console.warn('날짜 객체가 없음');
                date = new Date();
            }
            
            // Date 객체가 아니거나 유효하지 않은 경우
            if (!(date instanceof Date)) {
                console.warn('Date 객체가 아님:', typeof date, date);
                date = new Date();
            }
            
            // 유효한 날짜인지 확인
            if (isNaN(date.getTime())) {
                console.warn('유효하지 않은 날짜:', date);
                date = new Date();
            }
            
            // 날짜 포맷팅
            const year = date.getFullYear();
            const month = date.getMonth() + 1;
            const day = date.getDate();
            
            // 숫자 검증
            if (isNaN(year) || isNaN(month) || isNaN(day)) {
                console.warn('날짜 구성 요소가 유효하지 않음:', { year, month, day });
                const now = new Date();
                return `${now.getFullYear()}.${String(now.getMonth() + 1).padStart(2, '0')}.${String(now.getDate()).padStart(2, '0')}`;
            }
            
            // 문자열로 변환 및 포맷팅
            const monthStr = String(month).padStart(2, '0');
            const dayStr = String(day).padStart(2, '0');
            
            return `${year}.${monthStr}.${dayStr}`;
        } catch (error) {
            console.error('날짜 포맷팅 오류:', error, date);
            // 폴백: 현재 날짜 사용
            try {
                const now = new Date();
                const year = now.getFullYear();
                const month = String(now.getMonth() + 1).padStart(2, '0');
                const day = String(now.getDate()).padStart(2, '0');
                return `${year}.${month}.${day}`;
            } catch (fallbackError) {
                console.error('폴백 날짜 포맷팅도 실패:', fallbackError);
                return '날짜 없음';
            }
        }
    }
    
    // 날짜 문자열 미리 생성 (템플릿 리터럴에서 안전하게 사용)
    let formattedDate;
    try {
        formattedDate = formatDate(postDate);
        // 최종 검증
        if (!formattedDate || formattedDate === 'Invalid Date' || formattedDate.includes('Invalid')) {
            console.warn('포맷팅된 날짜가 유효하지 않음:', formattedDate);
            formattedDate = formatDate(new Date());
        }
    } catch (error) {
        console.error('날짜 포맷팅 중 오류:', error);
        formattedDate = formatDate(new Date());
    }
    
    const isPopular = likesCount >= 2; // 추천수 2 이상이면 인기 작품
    
    // 클릭 이벤트를 카드 전체에 적용
    postCard.onclick = function(e) {
        // 삭제 버튼 클릭 시에는 상세 페이지로 이동하지 않음
        if (!e.target.classList.contains('delete-btn') && !e.target.closest('.delete-btn')) {
            // 본 게시물로 표시
            markAsViewed(post.id);
            // 게시물 상세 페이지로 이동 (라우터 사용)
            if (window.router && window.router.navigate) {
                window.router.navigate('post-detail', { id: post.id });
            } else {
                window.location.href = `post-detail.html?id=${post.id}`;
            }
        }
    };

    postCard.innerHTML = `
        <div class="post-header" style="padding: 0; border: none; margin-bottom: 0;">
            <div class="post-author" style="margin-bottom: 0.5rem;">
                <span class="author-avatar"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor" style="width: 1.5rem; height: 1.5rem;"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg></span>
                <span class="author-name">${post.author || '익명'}</span>
                ${isPopular ? '<span style="margin-left: 0.5rem;"><img src="crown.png" alt="인기작품" style="width: 20px; height: 20px; vertical-align: middle;"></span>' : ''}
            </div>
            <div class="post-header-right" style="gap: 0.5rem;">
                <span class="post-date">${formattedDate}</span>
                ${isOwner ? `<button class="delete-btn" onclick="event.stopPropagation(); deletePost('${post.id}')" title="삭제"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor" style="width: 1.2rem; height: 1.2rem; display: inline-block; vertical-align: middle;"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg></button>` : ''}
            </div>
        </div>
        <div class="post-title" style="font-size: 1.1rem; font-weight: 600; color: #333; margin: 0.5rem 0; padding: 0;">${post.title || '제목 없음'}</div>
        ${post.tags && post.tags.length > 0 ? `
            <div class="post-tags">
                ${post.tags.map(tag => `<span class="tag-badge">#${tag}</span>`).join('')}
            </div>
        ` : ''}
        <div class="post-actions" style="padding: 0; border: none; gap: 1rem; margin-top: 0.5rem;">
            <span class="like-count" style="font-size: 0.9rem; display: flex; align-items: center; gap: 0.25rem;"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="#ff6b6b" style="width: 0.9rem; height: 0.9rem;"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg> ${likesCount}</span>
            <span class="comment-count" style="font-size: 0.9rem; display: flex; align-items: center; gap: 0.25rem;"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="#667eea" style="width: 0.9rem; height: 0.9rem;"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg> ${commentsCount}</span>
            ${post.recreations && post.recreations.length > 0 ? `<span class="recreation-count" style="font-size: 0.9rem;">🎨 ${post.recreations.length}</span>` : ''}
        </div>
    `;
    
    return postCard;
}

// 게시물 삭제
async function deletePost(postId) {
    if (!currentUser) {
        alert('로그인이 필요합니다.');
        return;
    }
    
    if (!confirm('정말 삭제하시겠습니까?')) {
        return;
    }
    
    try {
        await window.dataManager.deletePost(postId);
        await loadFeed();
    } catch (error) {
        console.error('게시물 삭제 오류:', error);
        alert('게시물 삭제 중 오류가 발생했습니다: ' + error.message);
    }
}

// 전역 함수로 내보내기
window.deletePost = deletePost;
window.removeImage = removeImage;
