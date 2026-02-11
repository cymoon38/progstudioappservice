// SPA 라우터 - 상단바 고정, 콘텐츠만 교체

// 라우트 정의
const routes = {
    '/': 'index',
    '/index.html': 'index',
    'index.html': 'index',
    '/popular.html': 'popular',
    'popular.html': 'popular',
    '/mission.html': 'mission',
    'mission.html': 'mission',
    '/shop.html': 'shop',
    'shop.html': 'shop',
    '/profile.html': 'profile',
    'profile.html': 'profile',
    '/post-detail.html': 'post-detail',
    'post-detail.html': 'post-detail'
};

// 현재 라우트
let currentRoute = null;
let currentParams = {};
let isNavigating = false;

// 라우트 변경 함수 (파라미터 지원)
async function navigateTo(route, params = {}) {
    // post-detail의 경우 id가 같으면 무시
    if (route === 'post-detail' && currentRoute === route && currentParams && currentParams.id === params.id) {
        return;
    }
    
    // 이미 해당 라우트이면 무시
    if (currentRoute === route && JSON.stringify(currentParams) === JSON.stringify(params)) {
        return;
    }
    
    if (isNavigating) {
        return;
    }

    isNavigating = true;
    currentRoute = route;
    currentParams = params;
    
    // 라우터 네비게이션 플래그 설정 (네비게이션 업데이트 방지)
    // 콘텐츠 로드 전에 설정하여 모든 네비게이션 업데이트 차단
    // 모든 페이지 전환에서 네비게이션을 고정하기 위해 즉시 설정
    window.isRouterNavigation = true;
    
    // 네비게이션 요소를 고정하여 변경 방지
    const profileDropdown = document.getElementById('profileDropdown');
    const notificationWrapper = document.getElementById('notificationWrapper');
    const pointsDisplay = document.getElementById('pointsDisplay');
    const loginLink = document.getElementById('loginLink');
    
    // 현재 상태를 저장하여 변경되지 않도록 보호
    if (profileDropdown) {
        profileDropdown.setAttribute('data-router-locked', 'true');
    }
    if (notificationWrapper) {
        notificationWrapper.setAttribute('data-router-locked', 'true');
    }
    if (pointsDisplay) {
        pointsDisplay.setAttribute('data-router-locked', 'true');
    }
    if (loginLink) {
        loginLink.setAttribute('data-router-locked', 'true');
    }

    try {
        // URL 업데이트 (히스토리 API 사용, 쿼리 파라미터 포함)
        let routePath = route.startsWith('/') ? route : '/' + route;
        
        // post-detail인 경우 쿼리 파라미터 추가
        if (route === 'post-detail' && params.id) {
            routePath = `/post-detail.html?id=${params.id}`;
        } else if (route === 'profile') {
            routePath = '/profile.html';
        }
        
        window.history.pushState({ route: route, params: params }, '', routePath);

        // 네비게이션 활성 상태 업데이트 (active 클래스만 변경)
        updateActiveNavigation(route);

        // 콘텐츠 로드 (파라미터 전달)
        await loadPageContent(route, params);
    } catch (error) {
        console.error('페이지 로드 오류:', error);
        // 오류 발생 시 전체 페이지 리로드로 폴백
        if (route === 'post-detail' && params.id) {
            window.location.href = `post-detail.html?id=${params.id}`;
        } else {
            window.location.href = routePath;
        }
    } finally {
        isNavigating = false;
        // 라우터 네비게이션 플래그 해제 (충분한 지연 후 - 모든 스크립트 실행 완료 대기)
        // post-detail 페이지의 경우 스크립트 실행이 더 오래 걸릴 수 있으므로 2초로 설정
        setTimeout(() => {
            window.isRouterNavigation = false;
            
            // 네비게이션 요소 잠금 해제
            const profileDropdown = document.getElementById('profileDropdown');
            const notificationWrapper = document.getElementById('notificationWrapper');
            const pointsDisplay = document.getElementById('pointsDisplay');
            const loginLink = document.getElementById('loginLink');
            
            if (profileDropdown) {
                profileDropdown.removeAttribute('data-router-locked');
            }
            if (notificationWrapper) {
                notificationWrapper.removeAttribute('data-router-locked');
            }
            if (pointsDisplay) {
                pointsDisplay.removeAttribute('data-router-locked');
            }
            if (loginLink) {
                loginLink.removeAttribute('data-router-locked');
            }
        }, 2000);
    }
}

// 네비게이션 활성 상태 업데이트
function updateActiveNavigation(route) {
    // 모든 네비게이션 링크에서 active 클래스 제거
    const navLinks = document.querySelectorAll('.nav-feed, .bottom-nav-item');
    navLinks.forEach(link => link.classList.remove('active'));

    // 현재 라우트에 맞는 링크 활성화
    const routeMap = {
        'index': ['index.html', '/index.html', '/'],
        'popular': ['popular.html', '/popular.html'],
        'mission': ['mission.html', '/mission.html'],
        'shop': ['shop.html', '/shop.html']
    };

    const targets = routeMap[route] || [];
    navLinks.forEach(link => {
        const href = link.getAttribute('href');
        if (href && targets.some(target => href.includes(target))) {
            link.classList.add('active');
        }
    });
}

// 페이지 콘텐츠 로드 (파라미터 지원)
async function loadPageContent(route, params = {}) {
    const container = document.querySelector('.container');
    if (!container) {
        console.error('컨테이너를 찾을 수 없습니다.');
        return;
    }

    // 로딩 표시
    const originalContent = container.innerHTML;
    container.innerHTML = '<div style="text-align: center; padding: 3rem;"><p>로딩 중...</p></div>';

    try {
        let content = '';

        switch (route) {
            case 'index':
                content = await loadIndexContent();
                break;
            case 'popular':
                content = await loadPopularContent();
                break;
            case 'mission':
                content = await loadMissionContent();
                break;
            case 'shop':
                content = await loadShopContent();
                break;
            case 'profile':
                content = await loadProfileContent();
                break;
            case 'post-detail':
                content = await loadPostDetailContent(params.id);
                break;
            default:
                throw new Error('알 수 없는 라우트: ' + route);
        }

        // 콘텐츠 교체 (라우터 네비게이션 플래그는 계속 유지)
        container.innerHTML = content;

        // 페이지별 초기화 함수 호출 (파라미터 전달)
        // 플래그는 initializePageContent 완료 후에도 유지 (스크립트 실행 대기)
        await initializePageContent(route, params);
    } catch (error) {
        console.error('콘텐츠 로드 오류:', error);
        container.innerHTML = originalContent;
        throw error;
    }
}

// 인덱스 페이지 콘텐츠 로드
async function loadIndexContent() {
    // fetch로 index.html에서 컨테이너 내용만 추출
    try {
        const response = await fetch('index.html');
        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const container = doc.querySelector('.container');
        return container ? container.innerHTML : '';
    } catch (error) {
        // fetch 실패 시 기본 HTML 반환
        return getDefaultIndexContent();
    }
}

// 인기작품 페이지 콘텐츠 로드
async function loadPopularContent() {
    try {
        const response = await fetch('popular.html');
        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const container = doc.querySelector('.container');
        
        // 스크립트 태그 추출 및 실행 (window.loadPopularPosts 함수 등록을 위해)
        const scripts = doc.querySelectorAll('script');
        scripts.forEach(script => {
            if (script.textContent && !script.src) {
                try {
                    // 인라인 스크립트 실행
                    const scriptContent = script.textContent;
                    // window.loadPopularPosts 함수만 실행
                    if (scriptContent.includes('window.loadPopularPosts')) {
                        eval(scriptContent);
                    }
                } catch (e) {
                    console.warn('인기작품 스크립트 실행 오류 (무시):', e);
                }
            }
        });
        
        return container ? container.innerHTML : '';
    } catch (error) {
        return getDefaultPopularContent();
    }
}

// 미션 페이지 콘텐츠 로드
async function loadMissionContent() {
    try {
        const response = await fetch('mission.html');
        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const container = doc.querySelector('.container');
        return container ? container.innerHTML : '';
    } catch (error) {
        return getDefaultMissionContent();
    }
}

// 상점 페이지 콘텐츠 로드
async function loadShopContent() {
    try {
        const response = await fetch('shop.html');
        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const container = doc.querySelector('.container');
        return container ? container.innerHTML : '';
    } catch (error) {
        return getDefaultShopContent();
    }
}

// 프로필 페이지 콘텐츠 로드
async function loadProfileContent() {
    try {
        // 네비게이션 요소 잠금 (다른 페이지에서 profile로 이동할 때도 네비게이션 유지)
        const profileDropdown = document.getElementById('profileDropdown');
        const notificationWrapper = document.getElementById('notificationWrapper');
        const pointsDisplay = document.getElementById('pointsDisplay');
        const loginLink = document.getElementById('loginLink');
        
        // 이미 잠겨있지 않으면 잠금 (navigateTo에서 이미 잠갔을 수도 있음)
        if (profileDropdown && !profileDropdown.getAttribute('data-router-locked')) {
            profileDropdown.setAttribute('data-router-locked', 'true');
        }
        if (notificationWrapper && !notificationWrapper.getAttribute('data-router-locked')) {
            notificationWrapper.setAttribute('data-router-locked', 'true');
        }
        if (pointsDisplay && !pointsDisplay.getAttribute('data-router-locked')) {
            pointsDisplay.setAttribute('data-router-locked', 'true');
        }
        if (loginLink && !loginLink.getAttribute('data-router-locked')) {
            loginLink.setAttribute('data-router-locked', 'true');
        }
        
        const response = await fetch('profile.html');
        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const container = doc.querySelector('.container');
        
        // 스크립트 태그 추출 및 실행 (window.loadProfile 함수 등록을 위해)
        // 라우터를 통해 로드 중임을 표시 (네비게이션 업데이트 방지)
        // navigateTo에서 이미 설정했을 수 있지만, 확실하게 설정
        window.isRouterNavigation = true;
        
        const scripts = doc.querySelectorAll('script');
        scripts.forEach(script => {
            if (script.textContent && !script.src) {
                try {
                    // 인라인 스크립트 실행
                    const scriptContent = script.textContent;
                    // window.loadProfile 함수 등록을 위해 전체 스크립트 실행
                    eval(scriptContent);
                } catch (e) {
                    console.warn('프로필 스크립트 실행 오류 (무시):', e);
                }
            }
        });
        
        return container ? container.innerHTML : '';
    } catch (error) {
        console.error('프로필 콘텐츠 로드 오류:', error);
        return getDefaultProfileContent();
    }
}

function getDefaultProfileContent() {
    return `
        <div class="profile-header">
            <div class="profile-info">
                <div class="profile-avatar" id="profileAvatar">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                    </svg>
                </div>
                <div>
                    <h2 id="profileName">사용자</h2>
                    <p id="profileEmail"></p>
                    <p class="post-count">작품 수: <span id="postCount">0</span>개</p>
                </div>
            </div>
        </div>
        <div class="profile-gallery">
            <div class="gallery-header">
                <h3>내 작품</h3>
            </div>
            <div class="gallery-grid" id="galleryGrid"></div>
        </div>
    `;
}

// 기본 콘텐츠 (fetch 실패 시)
function getDefaultIndexContent() {
    return `
        <div class="promo-banner-section">
            <div class="promo-banner">
                <div class="promo-banner-content">
                    <h2 class="promo-title">그림 커뮤니티</h2>
                    <p class="promo-description">다양한 작품을 감상하고 나만의 작품을 공유해보세요</p>
                </div>
            </div>
        </div>
        <div class="feed-header">
            <div class="feed-header-search-container">
                <div class="search-container">
                    <input type="text" id="feedSearchInput" placeholder="작품 검색" class="search-input" autocomplete="off">
                    <button id="feedSearchBtn" class="search-btn">
                        <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
                        </svg>
                    </button>
                </div>
            </div>
            <button class="upload-btn" id="uploadBtn">
                <span class="upload-btn-icon">
                    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
                        <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                    </svg>
                </span>
                <span>작품 업로드</span>
            </button>
        </div>
        <div class="feed-container" id="feedContainer"></div>
    `;
}

function getDefaultPopularContent() {
    return `
        <div class="popular-header">
            <h1>인기작품</h1>
            <p class="popular-header-description">좋아요가 많은 작품들을 확인해보세요</p>
        </div>
        <div class="feed-container" id="popularContainer"></div>
    `;
}

function getDefaultMissionContent() {
    return `
        <div class="mission-header">
            <h1>돈버는 미션</h1>
            <p>다양한 미션을 완료하고 포인트를 받아보세요</p>
        </div>
        <div id="missionContainer"></div>
    `;
}

function getDefaultShopContent() {
    return `
        <div class="popular-header">
            <h1>상점</h1>
            <p>다양한 아이템을 구매해보세요</p>
        </div>
        <div style="background: white; border-radius: 15px; padding: 2rem; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); text-align: center;">
            <p style="color: #999; font-size: 1.1rem;">상점 페이지는 준비 중입니다.</p>
        </div>
    `;
}

// 작품 상세보기 페이지 콘텐츠 로드
async function loadPostDetailContent(postId) {
    try {
        // 네비게이션 요소 잠금 (다른 페이지에서 post-detail로 이동할 때도 네비게이션 유지)
        const profileDropdown = document.getElementById('profileDropdown');
        const notificationWrapper = document.getElementById('notificationWrapper');
        const pointsDisplay = document.getElementById('pointsDisplay');
        const loginLink = document.getElementById('loginLink');
        
        // 이미 잠겨있지 않으면 잠금 (navigateTo에서 이미 잠갔을 수도 있음)
        if (profileDropdown && !profileDropdown.getAttribute('data-router-locked')) {
            profileDropdown.setAttribute('data-router-locked', 'true');
        }
        if (notificationWrapper && !notificationWrapper.getAttribute('data-router-locked')) {
            notificationWrapper.setAttribute('data-router-locked', 'true');
        }
        if (pointsDisplay && !pointsDisplay.getAttribute('data-router-locked')) {
            pointsDisplay.setAttribute('data-router-locked', 'true');
        }
        if (loginLink && !loginLink.getAttribute('data-router-locked')) {
            loginLink.setAttribute('data-router-locked', 'true');
        }
        
        const response = await fetch('post-detail.html');
        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const container = doc.querySelector('.container');
        
        // 스크립트 태그 추출 및 실행 (window.loadPostDetail 함수 등록을 위해)
        // 라우터를 통해 로드 중임을 표시 (네비게이션 업데이트 방지)
        // navigateTo에서 이미 설정했을 수 있지만, 확실하게 설정
        window.isRouterNavigation = true;
        
        // ⚠️ 중요: post-detail.html은 좋아요/댓글 이벤트를 인라인 스크립트에서 바인딩합니다.
        // 라우터로 로드할 때 그 스크립트가 실행되지 않으면(예: window.loadPostDetail만 eval) 모바일에서 버튼이 동작하지 않습니다.
        // 따라서 post-detail 인라인 스크립트는 "한 번만" 전체 실행합니다.
        const scripts = doc.querySelectorAll('script');
        scripts.forEach(script => {
            if (script.textContent && !script.src) {
                try {
                    const scriptContent = script.textContent;
                    // 중복 실행 방지 (이벤트 리스너 중복 등록/부작용 방지)
                    if (!window.__postDetailInlineScriptLoaded) {
                        eval(scriptContent);
                    }
                } catch (e) {
                    console.warn('작품 상세 스크립트 실행 오류 (무시):', e);
                }
            }
        });
        window.__postDetailInlineScriptLoaded = true;
        
        // 플래그 해제는 navigateTo의 finally 블록에서 처리하므로 여기서는 제거
        
        return container ? container.innerHTML : '';
    } catch (error) {
        console.error('post-detail.html 로드 실패:', error);
        return getDefaultPostDetailContent();
    }
}

function getDefaultPostDetailContent() {
    // post-detail.html의 기본 HTML 구조 반환
    return `
        <div class="post-detail-container">
            <div class="post-main">
                <div class="post-header">
                    <div class="post-author">
                        <span class="author-avatar">
                            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
                                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                            </svg>
                        </span>
                        <span class="author-name" id="authorName"></span>
                    </div>
                    <span class="post-date" id="postDate"></span>
                </div>
                <div class="post-title-section">
                    <h2 class="post-title-detail" id="postTitle"></h2>
                    <span class="post-views" id="postViews">조회수 0</span>
                </div>
                <div id="postTags" class="post-tags" style="margin-top: 1rem;"></div>
                <div class="post-image-container">
                    <img id="postImage" src="" alt="그림">
                    <button id="viewOriginalBtn" class="view-original-btn" style="display: none;">원본 보기</button>
                    <button id="viewCompressedBtn" class="view-compressed-btn" style="display: none;">압축본 보기</button>
                </div>
                <div class="post-caption" id="postCaption"></div>
                <div class="post-actions">
                    <button class="like-btn" id="likeBtn">
                        <span class="like-icon">♥</span>
                        <span id="likeCount">0</span>
                    </button>
                    <button class="comment-btn">
                        <span id="commentCount">0</span>
                    </button>
                </div>
                <div class="comments-section">
                    <h4>댓글</h4>
                    <div class="comment-form">
                        <textarea id="commentInput" placeholder="댓글을 입력하세요..." rows="2"></textarea>
                        <button class="btn-primary" id="submitComment">댓글 작성</button>
                    </div>
                    <div class="comments-list" id="commentsList"></div>
                </div>
            </div>
            <div class="recreation-sidebar">
                <button class="btn-secondary" id="uploadRecreationBtn" style="display: none;">따라그리기 업로드</button>
                <div id="originalImageDisplay" class="original-image-display" style="display: none;">
                    <h4>원본 그림</h4>
                    <img id="originalImage" src="" alt="원본 그림">
                </div>
            </div>
        </div>
    `;
}

// 페이지별 초기화
async function initializePageContent(route, params = {}) {
    switch (route) {
        case 'index':
            // 피드 로드
            if (window.loadFeed && document.getElementById('feedContainer')) {
                await window.loadFeed();
            }
            // 검색 기능 다시 설정
            if (window.setupSearch) {
                window.setupSearch();
            }
            // 업로드 모달 설정
            if (window.setupUploadModal) {
                window.setupUploadModal();
            }
            break;
        case 'popular':
            // 인기작품 로드 (popular.html의 스크립트가 처리)
            if (window.loadPopularPosts && document.getElementById('popularContainer')) {
                await window.loadPopularPosts();
            }
            break;
        case 'mission':
            // 미션 로드 (mission.html의 스크립트가 처리)
            if (window.loadMissions && document.getElementById('missionContainer')) {
                await window.loadMissions();
            }
            break;
        case 'shop':
            // 상점 초기화 (필요 시)
            break;
        case 'profile':
            // 프로필 로드 (profile.html의 스크립트가 처리)
            if (window.loadProfile) {
                await window.loadProfile();
            } else {
                // 함수가 없으면 대기 (최대 2초)
                let attempts = 0;
                const maxAttempts = 20;
                while (!window.loadProfile && attempts < maxAttempts) {
                    await new Promise(resolve => setTimeout(resolve, 100));
                    attempts++;
                }
                if (window.loadProfile) {
                    await window.loadProfile();
                } else {
                    console.error('loadProfile 함수를 찾을 수 없습니다.');
                }
            }
            break;
        case 'post-detail':
            // 작품 상세보기 로드
            if (params && params.id) {
                // post-detail.html의 loadPostDetail 함수 호출
                // post-detail.html의 스크립트는 전역 함수로 등록되어 있어야 함
                if (window.loadPostDetail) {
                    await window.loadPostDetail(params.id);
                } else {
                    // 함수가 없으면 직접 스크립트 로드 시도
                    // 또는 dataManager를 직접 사용
                    console.warn('loadPostDetail 함수를 찾을 수 없습니다. 함수가 정의될 때까지 대기합니다...');
                    // 함수가 정의될 때까지 대기 (최대 2초)
                    let attempts = 0;
                    const maxAttempts = 20;
                    while (!window.loadPostDetail && attempts < maxAttempts) {
                        await new Promise(resolve => setTimeout(resolve, 100));
                        attempts++;
                    }
                    if (window.loadPostDetail) {
                        await window.loadPostDetail(params.id);
                    } else {
                        console.error('loadPostDetail 함수를 찾을 수 없습니다. post-detail.html 스크립트를 확인하세요.');
                    }
                }
            }
            break;
    }
}

// 현재 경로에서 라우트 추출
function getRouteFromPath(path) {
    const pathname = path || window.location.pathname;
    const routeKey = pathname.split('/').pop() || 'index.html';
    
    // post-detail.html 체크
    if (pathname.includes('post-detail.html') || routeKey.includes('post-detail.html')) {
        return 'post-detail';
    }
    
    // profile.html 체크
    if (pathname.includes('profile.html') || routeKey.includes('profile.html')) {
        return 'profile';
    }
    
    if (routes[pathname]) {
        return routes[pathname];
    }
    if (routes[routeKey]) {
        return routes[routeKey];
    }
    return 'index';
}

// 라우터 초기화
function initRouter() {
    // 초기 라우트 설정
    const initialRoute = getRouteFromPath();
    currentRoute = initialRoute;

    // 네비게이션 링크에 이벤트 리스너 추가
    document.addEventListener('click', function(e) {
        // 상단 네비게이션 링크 (PC용 .nav-feed), 하단 네비게이션 링크 (모바일용 .bottom-nav-item), 로고 링크, 프로필 드롭다운 링크 처리
        const link = e.target.closest('a.nav-feed, a.bottom-nav-item, a.logo-link, a#profileLink');
        
        if (link && link.href) {
            const href = link.getAttribute('href');
            
            // 현재 도메인의 링크만 처리 (외부 링크 제외)
            if (href && !href.startsWith('http') && !href.startsWith('mailto:') && !href.startsWith('tel:')) {
                // post-detail.html은 쿼리 파라미터 처리 필요
                if (href.includes('post-detail.html')) {
                    e.preventDefault();
                    e.stopPropagation();
                    const urlParams = new URLSearchParams(new URL(href, window.location.origin).search);
                    const postId = urlParams.get('id');
                    if (postId) {
                        navigateTo('post-detail', { id: postId });
                    } else {
                        navigateTo('index');
                    }
                    return;
                }
                
                // profile.html은 라우터로 처리
                if (href.includes('profile.html')) {
                    e.preventDefault();
                    e.stopPropagation();
                    // 프로필 드롭다운 메뉴 닫기
                    const dropdownMenu = document.getElementById('dropdownMenu');
                    if (dropdownMenu) {
                        dropdownMenu.style.display = 'none';
                    }
                    navigateTo('profile');
                    return;
                }
                
                // 로그인, 검색 링크는 제외 (전체 페이지 로드)
                if (href.includes('login.html') || href.includes('search.html') || href === '#' || (!href.endsWith('.html') && href !== 'index.html' && !href.includes('index.html'))) {
                    // 이런 링크는 기본 동작 유지 (전체 페이지 로드)
                    return;
                }
                
                // index.html 또는 루트 경로도 처리
                if (href === 'index.html' || href === '/' || href.includes('index.html')) {
                    e.preventDefault();
                    e.stopPropagation();
                    navigateTo('index');
                    return;
                }
                
                e.preventDefault();
                e.stopPropagation();
                const route = getRouteFromPath(href);
                if (route && (routes[route] || route === 'index' || route === 'popular' || route === 'mission' || route === 'shop')) {
                    navigateTo(route);
                } else {
                    // 라우트를 찾지 못하면 기본 동작 유지
                    console.warn('라우트를 찾을 수 없음:', href, route);
                }
            }
        }
    });

    // 브라우저 뒤로/앞으로 버튼 처리
    window.addEventListener('popstate', function(e) {
        let route = 'index';
        let params = {};
        
        if (e.state && e.state.route) {
            route = e.state.route;
            params = e.state.params || {};
        } else {
            // URL에서 라우트와 파라미터 추출
            const path = window.location.pathname;
            route = getRouteFromPath(path);
            
            // post-detail인 경우 URL 파라미터에서 id 추출
            if (route === 'post-detail' || path.includes('post-detail.html')) {
                const urlParams = new URLSearchParams(window.location.search);
                const postId = urlParams.get('id');
                if (postId) {
                    params = { id: postId };
                    route = 'post-detail';
                }
            }
            
            // profile인 경우
            if (route === 'profile' || path.includes('profile.html')) {
                route = 'profile';
            }
        }
        
        if (route) {
            currentRoute = null; // 강제로 다시 로드
            navigateTo(route, params);
        }
    });

    // 현재 라우트가 index가 아니면 해당 페이지로 이동
    if (initialRoute === 'post-detail') {
        // post-detail인 경우 URL 파라미터에서 id 추출
        const urlParams = new URLSearchParams(window.location.search);
        const postId = urlParams.get('id');
        if (postId) {
            navigateTo('post-detail', { id: postId });
        } else {
            // id가 없으면 index로 리다이렉트
            navigateTo('index');
        }
    } else if (initialRoute === 'profile') {
        navigateTo('profile');
    } else if (initialRoute !== 'index') {
        navigateTo(initialRoute);
    } else {
        // index인 경우 활성 상태만 업데이트
        updateActiveNavigation('index');
    }
}

// 전역으로 export
window.router = {
    navigate: navigateTo,
    init: initRouter,
    getCurrentRoute: () => currentRoute
};

