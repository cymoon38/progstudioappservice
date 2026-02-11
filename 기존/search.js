// 검색 기능

// URL 파라미터에서 검색어 가져오기
function getSearchQuery() {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get('q') || '';
}

// 검색 실행
async function performSearch(query) {
    const searchResultsContainer = document.getElementById('searchResultsContainer');
    const searchResultsTitle = document.getElementById('searchResultsTitle');
    const searchResultsCount = document.getElementById('searchResultsCount');
    
    if (!query || query.trim() === '') {
        searchResultsContainer.innerHTML = '<div class="no-posts"><p>검색어를 입력해주세요.</p></div>';
        searchResultsTitle.textContent = '검색 결과';
        searchResultsCount.textContent = '';
        return;
    }
    
    try {
        searchResultsContainer.innerHTML = '<p style="text-align: center; padding: 2rem;">검색 중...</p>';
        
        console.log('🔍 검색 시작:', query);
        
        // Firebase 초기화 확인
        if (!window.dataManager) {
            console.error('❌ dataManager가 없습니다.');
            searchResultsContainer.innerHTML = '<div class="no-posts"><p>검색 기능을 초기화하는 중 오류가 발생했습니다.</p></div>';
            return;
        }
        
        // 서버 측 쿼리를 사용한 빠른 검색
        const searchResults = await window.dataManager.searchPosts(query, 50);
        
        console.log('✅ 검색 완료, 결과 개수:', searchResults.length);
        
        // 검색 결과 개수 표시
        const resultCount = searchResults.length;
        searchResultsTitle.textContent = `"${query}" 검색 결과`;
        searchResultsCount.textContent = `총 ${resultCount}개의 작품을 찾았습니다.`;
        
        // 검색 결과 표시
        if (resultCount === 0) {
            searchResultsContainer.innerHTML = `
                <div class="no-posts">
                    <p>검색 결과가 없습니다.</p>
                    <p style="margin-top: 1rem; color: #666; font-size: 0.9rem;">
                        다른 검색어로 시도해보세요.
                    </p>
                </div>
            `;
        } else {
            displaySearchResults(searchResults);
        }
    } catch (error) {
        console.error('❌ 검색 오류:', error);
        console.error('오류 상세:', error.message, error.stack);
        searchResultsContainer.innerHTML = `
            <div class="no-posts">
                <p>검색 중 오류가 발생했습니다.</p>
                <p style="margin-top: 1rem; color: #666; font-size: 0.9rem;">
                    오류: ${error.message}
                </p>
            </div>
        `;
    }
}

// 검색 결과 표시
function displaySearchResults(posts) {
    const searchResultsContainer = document.getElementById('searchResultsContainer');
    searchResultsContainer.innerHTML = '';
    
    // DocumentFragment 사용하여 성능 최적화
    const fragment = document.createDocumentFragment();
    
    posts.forEach(post => {
        const postCard = createPostCard(post);
        fragment.appendChild(postCard);
    });
    
    searchResultsContainer.appendChild(fragment);
}

// 게시물 카드 생성 (app.js의 createPostCard와 동일한 로직)
function createPostCard(post) {
    const postCard = document.createElement('div');
    postCard.className = 'post-card';
    
    // 조회한 게시물인지 확인
    const viewedPosts = getViewedPosts();
    if (viewedPosts.includes(post.id)) {
        postCard.classList.add('viewed-post');
    }
    
    // 좋아요 수 계산
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
    
    // 태그 표시
    let tagsHtml = '';
    if (post.tags && post.tags.length > 0) {
        tagsHtml = `
            <div class="post-tags" style="margin-top: 0.5rem; display: flex; flex-wrap: wrap; gap: 0.5rem;">
                ${post.tags.map(tag => `<span class="tag-badge" style="background: #f0f2ff; color: #667eea; padding: 0.25rem 0.75rem; border-radius: 15px; font-size: 0.85rem;">#${tag}</span>`).join('')}
            </div>
        `;
    }
    
    postCard.innerHTML = `
        <div class="post-header">
            <div class="post-author">
                <span class="author-name">${escapeHtml(post.author || '익명')}</span>
                ${post.type === 'recreation' ? '<span class="post-type-badge">모작</span>' : '<span class="post-type-badge">창작</span>'}
            </div>
            <div class="post-date">${formatDate(post.date)}</div>
        </div>
        <h3 class="post-title">
            <a href="post-detail.html?id=${post.id}" onclick="markAsViewed('${post.id}')">
                ${escapeHtml(post.title || '제목 없음')}
            </a>
        </h3>
        ${tagsHtml}
        <div class="post-actions" style="padding: 0; border: none; gap: 1rem; margin-top: 0.5rem;">
            <span class="like-count" style="font-size: 0.9rem; display: flex; align-items: center; gap: 0.25rem;"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="#ff6b6b" style="width: 0.9rem; height: 0.9rem;"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg> ${likesCount}</span>
            <span class="comment-count" style="font-size: 0.9rem; display: flex; align-items: center; gap: 0.25rem;"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="#667eea" style="width: 0.9rem; height: 0.9rem;"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg> ${commentsCount}</span>
        </div>
    `;
    
    // 클릭 시 상세 페이지로 이동
    postCard.addEventListener('click', function(e) {
        if (!e.target.closest('a')) {
            window.location.href = `post-detail.html?id=${post.id}`;
            markAsViewed(post.id);
        }
    });
    
    return postCard;
}

// HTML 이스케이프
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// 날짜 포맷팅
function formatDate(timestamp) {
    if (!timestamp) return '';
    
    try {
        let date;
        if (timestamp.toDate) {
            date = timestamp.toDate();
        } else if (timestamp.seconds) {
            date = new Date(timestamp.seconds * 1000);
        } else {
            date = new Date(timestamp);
        }
        
        const now = new Date();
        const diff = now - date;
        const seconds = Math.floor(diff / 1000);
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        
        if (seconds < 60) return '방금 전';
        if (minutes < 60) return `${minutes}분 전`;
        if (hours < 24) return `${hours}시간 전`;
        if (days < 7) return `${days}일 전`;
        
        return date.toLocaleDateString('ko-KR');
    } catch (e) {
        return '';
    }
}

// 조회한 게시물 관리 (app.js와 동일 - 사용자별로 분리)
function getCurrentUserId() {
    try {
        if (window.currentUser && window.currentUser.uid) {
            return window.currentUser.uid;
        }
        if (typeof firebaseAuth !== 'undefined' && firebaseAuth && firebaseAuth.currentUser) {
            return firebaseAuth.currentUser.uid;
        }
        return null;
    } catch (error) {
        return null;
    }
}

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
    } catch (e) {
        return [];
    }
}

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
    } catch (e) {
        console.error('조회 기록 저장 오류:', e);
    }
}

// 페이지 로드 시 검색 실행
document.addEventListener('DOMContentLoaded', async function() {
    console.log('📄 search.html 페이지 로드됨');
    
    // Firebase 초기화 대기
    let attempts = 0;
    while ((!window.dataManager || !db) && attempts < 100) {
        await new Promise(resolve => setTimeout(resolve, 100));
        attempts++;
    }
    
    if (!window.dataManager || !db) {
        console.error('❌ Firebase 초기화 실패');
        const searchResultsContainer = document.getElementById('searchResultsContainer');
        if (searchResultsContainer) {
            searchResultsContainer.innerHTML = '<div class="no-posts"><p>Firebase 초기화에 실패했습니다. 페이지를 새로고침해주세요.</p></div>';
        }
        return;
    }
    
    console.log('✅ Firebase 초기화 완료');
    
    // URL에서 검색어 가져오기
    const query = getSearchQuery();
    console.log('🔍 검색어:', query);
    
    // 검색 입력창에 검색어 표시
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        searchInput.value = query;
    }
    
    // 검색 실행
    if (query) {
        console.log('🚀 검색 시작...');
        await performSearch(query);
    } else {
        const searchResultsContainer = document.getElementById('searchResultsContainer');
        if (searchResultsContainer) {
            searchResultsContainer.innerHTML = '<div class="no-posts"><p>검색어를 입력해주세요.</p></div>';
        }
    }
    
    // 검색 버튼 클릭 이벤트
    const searchBtn = document.getElementById('searchBtn');
    if (searchBtn && searchInput) {
        searchBtn.addEventListener('click', function() {
            const query = searchInput.value.trim();
            if (query) {
                window.location.href = `search.html?q=${encodeURIComponent(query)}`;
            }
        });
    }
    
    // Enter 키로 검색
    if (searchInput) {
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                const query = searchInput.value.trim();
                if (query) {
                    window.location.href = `search.html?q=${encodeURIComponent(query)}`;
                }
            }
        });
    }
});

