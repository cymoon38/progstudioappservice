// Firebase Authentication 관련 기능

// 탭 전환 기능
document.addEventListener('DOMContentLoaded', function() {
    const loginTab = document.getElementById('loginTab');
    const signupTab = document.getElementById('signupTab');
    const loginForm = document.getElementById('loginForm');
    const signupForm = document.getElementById('signupForm');

    if (loginTab && signupTab) {
        // 로그인 탭 클릭
        loginTab.addEventListener('click', function() {
            loginTab.classList.add('active');
            signupTab.classList.remove('active');
            loginForm.classList.add('active');
            signupForm.classList.remove('active');
            clearErrors();
        });

        // 회원가입 탭 클릭
        signupTab.addEventListener('click', function() {
            signupTab.classList.add('active');
            loginTab.classList.remove('active');
            signupForm.classList.add('active');
            loginForm.classList.remove('active');
            clearErrors();
        });
    }

    // 로그인 폼 제출
    const loginFormElement = document.getElementById('loginForm');
    if (loginFormElement) {
        loginFormElement.addEventListener('submit', async function(e) {
            e.preventDefault();
            const email = document.getElementById('loginEmail').value.trim();
            const password = document.getElementById('loginPassword').value;

            try {
                await signIn(email, password);
                // 로그인 성공 후 폼 초기화
                loginFormElement.reset();
            } catch (error) {
                showError('loginError', error.message);
            }
        });
    }

    // 실시간 아이디 중복 체크
    const signupNameInput = document.getElementById('signupName');
    let nameCheckTimeout = null;
    if (signupNameInput) {
        signupNameInput.addEventListener('input', async function() {
            const name = this.value.trim();
            const errorElement = document.getElementById('signupError');
            
            // 이전 타이머 취소
            if (nameCheckTimeout) {
                clearTimeout(nameCheckTimeout);
            }
            
            // 입력이 없으면 오류 메시지 숨기기
            if (!name) {
                if (errorElement) {
                    errorElement.style.display = 'none';
                }
                return;
            }
            
            // 500ms 후에 중복 체크 (입력이 멈춘 후)
            nameCheckTimeout = setTimeout(async function() {
                try {
                    // Firebase 초기화 대기
                    if (!window.dataManager) {
                        await new Promise(resolve => {
                            let attempts = 0;
                            const checkInterval = setInterval(() => {
                                attempts++;
                                if (window.dataManager) {
                                    clearInterval(checkInterval);
                                    resolve();
                                } else if (attempts >= 50) {
                                    clearInterval(checkInterval);
                                    resolve();
                                }
                            }, 100);
                        });
                    }
                    
                    if (window.dataManager) {
                        const userExists = await window.dataManager.checkUserExists(name);
                        if (userExists) {
                            showError('signupError', '이미 사용 중인 닉네임입니다.');
                        } else {
                            // 중복이 아니면 오류 메시지 숨기기 (닉네임 관련 오류만)
                            if (errorElement && errorElement.textContent.includes('닉네임')) {
                                errorElement.style.display = 'none';
                            }
                        }
                    }
                } catch (error) {
                    console.error('아이디 중복 체크 오류:', error);
                }
            }, 500);
        });
    }

    // 실시간 이메일 중복 체크
    const signupEmailInput = document.getElementById('signupEmail');
    let emailCheckTimeout = null;
    if (signupEmailInput) {
        signupEmailInput.addEventListener('input', async function() {
            const email = this.value.trim();
            const errorElement = document.getElementById('signupError');
            
            // 이전 타이머 취소
            if (emailCheckTimeout) {
                clearTimeout(emailCheckTimeout);
            }
            
            // 입력이 없으면 오류 메시지 숨기기
            if (!email) {
                if (errorElement && errorElement.textContent.includes('이메일')) {
                    errorElement.style.display = 'none';
                }
                return;
            }
            
            // 이메일 형식 검증
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(email)) {
                return; // 형식이 맞지 않으면 중복 체크 안 함
            }
            
            // 500ms 후에 중복 체크 (입력이 멈춘 후)
            emailCheckTimeout = setTimeout(async function() {
                try {
                    // Firebase 초기화 대기
                    if (!window.dataManager) {
                        await new Promise(resolve => {
                            let attempts = 0;
                            const checkInterval = setInterval(() => {
                                attempts++;
                                if (window.dataManager) {
                                    clearInterval(checkInterval);
                                    resolve();
                                } else if (attempts >= 50) {
                                    clearInterval(checkInterval);
                                    resolve();
                                }
                            }, 100);
                        });
                    }
                    
                    if (window.dataManager) {
                        const emailExists = await window.dataManager.checkEmailExists(email);
                        if (emailExists) {
                            showError('signupError', '이미 사용 중인 이메일입니다.');
                        } else {
                            // 중복이 아니면 오류 메시지 숨기기 (이메일 관련 오류만)
                            if (errorElement && errorElement.textContent.includes('이메일')) {
                                errorElement.style.display = 'none';
                            }
                        }
                    }
                } catch (error) {
                    console.error('이메일 중복 체크 오류:', error);
                }
            }, 500);
        });
    }

    // 회원가입 폼 제출
    const signupFormElement = document.getElementById('signupForm');
    if (signupFormElement) {
        signupFormElement.addEventListener('submit', async function(e) {
            e.preventDefault();
            const name = document.getElementById('signupName').value.trim();
            const email = document.getElementById('signupEmail').value.trim();
            const password = document.getElementById('signupPassword').value;
            const passwordConfirm = document.getElementById('signupPasswordConfirm').value;

            // 모든 필드 필수 입력 확인
            if (!name) {
                showError('signupError', '닉네임을 입력해주세요.');
                return;
            }

            if (!email) {
                showError('signupError', '이메일을 입력해주세요.');
                return;
            }

            if (!password) {
                showError('signupError', '비밀번호를 입력해주세요.');
                return;
            }

            if (!passwordConfirm) {
                showError('signupError', '비밀번호 확인을 입력해주세요.');
                return;
            }

            // 비밀번호 확인
            if (password !== passwordConfirm) {
                showError('signupError', '비밀번호가 일치하지 않습니다.');
                return;
            }

            if (password.length < 6) {
                showError('signupError', '비밀번호는 최소 6자 이상이어야 합니다.');
                return;
            }

            // Firebase 초기화 대기
            let attempts = 0;
            while ((!window.dataManager || !db) && attempts < 100) {
                await new Promise(resolve => setTimeout(resolve, 100));
                attempts++;
            }

            // 아이디(닉네임) 중복 체크
            if (!window.dataManager || !db) {
                console.error('❌ dataManager 또는 db 초기화 실패');
                showError('signupError', '시스템 초기화 중입니다. 잠시 후 다시 시도해주세요.');
                return;
            }

            try {
                console.log('🔍 닉네임 중복 체크 시작:', name);
                const nameExists = await window.dataManager.checkUserExists(name);
                if (nameExists) {
                    console.log('❌ 닉네임 중복:', name);
                    showError('signupError', '이미 사용 중인 닉네임입니다. 다른 닉네임을 선택해주세요.');
                    return;
                }
                console.log('✅ 닉네임 사용 가능:', name);
            } catch (error) {
                console.error('❌ 닉네임 중복 체크 오류:', error);
                showError('signupError', '닉네임 중복 확인 중 오류가 발생했습니다. 다시 시도해주세요.');
                return;
            }

            // 이메일 중복 체크 (Firestore users 컬렉션에서)
            try {
                console.log('🔍 이메일 중복 체크 시작:', email);
                const emailExists = await window.dataManager.checkEmailExists(email);
                if (emailExists) {
                    console.log('❌ 이메일 중복:', email);
                    showError('signupError', '이미 사용 중인 이메일입니다. 다른 이메일을 사용해주세요.');
                    return;
                }
                console.log('✅ 이메일 사용 가능:', email);
            } catch (error) {
                console.error('❌ 이메일 중복 체크 오류:', error);
                showError('signupError', '이메일 중복 확인 중 오류가 발생했습니다. 다시 시도해주세요.');
                return;
            }

            try {
                await signUp(email, password, name);
                // 회원가입 성공 후 폼 초기화
                signupFormElement.reset();
            } catch (error) {
                showError('signupError', error.message);
            }
        });
    }

    // 현재 사용자 상태 확인
    checkAuthState();
});

// 에러 메시지 표시
function showError(elementId, message) {
    const errorElement = document.getElementById(elementId);
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.style.display = 'block';
    }
}

// 에러 메시지 숨기기
function clearErrors() {
    const loginError = document.getElementById('loginError');
    const signupError = document.getElementById('signupError');
    if (loginError) loginError.style.display = 'none';
    if (signupError) signupError.style.display = 'none';
}

// 회원가입 함수
async function signUp(email, password, name) {
    try {
        // Firebase Auth 초기화 확인
        if (!firebaseAuth) {
            await waitForFirebase();
        }

        // 아이디(닉네임) 중복 최종 체크 (서버 측 - 이중 확인)
        if (db && window.dataManager) {
            console.log('🔍 최종 닉네임 중복 체크:', name);
            const nameExists = await window.dataManager.checkUserExists(name);
            if (nameExists) {
                console.log('❌ 최종 닉네임 중복 확인:', name);
                throw new Error('이미 사용 중인 닉네임입니다. 다른 닉네임을 선택해주세요.');
            }
            console.log('✅ 최종 닉네임 사용 가능:', name);
        }

        // 이메일 중복 최종 체크 (Firestore users 컬렉션에서)
        if (db && window.dataManager) {
            console.log('🔍 최종 이메일 중복 체크:', email);
            const emailExists = await window.dataManager.checkEmailExists(email);
            if (emailExists) {
                console.log('❌ 최종 이메일 중복 확인:', email);
                throw new Error('이미 사용 중인 이메일입니다. 다른 이메일을 사용해주세요.');
            }
            console.log('✅ 최종 이메일 사용 가능:', email);
        }

        // Firebase Auth 회원가입 (이메일 중복 체크 포함)
        console.log('🚀 Firebase Auth 회원가입 시작');
        const userCredential = await firebaseAuth.createUserWithEmailAndPassword(email, password);
        const user = userCredential.user;
        console.log('✅ Firebase Auth 회원가입 성공:', user.uid);

        // 사용자 프로필 업데이트 (닉네임)
        await user.updateProfile({
            displayName: name
        });

        // Firestore에 사용자 정보 저장 (트랜잭션 사용하여 중복 방지)
        if (db) {
            // 다시 한 번 중복 체크 (트랜잭션 전)
            const finalNameCheck = await window.dataManager.checkUserExists(name);
            if (finalNameCheck) {
                // 이미 생성된 Auth 계정 삭제
                await user.delete();
                throw new Error('이미 사용 중인 닉네임입니다. 다른 닉네임을 선택해주세요.');
            }

            await db.collection('users').doc(user.uid).set({
                name: name,
                email: email.toLowerCase(), // 소문자로 저장
                createdAt: firebase.firestore.FieldValue.serverTimestamp(),
                postCount: 0
            });
            console.log('✅ Firestore 사용자 정보 저장 완료');
        }

        // 캐시 초기화 (새 사용자 추가됨)
        if (window.dataManager && window.dataManager.clearUserCache) {
            window.dataManager.clearUserCache(name);
        }

        console.log('✅ 회원가입 완료:', user.email);
        
        // 로그인 성공 후 메인 페이지로 이동
        window.location.href = 'index.html';
    } catch (error) {
        console.error('❌ 회원가입 오류:', error);
        let errorMessage = '회원가입에 실패했습니다.';
        
        if (error.code === 'auth/email-already-in-use') {
            errorMessage = '이미 사용 중인 이메일입니다.';
        } else if (error.code === 'auth/invalid-email') {
            errorMessage = '유효하지 않은 이메일 형식입니다.';
        } else if (error.code === 'auth/weak-password') {
            errorMessage = '비밀번호가 너무 약합니다. (최소 6자)';
        } else if (error.message.includes('닉네임') || error.message.includes('이메일')) {
            errorMessage = error.message;
        }
        
        throw new Error(errorMessage);
    }
}

// 로그인 함수
async function signIn(email, password) {
    try {
        // Firebase Auth 초기화 확인
        if (!firebaseAuth) {
            await waitForFirebase();
        }

        await firebaseAuth.signInWithEmailAndPassword(email, password);
        console.log('✅ 로그인 성공');
        
        // 로그인 성공 후 메인 페이지로 이동
        window.location.href = 'index.html';
    } catch (error) {
        console.error('❌ 로그인 오류:', error);
        let errorMessage = '로그인에 실패했습니다.';
        
        if (error.code === 'auth/user-not-found') {
            errorMessage = '등록되지 않은 이메일입니다.';
        } else if (error.code === 'auth/wrong-password') {
            errorMessage = '비밀번호가 일치하지 않습니다.';
        } else if (error.code === 'auth/invalid-email') {
            errorMessage = '유효하지 않은 이메일 형식입니다.';
        } else if (error.code === 'auth/user-disabled') {
            errorMessage = '비활성화된 계정입니다.';
        }
        
        throw new Error(errorMessage);
    }
}

// 로그아웃 함수
async function signOut() {
    try {
        if (!firebaseAuth) {
            await waitForFirebase();
        }
        
        await firebaseAuth.signOut();
        console.log('✅ 로그아웃 성공');
        window.location.href = 'index.html';
    } catch (error) {
        console.error('❌ 로그아웃 오류:', error);
    }
}

// 현재 인증 상태 확인
function checkAuthState() {
    // Firebase가 로드될 때까지 대기
    if (typeof firebase === 'undefined') {
        setTimeout(checkAuthState, 50); // 100ms에서 50ms로 단축
        return;
    }

    if (!firebaseAuth) {
        setTimeout(checkAuthState, 50); // 100ms에서 50ms로 단축
        return;
    }

    // 즉시 현재 사용자 확인하여 빠르게 네비게이션 업데이트 (페이지 전환 시 지연 감소)
    const currentUser = firebaseAuth.currentUser;
    // 라우터 네비게이션 중이면 업데이트 건너뛰기
    if (!window.isRouterNavigation) {
        if (window.updateNavigation) {
            window.updateNavigation(currentUser);
        } else if (typeof updateNavigation === 'function') {
            updateNavigation(currentUser);
        }
    }

    // 로그인 상태를 localStorage에 저장 (다음 페이지 로드 시 빠른 표시)
    if (currentUser) {
        try {
            localStorage.setItem('lastAuthState', 'logged_in');
        } catch (e) {
            // localStorage 접근 실패 시 무시
        }
    } else {
        try {
            localStorage.setItem('lastAuthState', 'logged_out');
        } catch (e) {
            // localStorage 접근 실패 시 무시
        }
    }

    // 비동기로 최신 상태 확인 (onAuthStateChanged는 비동기이므로 나중에 업데이트)
    firebaseAuth.onAuthStateChanged(function(user) {
        // 로그인 상태를 localStorage에 저장
        try {
            localStorage.setItem('lastAuthState', user ? 'logged_in' : 'logged_out');
        } catch (e) {
            // localStorage 접근 실패 시 무시
        }
        if (user) {
            console.log('✅ 현재 로그인된 사용자:', user.email);
            // 모든 페이지에서 네비게이션 업데이트 (라우터 네비게이션 중이면 건너뛰기)
            if (!window.isRouterNavigation) {
                if (window.updateNavigation) {
                    window.updateNavigation(user);
                } else {
                    // window.updateNavigation이 없으면 fallback
                    updateNavigation(user);
                }
            }
        } else {
            console.log('ℹ️ 로그인되지 않은 상태');
            // 모든 페이지에서 네비게이션 업데이트 (라우터 네비게이션 중이면 건너뛰기)
            if (!window.isRouterNavigation) {
                if (window.updateNavigation) {
                    window.updateNavigation(null);
                } else {
                    // window.updateNavigation이 없으면 fallback
                    updateNavigation(null);
                }
            }
        }
    });
}

// 네비게이션 업데이트 (index.html에만 적용)
function updateNavigation(user) {
    const loginLink = document.getElementById('loginLink');
    const profileDropdown = document.getElementById('profileDropdown');
    const logoutBtn = document.getElementById('logoutBtn');

    if (user) {
        // 로그인된 경우: 로그인 버튼 숨기고 프로필 드롭다운 표시
        if (loginLink) loginLink.style.display = 'none';
        if (profileDropdown) profileDropdown.style.display = 'block';
        
        // 로그아웃 버튼 이벤트
        if (logoutBtn) {
            logoutBtn.addEventListener('click', function(e) {
                e.preventDefault();
                signOut();
            });
        }

        // 프로필 아이콘 클릭 이벤트
        const profileIcon = document.getElementById('profileIcon');
        const dropdownMenu = document.getElementById('dropdownMenu');
        
        if (profileIcon && dropdownMenu) {
            profileIcon.addEventListener('click', function(e) {
                e.stopPropagation();
                dropdownMenu.style.display = dropdownMenu.style.display === 'block' ? 'none' : 'block';
            });

            // 외부 클릭 시 드롭다운 닫기
            document.addEventListener('click', function(e) {
                if (!profileDropdown.contains(e.target)) {
                    dropdownMenu.style.display = 'none';
                }
            });
        }
    } else {
        // 로그인되지 않은 경우: 프로필 드롭다운 숨기고 로그인 버튼 표시
        if (profileDropdown) profileDropdown.style.display = 'none';
        if (loginLink) loginLink.style.display = 'block';
    }
}

// Firebase 초기화 대기 함수
function waitForFirebase() {
    return new Promise((resolve, reject) => {
        let attempts = 0;
        const maxAttempts = 50; // 5초 대기

        const checkInterval = setInterval(() => {
            attempts++;
            
            if (firebaseAuth) {
                clearInterval(checkInterval);
                resolve();
            } else if (attempts >= maxAttempts) {
                clearInterval(checkInterval);
                reject(new Error('Firebase 초기화에 실패했습니다.'));
            }
        }, 100);
    });
}

// 현재 사용자 정보 가져오기
function getCurrentUser() {
    if (!firebaseAuth) {
        return null;
    }
    return firebaseAuth.currentUser;
}

// authManager 객체 (다른 페이지에서 사용)
const authManager = {
    // 인증 상태 변화 감지
    onAuthStateChanged(callback) {
        if (!firebaseAuth) {
            setTimeout(() => this.onAuthStateChanged(callback), 100);
            return;
        }
        
        firebaseAuth.onAuthStateChanged(async function(user) {
            if (user) {
                // 사용자 정보 가져오기
                if (db) {
                    try {
                        const userDoc = await db.collection('users').doc(user.uid).get();
                        if (userDoc.exists) {
                            const userData = userDoc.data();
                            user.username = userData.name;
                        } else {
                            user.username = user.displayName || user.email.split('@')[0];
                        }
                    } catch (error) {
                        console.error('사용자 정보 가져오기 오류:', error);
                        user.username = user.displayName || user.email.split('@')[0];
                    }
                } else {
                    user.username = user.displayName || user.email.split('@')[0];
                }
                user.uid = user.uid;
            }
            callback(user);
        });
    },

    // 현재 사용자 가져오기 (async)
    async getCurrentUserAsync() {
        if (!firebaseAuth) {
            await waitForFirebase();
        }
        
        const user = firebaseAuth.currentUser;
        if (!user) {
            return null;
        }

        // 사용자 정보 가져오기
        if (db) {
            try {
                const userDoc = await db.collection('users').doc(user.uid).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    return {
                        uid: user.uid,
                        email: user.email,
                        displayName: user.displayName,
                        username: userData.name,
                        ...userData
                    };
                }
            } catch (error) {
                console.error('사용자 정보 가져오기 오류:', error);
            }
        }
        
        return {
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            username: user.displayName || user.email.split('@')[0]
        };
    },

    // 로그인 여부 확인
    isLoggedIn() {
        if (!firebaseAuth) {
            return false;
        }
        return firebaseAuth.currentUser !== null;
    }
};

// auth 객체 (간단한 함수들)
const auth = {
    // 현재 사용자 가져오기 (async)
    async getCurrentUserAsync() {
        return await authManager.getCurrentUserAsync();
    },

    // 로그인 여부 확인
    isLoggedIn() {
        return authManager.isLoggedIn();
    },

    // 로그아웃
    async signOut() {
        return await signOut();
    }
};

// 전역 접근을 위해 window 객체에 추가
window.authManager = authManager;
window.auth = auth;
