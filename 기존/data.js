// Firestore 데이터베이스 작업 관리

// 사용자 존재 여부 캐시 (성능 최적화)
const userExistsCache = new Map();
const CACHE_DURATION = 1 * 60 * 1000; // 1분 (더 짧게 설정하여 최신 상태 유지)

const dataManager = {
    // 사용자 존재 여부 확인 (캐시 사용)
    async checkUserExists(username) {
        try {
            if (!db || !username || username.trim() === '') {
                return false;
            }

            // 캐시 확인 (캐시 시간을 짧게 설정하여 최신 상태 유지)
            const cached = userExistsCache.get(username);
            if (cached && Date.now() - cached.timestamp < CACHE_DURATION) {
                return cached.exists;
            }

            let exists = false;
            try {
                const snapshot = await db.collection('users')
                    .where('name', '==', username.trim())
                    .limit(1)
                    .get();

                exists = !snapshot.empty;
            } catch (queryError) {
                // 쿼리 실패 시 (권한 오류 등) 기본값 반환 (존재한다고 가정하여 게시물 표시)
                console.warn('사용자 존재 확인 쿼리 오류 (존재한다고 가정):', queryError);
                exists = true; // 오류 발생 시 존재한다고 가정 (게시물이 표시되도록)
            }
            
            // 캐시에 저장
            userExistsCache.set(username, {
                exists: exists,
                timestamp: Date.now()
            });

            console.log('사용자 존재 확인:', username, exists ? '존재함' : '존재하지 않음');
            return exists;
        } catch (error) {
            console.error('❌ 사용자 존재 확인 오류:', error, username);
            // 오류 발생 시 안전하게 true 반환 (중복 가능성 있음)
            return true;
        }
    },

    // 이메일 존재 여부 확인
    async checkEmailExists(email) {
        try {
            if (!db || !email || email.trim() === '') {
                return false;
            }

            const snapshot = await db.collection('users')
                .where('email', '==', email.trim().toLowerCase())
                .limit(1)
                .get();

            const exists = !snapshot.empty;
            console.log('이메일 존재 확인:', email, exists ? '존재함' : '존재하지 않음');
            return exists;
        } catch (error) {
            console.error('❌ 이메일 존재 확인 오류:', error, email);
            // 오류 발생 시 안전하게 true 반환 (중복 가능성 있음)
            return true;
        }
    },

    // 캐시 초기화
    clearUserCache(username) {
        if (username) {
            userExistsCache.delete(username);
        } else {
            userExistsCache.clear();
        }
    },

    // 게시물 캐시 무효화 (피드, 인기작품)
    clearPostsCache() {
        try {
            localStorage.removeItem('feed_posts_cache');
            localStorage.removeItem('feed_posts_cache_timestamp');
            localStorage.removeItem('popular_posts_cache');
            localStorage.removeItem('popular_posts_cache_timestamp');
            console.log('✅ 게시물 캐시 무효화 완료');
        } catch (error) {
            console.warn('캐시 무효화 오류 (무시):', error);
        }
    },

    // 특정 게시물 캐시 무효화
    clearPostCache(postId) {
        try {
            localStorage.removeItem(`post_${postId}_cache`);
            localStorage.removeItem(`post_${postId}_cache_timestamp`);
        } catch (error) {
            console.warn('게시물 캐시 무효화 오류 (무시):', error);
        }
    },

    // 삭제된 사용자 데이터 정리 (게시물, 댓글, 좋아요)
    async cleanDeletedUserData(username) {
        try {
            if (!db || !username) {
                return;
            }

            // 해당 사용자의 모든 게시물 가져오기
            const postsSnapshot = await db.collection('posts')
                .where('author', '==', username)
                .get();

            const batch = db.batch();
            let batchCount = 0;
            const maxBatchSize = 500; // Firestore 배치 제한

            // 게시물 삭제
            postsSnapshot.forEach(doc => {
                const post = doc.data();
                
                // 이미지 삭제
                if (post.image && window.storageManager) {
                    window.storageManager.deleteImage(post.image).catch(err => {
                        console.error('이미지 삭제 오류:', err);
                    });
                }
                if (post.originalImage && window.storageManager) {
                    window.storageManager.deleteImage(post.originalImage).catch(err => {
                        console.error('원본 이미지 삭제 오류:', err);
                    });
                }

                batch.delete(doc.ref);
                batchCount++;

                if (batchCount >= maxBatchSize) {
                    batch.commit();
                    batchCount = 0;
                }
            });

            if (batchCount > 0) {
                await batch.commit();
            }

            // 모든 게시물에서 해당 사용자의 댓글과 좋아요 제거
            const allPostsSnapshot = await db.collection('posts').get();
            const updateBatch = db.batch();
            let updateBatchCount = 0;

            allPostsSnapshot.forEach(doc => {
                const post = doc.data();
                let updated = false;
                const updatedPost = { ...post };

                // 좋아요 목록에서 제거
                if (post.likes && post.likes.includes(username)) {
                    updatedPost.likes = post.likes.filter(like => like !== username);
                    updated = true;
                }

                // 댓글 목록에서 제거
                if (post.comments && Array.isArray(post.comments)) {
                    const originalLength = post.comments.length;
                    updatedPost.comments = post.comments.filter(comment => comment.author !== username);
                    if (updatedPost.comments.length !== originalLength) {
                        updated = true;
                    }
                }

                // 따라그리기에서 제거
                if (post.recreations && Array.isArray(post.recreations)) {
                    const originalLength = post.recreations.length;
                    updatedPost.recreations = post.recreations.filter(recreation => recreation.author !== username);
                    if (updatedPost.recreations.length !== originalLength) {
                        updated = true;
                    }
                }

                if (updated) {
                    updateBatch.update(doc.ref, updatedPost);
                    updateBatchCount++;

                    if (updateBatchCount >= maxBatchSize) {
                        updateBatch.commit();
                        updateBatchCount = 0;
                    }
                }
            });

            if (updateBatchCount > 0) {
                await updateBatch.commit();
            }

            console.log('✅ 삭제된 사용자 데이터 정리 완료:', username);
        } catch (error) {
            console.error('❌ 삭제된 사용자 데이터 정리 오류:', error);
        }
    },

    // 게시물에서 삭제된 사용자 필터링
    async filterDeletedUsers(posts) {
        if (!posts || posts.length === 0) {
            return [];
        }

        const validPosts = [];
        const postsToUpdate = [];
        
        for (const post of posts) {
            // 작성자 존재 여부 확인
            if (!post.author) {
                // 작성자 정보가 없으면 제외
                continue;
            }

            const authorExists = await this.checkUserExists(post.author);
            
            // 작성자가 삭제된 경우 게시물 제외
            if (!authorExists) {
                console.log('삭제된 사용자의 게시물 제외:', post.author, post.id);
                continue;
            }
            
            let needsUpdate = false;
            const originalLikesCount = post.likes ? post.likes.length : 0;
            const originalCommentsCount = post.comments ? post.comments.length : 0;
            const originalRecreationsCount = post.recreations ? post.recreations.length : 0;

            // 좋아요 목록에서 삭제된 사용자 제거
            if (post.likes && Array.isArray(post.likes)) {
                const validLikes = [];
                for (const likeUser of post.likes) {
                    if (likeUser && await this.checkUserExists(likeUser)) {
                        validLikes.push(likeUser);
                    }
                }
                if (validLikes.length !== originalLikesCount) {
                    post.likes = validLikes;
                    needsUpdate = true;
                }
            }

            // 댓글 목록에서 삭제된 사용자 제거
            if (post.comments && Array.isArray(post.comments)) {
                const validComments = [];
                for (const comment of post.comments) {
                    if (comment && comment.author && await this.checkUserExists(comment.author)) {
                        validComments.push(comment);
                    }
                }
                if (validComments.length !== originalCommentsCount) {
                    post.comments = validComments;
                    needsUpdate = true;
                }
            }

            // 따라그리기에서 삭제된 사용자 제거
            if (post.recreations && Array.isArray(post.recreations)) {
                const validRecreations = [];
                for (const recreation of post.recreations) {
                    if (recreation && recreation.author && await this.checkUserExists(recreation.author)) {
                        validRecreations.push(recreation);
                    }
                }
                if (validRecreations.length !== originalRecreationsCount) {
                    post.recreations = validRecreations;
                    needsUpdate = true;
                }
            }

            // 업데이트가 필요한 게시물 저장
            if (needsUpdate) {
                postsToUpdate.push(post);
            }

            validPosts.push(post);
        }

        // 삭제된 사용자 데이터가 정리된 게시물들을 일괄 업데이트
        if (postsToUpdate.length > 0) {
            // 비동기로 업데이트 (블로킹하지 않음)
            Promise.all(postsToUpdate.map(post => this.updatePost(post).catch(err => {
                console.error('게시물 업데이트 오류:', err);
            }))).catch(err => {
                console.error('게시물 일괄 업데이트 오류:', err);
            });
        }

        return validPosts;
    },

    // 모든 게시물 가져오기 (최신순) - localStorage 캐싱으로 성능 최적화
    async getAllPosts() {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            // localStorage 캐시 확인 (비용 절감: 읽기 횟수 감소)
            const cacheKey = 'feed_posts_cache';
            const cacheTimestampKey = 'feed_posts_cache_timestamp';
            const CACHE_DURATION = 2 * 60 * 1000; // 2분 캐시 (비용 절감)
            
            const cachedData = localStorage.getItem(cacheKey);
            const cacheTimestamp = localStorage.getItem(cacheTimestampKey);
            
            // 캐시가 있고 2분 이내라면 즉시 반환 (읽기 비용 0)
            if (cachedData && cacheTimestamp && (Date.now() - parseInt(cacheTimestamp)) < CACHE_DURATION) {
                try {
                    const cachedPosts = JSON.parse(cachedData);
                    console.log('✅ 캐시에서 게시물 로드 (읽기 비용 0):', cachedPosts.length, '개');
                    
                    // 백그라운드에서 최신 데이터 확인 (사용자 경험 개선)
                    this.getAllPostsFromFirestore().then(latestPosts => {
                        if (latestPosts && latestPosts.length > 0) {
                            // 최신 데이터가 있으면 캐시 업데이트
                            localStorage.setItem(cacheKey, JSON.stringify(latestPosts));
                            localStorage.setItem(cacheTimestampKey, Date.now().toString());
                        }
                    }).catch(err => {
                        console.warn('백그라운드 데이터 업데이트 실패 (무시):', err);
                    });
                    
                    return cachedPosts;
                } catch (parseError) {
                    console.warn('캐시 파싱 오류, Firestore에서 로드:', parseError);
                }
            }

            // 캐시가 없거나 만료된 경우 Firestore에서 로드
            const posts = await this.getAllPostsFromFirestore();
            
            // 캐시에 저장 (다음 방문 시 빠른 로드)
            try {
                localStorage.setItem(cacheKey, JSON.stringify(posts));
                localStorage.setItem(cacheTimestampKey, Date.now().toString());
            } catch (storageError) {
                console.warn('localStorage 저장 실패 (무시):', storageError);
            }
            
            return posts;
        } catch (error) {
            console.error('❌ 게시물 가져오기 오류:', error);
            
            // 오류 발생 시 캐시에서 로드 시도
            const cacheKey = 'feed_posts_cache';
            const cachedData = localStorage.getItem(cacheKey);
            if (cachedData) {
                try {
                    const cachedPosts = JSON.parse(cachedData);
                    console.log('⚠️ 오류 발생, 캐시에서 게시물 로드:', cachedPosts.length, '개');
                    return cachedPosts;
                } catch (parseError) {
                    console.error('캐시 파싱 오류:', parseError);
                }
            }
            
            return [];
        }
    },

    // Firestore에서 게시물 가져오기 (내부 함수)
    async getAllPostsFromFirestore() {
            const snapshot = await db.collection('posts')
                .orderBy('date', 'desc')
                .get();

            const posts = [];
            snapshot.forEach(doc => {
                const data = doc.data();
                posts.push({
                    id: doc.id,
                    ...data
                });
            });

            // 성능 최적화: 삭제된 사용자 필터링 비활성화 (너무 많은 쿼리 발생)
            // 삭제된 사용자의 게시물은 드물고, 실시간 필터링보다는 정기적인 데이터 정리가 더 효율적
            // const validPosts = await this.filterDeletedUsers(posts);
            
            return posts;
    },

    // 특정 게시물 가져오기 - 삭제된 사용자 필터링
    async getPost(postId) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            const doc = await db.collection('posts').doc(postId).get();
            
            if (!doc.exists) {
                return null;
            }

            const post = {
                id: doc.id,
                ...doc.data()
            };

            // 작성자 존재 여부 확인
            const authorExists = await this.checkUserExists(post.author);
            if (!authorExists) {
                // 작성자가 삭제된 경우 null 반환
                return null;
            }

            // 좋아요, 댓글, 따라그리기에서 삭제된 사용자 제거
            const filteredPosts = await this.filterDeletedUsers([post]);
            return filteredPosts.length > 0 ? filteredPosts[0] : null;
        } catch (error) {
            console.error('❌ 게시물 가져오기 오류:', error);
            return null;
        }
    },

    // 인기 게시물 가져오기 (좋아요 수 기준) - localStorage 캐싱으로 성능 최적화
    async getPopularPosts(limit = 10) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            // localStorage 캐시 확인 (비용 절감: 읽기 횟수 감소)
            const cacheKey = 'popular_posts_cache';
            const cacheTimestampKey = 'popular_posts_cache_timestamp';
            const CACHE_DURATION = 3 * 60 * 1000; // 3분 캐시 (인기작품은 자주 변하지 않음)
            
            const cachedData = localStorage.getItem(cacheKey);
            const cacheTimestamp = localStorage.getItem(cacheTimestampKey);
            
            // 캐시가 있고 3분 이내라면 즉시 반환 (읽기 비용 0)
            if (cachedData && cacheTimestamp && (Date.now() - parseInt(cacheTimestamp)) < CACHE_DURATION) {
                try {
                    const cachedPosts = JSON.parse(cachedData);
                    console.log('✅ 캐시에서 인기작품 로드 (읽기 비용 0):', cachedPosts.length, '개');
                    
                    // 백그라운드에서 최신 데이터 확인 (사용자 경험 개선)
                    this.getPopularPostsFromFirestore(limit).then(latestPosts => {
                        if (latestPosts && latestPosts.length > 0) {
                            // 최신 데이터가 있으면 캐시 업데이트
                            localStorage.setItem(cacheKey, JSON.stringify(latestPosts));
                            localStorage.setItem(cacheTimestampKey, Date.now().toString());
                        }
                    }).catch(err => {
                        console.warn('백그라운드 인기작품 업데이트 실패 (무시):', err);
                    });
                    
                    return cachedPosts;
                } catch (parseError) {
                    console.warn('캐시 파싱 오류, Firestore에서 로드:', parseError);
                }
            }

            // 캐시가 없거나 만료된 경우 Firestore에서 로드
            const posts = await this.getPopularPostsFromFirestore(limit);
            
            // 캐시에 저장 (다음 방문 시 빠른 로드)
            try {
                localStorage.setItem(cacheKey, JSON.stringify(posts));
                localStorage.setItem(cacheTimestampKey, Date.now().toString());
            } catch (storageError) {
                console.warn('localStorage 저장 실패 (무시):', storageError);
            }
            
            return posts;
        } catch (error) {
            console.error('❌ 인기 게시물 가져오기 오류:', error);
            
            // 오류 발생 시 캐시에서 로드 시도
            const cacheKey = 'popular_posts_cache';
            const cachedData = localStorage.getItem(cacheKey);
            if (cachedData) {
                try {
                    const cachedPosts = JSON.parse(cachedData);
                    console.log('⚠️ 오류 발생, 캐시에서 인기작품 로드:', cachedPosts.length, '개');
                    return cachedPosts;
                } catch (parseError) {
                    console.error('캐시 파싱 오류:', parseError);
                }
            }
            
            return [];
        }
    },

    // Firestore에서 인기 게시물 가져오기 (내부 함수)
    async getPopularPostsFromFirestore(limit = 10) {
            const snapshot = await db.collection('posts').get();
            const posts = [];
            
            snapshot.forEach(doc => {
                const data = doc.data();
                posts.push({
                    id: doc.id,
                    ...data,
                    likesCount: data.likes ? data.likes.length : 0
                });
            });

            // 삭제된 사용자의 게시물 필터링 (오류 발생 시 원본 반환)
            let validPosts = posts;
            try {
                validPosts = await this.filterDeletedUsers(posts);
            } catch (filterError) {
                console.warn('삭제된 사용자 필터링 오류 (원본 게시물 반환):', filterError);
                // 필터링 실패 시 원본 게시물 반환 (로그인하지 않은 상태 등)
                validPosts = posts;
            }

            // 좋아요 수 기준으로 정렬 (필터링 후)
            validPosts.forEach(post => {
                post.likesCount = post.likes ? post.likes.length : 0;
            });
            validPosts.sort((a, b) => b.likesCount - a.likesCount);
            
            // 추천수 2 이상인 게시물만 필터링
            const popularPosts = validPosts.filter(post => post.likesCount >= 2);
            
            return popularPosts.slice(0, limit);
    },

    // 사용자의 게시물 가져오기 - 사용자 존재 여부 확인
    async getUserPosts(username) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            if (!username || username.trim() === '') {
                console.error('❌ 사용자 이름이 비어있습니다.');
                return [];
            }

            const trimmedUsername = username.trim();
            console.log('🔍 게시물 조회 시작 - 사용자:', trimmedUsername);

            // 모든 게시물을 가져와서 필터링하는 방식 사용 (확실한 방법)
            // 인덱스 문제나 쿼리 문제를 피하기 위해
            let snapshot;
            
            try {
                // 먼저 인덱스 쿼리 시도
                snapshot = await db.collection('posts')
                    .where('author', '==', trimmedUsername)
                    .orderBy('date', 'desc')
                    .get();
                console.log('✅ 인덱스 쿼리 성공');
            } catch (indexError) {
                console.warn('⚠️ 인덱스 쿼리 실패, orderBy 없이 시도:', indexError.message);
                
                try {
                    // orderBy 없이 시도
                    snapshot = await db.collection('posts')
                        .where('author', '==', trimmedUsername)
                        .get();
                    console.log('✅ 단순 쿼리 성공');
                } catch (queryError) {
                    console.warn('⚠️ 단순 쿼리도 실패, 모든 게시물 조회 후 필터링:', queryError.message);
                    
                    // 모든 게시물 가져와서 필터링 (fallback)
                    snapshot = await db.collection('posts').get();
                    console.log('✅ 전체 게시물 조회 성공 (fallback)');
                }
            }

            const posts = [];
            const allAuthors = new Set(); // 디버깅용
            
            snapshot.forEach(doc => {
                const data = doc.data();
                const postAuthor = data.author ? data.author.trim() : '';
                
                // 디버깅: 모든 author 수집
                if (postAuthor) {
                    allAuthors.add(postAuthor);
                }
                
                // author가 일치하는 게시물만 추가 (대소문자 무시, 공백 무시)
                const postAuthorNormalized = postAuthor.toLowerCase().trim();
                const usernameNormalized = trimmedUsername.toLowerCase().trim();
                
                if (postAuthorNormalized === usernameNormalized) {
                    posts.push({
                        id: doc.id,
                        ...data
                    });
                }
            });
            
            // 디버깅 정보 출력
            if (posts.length === 0 && allAuthors.size > 0) {
                console.warn('⚠️ 일치하는 게시물이 없습니다.');
                console.warn('📋 찾고 있는 이름:', trimmedUsername);
                console.warn('📋 Firestore에 있는 author 목록:', Array.from(allAuthors));
                console.warn('💡 author 필드가 정확히 일치하는지 확인하세요. (대소문자, 공백 포함)');
            }

            console.log('📊 조회된 게시물:', posts.length, '개');
            
            // 날짜순 정렬 (orderBy가 없었던 경우)
            if (posts.length > 0) {
                posts.sort((a, b) => {
                    const dateA = a.date ? (a.date.toDate ? a.date.toDate() : new Date(a.date)) : new Date(0);
                    const dateB = b.date ? (b.date.toDate ? b.date.toDate() : new Date(b.date)) : new Date(0);
                    return dateB - dateA; // 최신순
                });
            }

            // 디버깅: 처음 몇 개 게시물의 author 확인
            if (posts.length > 0) {
                console.log('✅ 게시물 찾기 성공!');
                console.log('📝 첫 번째 게시물 샘플:', {
                    id: posts[0].id,
                    author: posts[0].author,
                    title: posts[0].title
                });
            } else {
                // 게시물이 없는 경우, Firestore에 실제로 데이터가 있는지 확인
                console.log('⚠️ 일치하는 게시물이 없습니다. Firestore 확인 중...');
                const allPostsSnapshot = await db.collection('posts').limit(10).get();
                const samplePosts = [];
                const authorsSet = new Set();
                
                allPostsSnapshot.forEach(doc => {
                    const data = doc.data();
                    const author = data.author ? data.author.trim() : '';
                    if (author) authorsSet.add(author);
                    samplePosts.push({
                        id: doc.id,
                        author: data.author,
                        authorLength: data.author ? data.author.length : 0,
                        title: data.title
                    });
                });
                
                console.log('🔍 Firestore의 샘플 게시물 (처음 10개):', samplePosts);
                console.log('🔍 Firestore에 있는 모든 author 목록:', Array.from(authorsSet));
                console.log('🔍 찾고 있는 사용자 이름:', trimmedUsername);
                console.log('🔍 찾는 이름의 길이:', trimmedUsername.length);
                console.log('💡 해결 방법:');
                console.log('   1. Firebase Console > Firestore > posts 컬렉션에서 게시물 확인');
                console.log('   2. 게시물의 author 필드와 위의 "찾고 있는 사용자 이름"이 정확히 일치하는지 확인');
                console.log('   3. 대소문자, 공백, 특수문자까지 모두 일치해야 합니다');
            }

            // 삭제된 사용자 필터링은 건너뛰기 (성능상 문제가 있을 수 있음)
            // const validPosts = await this.filterDeletedUsers(posts);
            // console.log('✅ 필터링 후 게시물 개수:', validPosts.length);
            
            console.log('✅ 최종 반환 게시물 개수:', posts.length);
            return posts;
        } catch (error) {
            console.error('❌ 사용자 게시물 가져오기 오류:', error);
            console.error('에러 상세:', {
                message: error.message,
                code: error.code,
                username: username
            });
            
            // 인덱스 관련 에러인 경우 안내 메시지
            if (error.message && error.message.includes('index')) {
                console.error('💡 해결 방법: Firebase Console > Firestore > Indexes에서 복합 인덱스를 생성하세요.');
            }
            
            return [];
        }
    },

    // 게시물 생성
    async createPost(postData) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            const post = {
                title: postData.title || '',
                caption: postData.caption || '',
                image: postData.image || '',
                originalImage: postData.originalImage || null,
                author: postData.author || '',
                authorUid: postData.authorUid || null, // 알림 기능을 위해 UID도 저장
                type: postData.type || 'original', // 'original' or 'recreation'
                tags: postData.tags || [], // 태그 배열
                date: firebase.firestore.FieldValue.serverTimestamp(),
                likes: postData.likes || [],
                comments: postData.comments || [],
                recreations: postData.recreations || [],
                views: 0
            };

            const docRef = await db.collection('posts').add(post);
            console.log('✅ 게시물 생성 완료:', docRef.id);

            // 캐시 무효화 (새 게시물이 추가되었으므로)
            this.clearPostsCache();

            // 생성된 게시물 반환
            const createdPost = await docRef.get();
            return {
                id: createdPost.id,
                ...createdPost.data()
            };
        } catch (error) {
            console.error('❌ 게시물 생성 오류:', error);
            throw new Error('게시물 생성에 실패했습니다: ' + error.message);
        }
    },

    // 게시물 업데이트
    async updatePost(post) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            if (!post.id) {
                throw new Error('게시물 ID가 없습니다.');
            }

            const postData = { ...post };
            delete postData.id; // ID는 문서 경로로 사용되므로 데이터에서 제거

            // date 필드를 유지하되, 업데이트 시간은 자동으로 처리
            await db.collection('posts').doc(post.id).update(postData);
            console.log('✅ 게시물 업데이트 완료:', post.id);
            
            // 캐시 무효화 (게시물이 업데이트되었으므로)
            this.clearPostsCache();
            this.clearPostCache(post.id);
            
            // 인기작품 선정 체크 (좋아요가 2개 이상이고 아직 인기작품이 아닌 경우)
            const likesCount = post.likes ? post.likes.length : 0;
            if (likesCount >= 2 && !post.isPopular) {
                console.log('🔍 updatePost에서 인기작품 선정 체크:', {
                    postId: post.id,
                    likesCount: likesCount,
                    isPopular: post.isPopular
                });
                
                // 인기작품 선정 처리 함수 호출 (전역 함수로 만들어야 함)
                // post-detail.html 또는 app.js에서 정의됨
                if (window.checkAndRewardPopularPost) {
                    // 비동기 호출이므로 await 없이 호출 (백그라운드 처리)
                    window.checkAndRewardPopularPost(post.id, post).catch(error => {
                        console.error('❌ 인기작품 코인 지급 오류 (updatePost):', error);
                    });
                } else {
                    console.warn('⚠️ checkAndRewardPopularPost 함수를 찾을 수 없습니다. 코인 지급이 건너뜁니다.');
                }
            }
        } catch (error) {
            console.error('❌ 게시물 업데이트 오류:', error);
            throw new Error('게시물 업데이트에 실패했습니다: ' + error.message);
        }
    },

    // 게시물 삭제
    async deletePost(postId) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            if (!postId) {
                throw new Error('게시물 ID가 없습니다.');
            }

            // 게시물 데이터 직접 가져오기 (필터링 없이, 이미지 URL을 위해)
            const doc = await db.collection('posts').doc(postId).get();
            
            if (!doc.exists) {
                throw new Error('게시물을 찾을 수 없습니다.');
            }

            const post = {
                id: doc.id,
                ...doc.data()
            };
            
            // 이미지 삭제
            if (post.image && window.storageManager) {
                try {
                    await window.storageManager.deleteImage(post.image);
                } catch (imgError) {
                    console.warn('이미지 삭제 실패 (계속 진행):', imgError);
                }
            }
            if (post.originalImage && window.storageManager) {
                try {
                    await window.storageManager.deleteImage(post.originalImage);
                } catch (imgError) {
                    console.warn('원본 이미지 삭제 실패 (계속 진행):', imgError);
                }
            }

            // 게시물 삭제
            await db.collection('posts').doc(postId).delete();
            console.log('✅ 게시물 삭제 완료:', postId);

            // 캐시 무효화 (게시물이 삭제되었으므로)
            this.clearPostsCache();
            this.clearPostCache(postId);

            // 사용자 게시물 수 업데이트 (작성자가 존재하는 경우에만)
            if (post.author) {
                const authorExists = await this.checkUserExists(post.author);
                if (authorExists) {
                    await this.updateUserPostCount(post.author);
                }
            }
        } catch (error) {
            console.error('❌ 게시물 삭제 오류:', error);
            throw new Error('게시물 삭제에 실패했습니다: ' + error.message);
        }
    },

    // 사용자 정보 가져오기
    async getUserInfo(username) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            const snapshot = await db.collection('users')
                .where('name', '==', username)
                .limit(1)
                .get();

            if (snapshot.empty) {
                return null;
            }

            const doc = snapshot.docs[0];
            return {
                uid: doc.id,
                ...doc.data()
            };
        } catch (error) {
            console.error('❌ 사용자 정보 가져오기 오류:', error);
            return null;
        }
    },

    // 사용자 정보 업데이트
    async updateUserInfo(uid, userData) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            await db.collection('users').doc(uid).update(userData);
            console.log('✅ 사용자 정보 업데이트 완료');
        } catch (error) {
            console.error('❌ 사용자 정보 업데이트 오류:', error);
            throw new Error('사용자 정보 업데이트에 실패했습니다: ' + error.message);
        }
    },

    // 사용자 게시물 수 업데이트
    async updateUserPostCount(username) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            const posts = await this.getUserPosts(username);
            const postCount = posts.length;

            // 사용자 정보 가져오기
            const userInfo = await this.getUserInfo(username);
            if (userInfo && userInfo.uid) {
                await db.collection('users').doc(userInfo.uid).update({
                    postCount: postCount
                });
            }
        } catch (error) {
            console.error('❌ 사용자 게시물 수 업데이트 오류:', error);
        }
    },

    // Firestore 초기화 대기
    waitForFirestore() {
        return new Promise((resolve, reject) => {
            let attempts = 0;
            const maxAttempts = 50; // 5초 대기

            const checkInterval = setInterval(() => {
                attempts++;
                
                if (db) {
                    clearInterval(checkInterval);
                    resolve();
                } else if (attempts >= maxAttempts) {
                    clearInterval(checkInterval);
                    reject(new Error('Firestore 초기화에 실패했습니다.'));
                }
            }, 100);
        });
    },

    // 알림 생성
    async createNotification(notificationData) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            console.log('🔔 알림 생성 시도:', notificationData);

            if (!notificationData.userId) {
                console.error('❌ userId가 없습니다:', notificationData);
                return;
            }

            const notification = {
                userId: notificationData.userId, // 알림을 받을 사용자 ID
                type: notificationData.type, // 'like' 또는 'comment'
                postId: notificationData.postId,
                postTitle: notificationData.postTitle || '제목 없음',
                author: notificationData.author, // 좋아요/댓글을 단 사용자
                read: false,
                createdAt: firebase.firestore.FieldValue.serverTimestamp()
            };

            // 댓글인 경우 댓글 내용도 저장
            if (notificationData.type === 'comment' && notificationData.commentText) {
                notification.commentText = notificationData.commentText;
            }

            const docRef = await db.collection('notifications').add(notification);
            console.log('✅ 알림 생성 완료:', {
                id: docRef.id,
                userId: notification.userId,
                type: notification.type,
                postId: notification.postId
            });
            return docRef.id;
        } catch (error) {
            console.error('❌ 알림 생성 오류:', error);
            console.error('오류 상세:', {
                code: error.code,
                message: error.message,
                notificationData: notificationData
            });
            throw error;
        }
    },

    // 사용자의 알림 가져오기 (읽지 않은 알림만)
    async getUserNotifications(userId, limit = 50) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            // 읽지 않은 알림만 가져오기
            const snapshot = await db.collection('notifications')
                .where('userId', '==', userId)
                .where('read', '==', false)
                .orderBy('createdAt', 'desc')
                .limit(limit)
                .get();

            const notifications = [];
            snapshot.forEach(doc => {
                const data = doc.data();
                notifications.push({
                    id: doc.id,
                    ...data
                });
            });

            // 같은 게시물의 알림을 그룹화
            const groupedNotifications = this.groupNotificationsByPost(notifications);

            return groupedNotifications;
        } catch (error) {
            console.error('❌ 알림 가져오기 오류:', error);
            // orderBy 없이 시도 (읽지 않은 알림만)
            try {
                const snapshot = await db.collection('notifications')
                    .where('userId', '==', userId)
                    .where('read', '==', false)
                    .limit(limit)
                    .get();

                const notifications = [];
                snapshot.forEach(doc => {
                    const data = doc.data();
                    notifications.push({
                        id: doc.id,
                        ...data
                    });
                });

                // 날짜순 정렬
                notifications.sort((a, b) => {
                    const dateA = a.createdAt ? (a.createdAt.toDate ? a.createdAt.toDate() : new Date(a.createdAt)) : new Date(0);
                    const dateB = b.createdAt ? (b.createdAt.toDate ? b.createdAt.toDate() : new Date(b.createdAt)) : new Date(0);
                    return dateB - dateA;
                });

                // 같은 게시물의 알림을 그룹화
                const groupedNotifications = this.groupNotificationsByPost(notifications);
                return groupedNotifications;
            } catch (fallbackError) {
                console.error('❌ 알림 가져오기 fallback 오류:', fallbackError);
                return [];
            }
        }
    },

    // 같은 게시물의 알림을 그룹화
    groupNotificationsByPost(notifications) {
        const grouped = new Map();
        
        notifications.forEach(notification => {
            const key = `${notification.postId}_${notification.type}`;
            
            if (!grouped.has(key)) {
                grouped.set(key, {
                    id: notification.id, // 가장 최근 알림의 ID 사용
                    userId: notification.userId,
                    type: notification.type,
                    postId: notification.postId,
                    postTitle: notification.postTitle,
                    authors: notification.authors || [notification.author], // 첫 번째 사용자
                    count: notification.count || 1, // 반응 개수
                    createdAt: notification.createdAt,
                    commentText: notification.commentText || null,
                    read: notification.read
                });
            } else {
                const existing = grouped.get(key);
                // 같은 타입의 알림이면 개수 증가
                if (notification.type === existing.type) {
                    existing.count = (existing.count || 1) + (notification.count || 1);
                    // 가장 최근 알림의 ID로 업데이트
                    if (notification.createdAt && existing.createdAt) {
                        const newDate = notification.createdAt.toDate ? notification.createdAt.toDate() : new Date(notification.createdAt);
                        const oldDate = existing.createdAt.toDate ? existing.createdAt.toDate() : new Date(existing.createdAt);
                        if (newDate > oldDate) {
                            existing.id = notification.id;
                            existing.createdAt = notification.createdAt;
                            if (notification.commentText) {
                                existing.commentText = notification.commentText;
                            }
                        }
                    }
                    // authors 배열 병합
                    const newAuthors = notification.authors || [notification.author];
                    if (newAuthors && newAuthors.length > 0) {
                        existing.authors = [...new Set([...existing.authors, ...newAuthors])];
                    }
                }
            }
        });
        
        return Array.from(grouped.values());
    },

    // 알림 생성 또는 업데이트 (중복 방지)
    async createOrUpdateNotification(notificationData) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            console.log('🔔 알림 생성/업데이트 시도:', notificationData);

            if (!notificationData.userId) {
                console.error('❌ userId가 없습니다:', notificationData);
                return;
            }

            // 같은 게시물, 같은 타입의 읽지 않은 알림이 있는지 확인
            // 읽은 알림이 있으면 새로 생성하지 않음
            let existingSnapshot;
            let hasReadNotification = false;
            
            try {
                // 같은 게시물, 같은 타입의 모든 알림 조회
                existingSnapshot = await db.collection('notifications')
                    .where('userId', '==', notificationData.userId)
                    .where('postId', '==', notificationData.postId)
                    .where('type', '==', notificationData.type)
                    .limit(10)
                    .get();
                
                // 읽지 않은 알림과 읽은 알림 분리
                const unreadDocs = [];
                existingSnapshot.docs.forEach(doc => {
                    const data = doc.data();
                    if (!data.read) {
                        unreadDocs.push(doc);
                    } else {
                        hasReadNotification = true;
                    }
                });
                
                if (unreadDocs.length > 0) {
                    // 읽지 않은 알림이 있으면 업데이트
                    existingSnapshot = {
                        empty: false,
                        docs: [unreadDocs[0]] // 첫 번째 읽지 않은 알림 사용
                    };
                } else {
                    // 읽지 않은 알림이 없으면
                    if (hasReadNotification) {
                        // 읽은 알림이 있으면 새로 생성하지 않음
                        console.log('ℹ️ 읽은 알림이 이미 있으므로 새 알림을 생성하지 않습니다.');
                        return null;
                    }
                    // 알림이 전혀 없으면 새로 생성
                    existingSnapshot = { empty: true, docs: [] };
                }
            } catch (error) {
                console.error('❌ 알림 조회 오류:', error);
                // 오류 발생 시 새 알림으로 처리
                existingSnapshot = { empty: true, docs: [] };
            }

            if (!existingSnapshot.empty) {
                // 기존 읽지 않은 알림이 있으면 업데이트 (개수 증가)
                const existingDoc = existingSnapshot.docs[0];
                const existingData = existingDoc.data();
                
                // authors 배열에 새 사용자 추가 (중복 방지)
                let authors = existingData.authors || [existingData.author];
                if (!authors.includes(notificationData.author)) {
                    authors.push(notificationData.author);
                }
                
                await existingDoc.ref.update({
                    count: (existingData.count || 1) + 1,
                    authors: authors,
                    createdAt: firebase.firestore.FieldValue.serverTimestamp() // 최신 시간으로 업데이트
                });
                
                console.log('✅ 알림 업데이트 완료 (통합):', existingDoc.id, 'count:', (existingData.count || 1) + 1);
                return existingDoc.id;
            } else {
                // 새 알림 생성 (읽지 않은 알림이 없고, 읽은 알림도 없는 경우)
                const notification = {
                    userId: notificationData.userId,
                    type: notificationData.type,
                    postId: notificationData.postId,
                    postTitle: notificationData.postTitle || '제목 없음',
                    author: notificationData.author,
                    authors: [notificationData.author], // 첫 번째 사용자
                    count: 1, // 반응 개수
                    read: false,
                    createdAt: firebase.firestore.FieldValue.serverTimestamp()
                };

                // 댓글인 경우 댓글 내용도 저장
                if (notificationData.type === 'comment' && notificationData.commentText) {
                    notification.commentText = notificationData.commentText;
                }
                
                // 대댓글인 경우 isReply 플래그 저장
                if (notificationData.isReply === true) {
                    notification.isReply = true;
                }

                const docRef = await db.collection('notifications').add(notification);
                console.log('✅ 새 알림 생성 완료:', docRef.id);
                return docRef.id;
            }
        } catch (error) {
            console.error('❌ 알림 생성/업데이트 오류:', error);
            throw error;
        }
    },

    // 읽지 않은 알림 개수 가져오기
    async getUnreadNotificationCount(userId) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            const snapshot = await db.collection('notifications')
                .where('userId', '==', userId)
                .where('read', '==', false)
                .get();

            return snapshot.size;
        } catch (error) {
            console.error('❌ 읽지 않은 알림 개수 가져오기 오류:', error);
            return 0;
        }
    },

    // 알림 읽음 처리
    async markNotificationAsRead(notificationId) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            await db.collection('notifications').doc(notificationId).update({
                read: true
            });
        } catch (error) {
            console.error('❌ 알림 읽음 처리 오류:', error);
        }
    },

    // 모든 알림 읽음 처리
    async markAllNotificationsAsRead(userId) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            const snapshot = await db.collection('notifications')
                .where('userId', '==', userId)
                .where('read', '==', false)
                .get();

            const batch = db.batch();
            snapshot.forEach(doc => {
                batch.update(doc.ref, { read: true });
            });

            if (snapshot.size > 0) {
                await batch.commit();
            }
        } catch (error) {
            console.error('❌ 모든 알림 읽음 처리 오류:', error);
        }
    },

    // 검색 기능 (서버 측 쿼리 사용)
    async searchPosts(query, limit = 50) {
        try {
            if (!db) {
                await this.waitForFirestore();
            }

            if (!query || query.trim() === '') {
                return [];
            }

            const searchTerm = query.trim();
            const searchTermLower = searchTerm.toLowerCase();
            
            // 각 쿼리를 개별적으로 실행 (인덱스 없이도 작동하도록)
            const postsMap = new Map();
            
            // 1. 태그 검색 (가장 빠름, 인덱스 불필요)
            try {
                const tagResults = await db.collection('posts')
                    .where('tags', 'array-contains', searchTerm)
                    .limit(limit)
                    .get();
                
                tagResults.forEach(doc => {
                    if (!postsMap.has(doc.id)) {
                        const data = doc.data();
                        postsMap.set(doc.id, {
                            id: doc.id,
                            ...data
                        });
                    }
                });
            } catch (tagError) {
                console.warn('태그 검색 오류 (무시):', tagError);
            }
            
            // 2. 제목 검색 (인덱스 필요할 수 있음)
            try {
                const titleResults = await db.collection('posts')
                    .where('title', '>=', searchTerm)
                    .where('title', '<=', searchTerm + '\uf8ff')
                    .limit(limit)
                    .get();
                
                titleResults.forEach(doc => {
                    if (!postsMap.has(doc.id)) {
                        const data = doc.data();
                        postsMap.set(doc.id, {
                            id: doc.id,
                            ...data
                        });
                    }
                });
            } catch (titleError) {
                console.warn('제목 검색 오류 (무시):', titleError);
            }
            
            // 3. 작성자 검색 (인덱스 필요할 수 있음)
            try {
                const authorResults = await db.collection('posts')
                    .where('author', '>=', searchTerm)
                    .where('author', '<=', searchTerm + '\uf8ff')
                    .limit(limit)
                    .get();
                
                authorResults.forEach(doc => {
                    if (!postsMap.has(doc.id)) {
                        const data = doc.data();
                        postsMap.set(doc.id, {
                            id: doc.id,
                            ...data
                        });
                    }
                });
            } catch (authorError) {
                console.warn('작성자 검색 오류 (무시):', authorError);
            }
            
            // 결과가 있으면 부분 일치 필터링 후 반환
            if (postsMap.size > 0) {
                const allPosts = Array.from(postsMap.values());
                
                // 부분 일치 검색을 위한 추가 필터링
                const filteredPosts = allPosts.filter(post => {
                    const title = (post.title || '').toLowerCase();
                    const author = (post.author || '').toLowerCase();
                    const tags = post.tags || [];
                    const tagMatches = tags.some(tag => tag.toLowerCase().includes(searchTermLower));
                    
                    return title.includes(searchTermLower) || 
                           author.includes(searchTermLower) || 
                           tagMatches;
                });

                // 날짜순 정렬
                filteredPosts.sort((a, b) => {
                    const dateA = a.date ? (a.date.toDate ? a.date.toDate() : new Date(a.date)) : new Date(0);
                    const dateB = b.date ? (b.date.toDate ? b.date.toDate() : new Date(b.date)) : new Date(0);
                    return dateB - dateA;
                });

                return filteredPosts.slice(0, limit);
            }
            
            // 쿼리 결과가 없으면 fallback: 클라이언트 측 검색
            console.log('⚠️ 쿼리 검색 결과 없음, 클라이언트 측 검색으로 전환');
            const allPosts = await this.getAllPosts();
            
            return allPosts.filter(post => {
                const title = (post.title || '').toLowerCase();
                const author = (post.author || '').toLowerCase();
                const tags = post.tags || [];
                const tagMatches = tags.some(tag => tag.toLowerCase().includes(searchTermLower));
                
                return title.includes(searchTermLower) || 
                       author.includes(searchTermLower) || 
                       tagMatches;
            }).slice(0, limit);
            
        } catch (error) {
            console.error('❌ 검색 오류:', error);
            // 최종 fallback: 클라이언트 측 검색
            try {
                const allPosts = await this.getAllPosts();
                const searchTermLower = query.trim().toLowerCase();
                
                return allPosts.filter(post => {
                    const title = (post.title || '').toLowerCase();
                    const author = (post.author || '').toLowerCase();
                    const tags = post.tags || [];
                    const tagMatches = tags.some(tag => tag.toLowerCase().includes(searchTermLower));
                    
                    return title.includes(searchTermLower) || 
                           author.includes(searchTermLower) || 
                           tagMatches;
                }).slice(0, limit);
            } catch (fallbackError) {
                console.error('❌ Fallback 검색도 실패:', fallbackError);
                return [];
            }
        }
    },

    // 코인 지급 함수
    async addCoins(userId, amount, type, postId = null) {
        try {
            console.log('💰 addCoins 함수 호출:', { userId, amount, type, postId });
            
            if (!db) {
                throw new Error('Firestore가 초기화되지 않았습니다.');
            }
            
            if (!userId || !amount || !type) {
                throw new Error(`필수 파라미터가 누락되었습니다. userId: ${userId}, amount: ${amount}, type: ${type}`);
            }

            console.log('📝 사용자 문서 조회 시작:', userId);
            const userRef = db.collection('users').doc(userId);
            const userDoc = await userRef.get();

            if (!userDoc.exists) {
                console.error('❌ 사용자 문서가 없습니다:', userId);
                throw new Error(`사용자 문서가 없습니다: ${userId}`);
            }

            const userData = userDoc.data();
            const currentCoins = userData.coins || 0;
            const newCoins = currentCoins + amount;

            console.log('💰 코인 업데이트:', {
                userId: userId,
                currentCoins: currentCoins,
                amount: amount,
                newCoins: newCoins
            });

            // 코인 업데이트
            await userRef.update({
                coins: newCoins
            });
            console.log('✅ 코인 업데이트 완료');

            // 코인 내역 추가
            const historyData = {
                userId: userId,
                amount: amount,
                type: type,
                timestamp: firebase.firestore.FieldValue.serverTimestamp()
            };

            if (postId) {
                historyData.postId = postId;
            }

            console.log('📝 코인 내역 추가 시작:', historyData);
            await db.collection('coinHistory').add(historyData);
            console.log('✅ 코인 내역 추가 완료');

            console.log(`✅ 코인 지급 완료: ${userId}, ${amount}코인, ${type}`);
            return { success: true, newCoins: newCoins };
        } catch (error) {
            console.error('❌ 코인 지급 오류:', error);
            console.error('오류 상세:', {
                message: error.message,
                code: error.code,
                stack: error.stack,
                userId: userId,
                amount: amount,
                type: type
            });
            throw error;
        }
    },

    // 사용자명으로 UID 찾기
    async getUserIdByUsername(username) {
        try {
            if (!db || !username) {
                return null;
            }

            const snapshot = await db.collection('users')
                .where('name', '==', username)
                .limit(1)
                .get();

            if (snapshot.empty) {
                return null;
            }

            return snapshot.docs[0].id;
        } catch (error) {
            console.error('❌ 사용자 UID 찾기 오류:', error);
            return null;
        }
    }
};

// 전역 접근을 위해 window 객체에 추가
window.dataManager = dataManager;
