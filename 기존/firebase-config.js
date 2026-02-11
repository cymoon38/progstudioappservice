// Firebase 설정 파일
// Firebase Console (https://console.firebase.google.com)에서 프로젝트 생성 후
// 설정 > 프로젝트 설정 > 앱 추가 > 웹 앱에서 아래 값들을 복사해서 넣어주세요

const firebaseConfig = {
    apiKey: "AIzaSyADNSIqYGqtFooPK9MjX4_UrLNoY0hcu4M",
    authDomain: "community-b19fb.firebaseapp.com",
    projectId: "community-b19fb",
    storageBucket: "community-b19fb.firebasestorage.app",
    messagingSenderId: "807594698988",
    appId: "1:807594698988:web:3bf482c3e1d88df5d09dc9",
    measurementId: "G-3YW94NCEJM"
};

// Firebase 초기화 (즉시 실행)
(function() {
    function initializeFirebase() {
        try {
            if (typeof firebase === 'undefined') {
                console.error('❌ Firebase SDK가 로드되지 않았습니다.');
                return false;
            }

            // Firebase 초기화
            if (firebase.apps.length === 0) {
                firebase.initializeApp(firebaseConfig);
                console.log('✅ Firebase 초기화 성공');
            } else {
                console.log('ℹ️ Firebase가 이미 초기화되었습니다.');
            }
            
            // Firebase 서비스 참조 (전역 변수로 설정)
            db = firebase.firestore();
            storage = firebase.storage();
            firebaseAuth = firebase.auth();
            
            // window 객체에도 설정 (이중 보장)
            window.db = db;
            window.storage = storage;
            window.firebaseAuth = firebaseAuth;
            
            console.log('✅ Firebase 서비스 초기화 성공');
            return true;
        } catch (error) {
            console.error('❌ Firebase 초기화 오류:', error);
            console.error('Firebase Console에서 Authentication을 활성화했는지 확인하세요.');
            return false;
        }
    }
    
    // 즉시 초기화 시도
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeFirebase);
    } else {
        initializeFirebase();
    }
    
    // SDK 로드 대기 후 재시도
    if (typeof firebase === 'undefined') {
        window.addEventListener('load', function() {
            setTimeout(initializeFirebase, 100);
        });
    }
})();

// 전역 변수 선언 (다른 파일에서 사용)
var db, storage, firebaseAuth;

