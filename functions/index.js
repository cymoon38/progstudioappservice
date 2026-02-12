const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

const db = admin.firestore();

// 기프트쇼비즈 API 설정
const GIFTSHOWBIZ_BASE_URL = 'https://bizapi.giftishow.com/bizApi';

// 환경 변수에서 Secret 가져오기
// Firebase Console > Functions > 설정 > 환경 변수에서 설정
function getSecret(secretName) {
  // 상용환경 키 사용 (나중에 환경 변수로 변경)
  if (secretName === 'GIFTSHOWBIZ_AUTH_CODE') {
    return 'REAL56bf67edd37e4733af8ddba2d5387150';
  }
  if (secretName === 'GIFTSHOWBIZ_AUTH_TOKEN') {
    return '3RXSN9gtle+bE63cH3vnSg==';
  }
  // 환경 변수에서 가져오기 (배포 시 설정)
  return process.env[secretName] || '';
}

// 오늘 날짜를 YYYY-MM-DD 형식으로 반환 (한국 시간 기준)
function getTodayDateString() {
  // 한국 시간(UTC+9)으로 현재 날짜 계산
  const now = new Date();
  const koreaTime = new Date(now.toLocaleString('en-US', {timeZone: 'Asia/Seoul'}));
  const year = koreaTime.getFullYear();
  const month = String(koreaTime.getMonth() + 1).padStart(2, '0');
  const day = String(koreaTime.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

// 게시물 작성자 UID 목록 가져오기 (중복 제거)
async function getPostAuthors(posts) {
  const authorUids = new Set();
  
  for (const post of posts) {
    if (post.authorUid && post.authorUid.length > 0) {
      authorUids.add(post.authorUid);
    } else if (post.author && post.author.length > 0) {
      // authorUid가 없으면 author 이름으로 UID 찾기
      try {
        const userQuery = await db
            .collection('users')
            .where('name', '==', post.author)
            .limit(1)
            .get();
        
        if (!userQuery.empty) {
          authorUids.add(userQuery.docs[0].id);
        }
      } catch (e) {
        console.error(`사용자 UID 찾기 오류: ${e} (author: ${post.author})`);
      }
    }
  }
  
  return authorUids;
}

// 코인 지급
async function addCoins(userId, amount, type, notificationMessage = null) {
  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new Error(`사용자 문서가 없습니다: ${userId}`);
    }
    
    const userData = userDoc.data();
    const currentCoins = userData.coins || 0;
    const newCoins = currentCoins + amount;
    
    await userRef.update({ coins: newCoins });
    
    await db.collection('coinHistory').add({
      userId: userId,
      amount: amount,
      type: type,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // 알림 생성
    if (notificationMessage) {
      try {
        await db.collection('notifications').add({
          userId: userId,
          type: 'coin_reward',
          message: notificationMessage,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          amount: amount,
          rewardType: type,
        });
        console.log(`🔔 알림 생성: ${userId} - ${notificationMessage}`);
      } catch (e) {
        console.error(`알림 생성 오류 (무시): ${e}`);
      }
    }
    
    console.log(`✅ 코인 지급 완료: ${userId} - ${amount}코인 (${type})`);
    return newCoins;
  } catch (e) {
    console.error(`코인 지급 오류: ${e}`);
    throw e;
  }
}

// 추첨 실행
async function runLottery() {
  try {
    const today = getTodayDateString();
    
    // 오늘 추첨이 이미 실행되었는지 확인
    const lotteryDoc = await db.collection('lotteryResults').doc(today).get();
    if (lotteryDoc.exists) {
      const data = lotteryDoc.data();
      // popularWinner와 normalWinner가 모두 있으면 추첨 완료
      if (data.popularWinner || data.normalWinner) {
        console.log('📋 오늘 추첨은 이미 실행되었습니다.');
        return null;
      }
    }
    
    console.log('🎲 추첨 시작...');
    
    // 한국 시간 기준으로 어제 오후 5시부터 오늘 오후 5시까지 계산
    // 현재 시간을 한국 시간으로 변환하여 오늘 날짜 확인
    const now = new Date();
    const koreaNow = new Date(now.toLocaleString('en-US', {timeZone: 'Asia/Seoul'}));
    const koreaYear = koreaNow.getFullYear();
    const koreaMonth = koreaNow.getMonth();
    const koreaDate = koreaNow.getDate();
    
    // 오늘 오후 5시 (17:00:00) - 한국 시간을 ISO 8601 형식으로 생성
    // 한국 시간대(+09:00)를 명시하여 정확한 시간 계산
    const today5PMKoreaStr = `${koreaYear}-${String(koreaMonth + 1).padStart(2, '0')}-${String(koreaDate).padStart(2, '0')}T17:00:00+09:00`;
    const today5PMKorea = new Date(today5PMKoreaStr);
    // UTC로 변환 (한국 시간에서 9시간 빼기)
    const today5PMUTC = new Date(today5PMKorea.getTime() - 9 * 60 * 60 * 1000);
    
    // 어제 날짜 계산
    const yesterdayKorea = new Date(koreaYear, koreaMonth, koreaDate - 1);
    const yesterdayYear = yesterdayKorea.getFullYear();
    const yesterdayMonth = yesterdayKorea.getMonth();
    const yesterdayDate = yesterdayKorea.getDate();
    
    // 어제 오후 5시 (17:00:00) - 한국 시간을 ISO 8601 형식으로 생성
    const yesterday5PMKoreaStr = `${yesterdayYear}-${String(yesterdayMonth + 1).padStart(2, '0')}-${String(yesterdayDate).padStart(2, '0')}T17:00:00+09:00`;
    const yesterday5PMKorea = new Date(yesterday5PMKoreaStr);
    // UTC로 변환
    const yesterday5PMUTC = new Date(yesterday5PMKorea.getTime() - 9 * 60 * 60 * 1000);
    
    // Firestore Timestamp로 변환
    const startTime = admin.firestore.Timestamp.fromDate(yesterday5PMUTC);
    const endTime = admin.firestore.Timestamp.fromDate(today5PMUTC);
    
    console.log(`📅 추첨 대상 기간: 어제 오후 5시 (${yesterday5PMUTC.toISOString()}) ~ 오늘 오후 5시 (${today5PMUTC.toISOString()})`);
    console.log(`📅 한국 시간 기준: ${yesterday5PMKoreaStr.replace('T', ' ').replace('+09:00', '')} ~ ${today5PMKoreaStr.replace('T', ' ').replace('+09:00', '')}`);
    
    // 1. 인기작품에서 먼저 추첨 (어제 오후 5시 ~ 오늘 오후 5시 사이 게시물)
    const popularPostsSnapshot = await db
        .collection('posts')
        .where('isPopular', '==', true)
        .where('type', '!=', 'notice') // 공지사항 제외
        .where('date', '>=', startTime) // 어제 오후 5시 이후
        .where('date', '<', endTime) // 오늘 오후 5시 이전
        .get();
    
    const popularPosts = popularPostsSnapshot.docs
        .map(doc => ({
          id: doc.id,
          author: doc.data().author || '',
          authorUid: doc.data().authorUid || null,
          type: doc.data().type || null,
        }))
        .filter(post => post.authorUid || post.author);
    
    console.log(`📊 인기작품 수: ${popularPosts.length}`);
    
    let popularWinnerUid = null;
    let popularWinnerName = null;
    let popularWinnerPostId = null;
    
    if (popularPosts.length > 0) {
      const popularAuthors = await getPostAuthors(popularPosts);
      console.log(`📊 인기작품 작성자 수: ${popularAuthors.size}`);
      
      if (popularAuthors.size > 0) {
        const winnerList = Array.from(popularAuthors);
        const winnerIndex = Math.floor(Math.random() * winnerList.length);
        popularWinnerUid = winnerList[winnerIndex];
        
        // 당첨자 이름 찾기
        try {
          const winnerDoc = await db.collection('users').doc(popularWinnerUid).get();
          if (winnerDoc.exists) {
            popularWinnerName = winnerDoc.data().name || '알 수 없음';
          }
        } catch (e) {
          console.error(`당첨자 이름 찾기 오류: ${e}`);
          popularWinnerName = '알 수 없음';
        }
        
        // 당첨자의 인기작품 중 하나를 랜덤 선택
        const winnerPosts = popularPosts.filter(post => post.authorUid === popularWinnerUid || 
          (post.authorUid === null && post.author === popularWinnerName));
        if (winnerPosts.length > 0) {
          const postIndex = Math.floor(Math.random() * winnerPosts.length);
          popularWinnerPostId = winnerPosts[postIndex].id;
        }
        
        // 인기작품 당첨자에게 500코인 지급
        await addCoins(
          popularWinnerUid, 
          500, 
          '오늘의 당첨자 보상',
          `${popularWinnerName}님, 오늘의 당첨자 보상으로 500코인을 받았습니다!`
        );
        console.log(`🎉 인기작품 추첨 당첨자: ${popularWinnerName} (${popularWinnerUid}) - 게시물: ${popularWinnerPostId} - 500코인 지급`);
      }
    }
    
    // 2. 일반 작품에서 추첨 (인기작품 당첨자 제외, 어제 오후 5시 ~ 오늘 오후 5시 사이 게시물)
    const generalPostsSnapshot = await db
        .collection('posts')
        .where('isPopular', '==', false) // 인기작품이 아닌 것
        .where('type', '!=', 'notice') // 공지사항 제외
        .where('date', '>=', startTime) // 어제 오후 5시 이후
        .where('date', '<', endTime) // 오늘 오후 5시 이전
        .get();
    
    const generalPosts = generalPostsSnapshot.docs
        .map(doc => ({
          id: doc.id,
          author: doc.data().author || '',
          authorUid: doc.data().authorUid || null,
          type: doc.data().type || null,
          isPopular: doc.data().isPopular || false,
        }))
        .filter(post => post.authorUid || post.author);
    
    console.log(`📊 일반작품 수: ${generalPosts.length}`);
    
    let normalWinnerUid = null;
    let normalWinnerName = null;
    let normalWinnerPostId = null;
    
    if (generalPosts.length > 0) {
      
      const allAuthors = await getPostAuthors(generalPosts);
      
      // 인기작품 당첨자 제외
      const normalAuthors = popularWinnerUid
          ? Array.from(allAuthors).filter(uid => uid !== popularWinnerUid)
          : Array.from(allAuthors);
      
      console.log(`📊 일반작품 작성자 수 (인기작품 당첨자 제외): ${normalAuthors.length}`);
      
      if (normalAuthors.length > 0) {
        const winnerIndex = Math.floor(Math.random() * normalAuthors.length);
        normalWinnerUid = normalAuthors[winnerIndex];
        
        // 당첨자 이름 찾기
        try {
          const winnerDoc = await db.collection('users').doc(normalWinnerUid).get();
          if (winnerDoc.exists) {
            normalWinnerName = winnerDoc.data().name || '알 수 없음';
          }
        } catch (e) {
          console.error(`당첨자 이름 찾기 오류: ${e}`);
          normalWinnerName = '알 수 없음';
        }
        
        // 당첨자의 일반작품 중 하나를 랜덤 선택
        const winnerPosts = generalPosts.filter(post => 
          (post.authorUid === normalWinnerUid) || 
          (post.authorUid === null && post.author === normalWinnerName));
        if (winnerPosts.length > 0) {
          const postIndex = Math.floor(Math.random() * winnerPosts.length);
          normalWinnerPostId = winnerPosts[postIndex].id;
        }
        
        // 일반작품 당첨자에게 300코인 지급
        await addCoins(
          normalWinnerUid, 
          300, 
          '오늘의 당첨자 보상',
          `${normalWinnerName}님, 오늘의 당첨자 보상으로 300코인을 받았습니다!`
        );
        console.log(`🎉 일반작품 추첨 당첨자: ${normalWinnerName} (${normalWinnerUid}) - 게시물: ${normalWinnerPostId} - 300코인 지급`);
      }
    }
    
    // 추첨 결과 저장
    await db.collection('lotteryResults').doc(today).set({
      date: today,
      popularWinner: popularWinnerUid ? {
        userId: popularWinnerUid,
        name: popularWinnerName,
        postId: popularWinnerPostId,
        reward: 500,
      } : null,
      normalWinner: normalWinnerUid ? {
        userId: normalWinnerUid,
        name: normalWinnerName,
        postId: normalWinnerPostId,
        reward: 300,
      } : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ 추첨 완료 및 결과 저장');
    
    return {
      popularWinner: popularWinnerUid ? {
        userId: popularWinnerUid,
        name: popularWinnerName,
        reward: 500,
      } : null,
      normalWinner: normalWinnerUid ? {
        userId: normalWinnerUid,
        name: normalWinnerName,
        reward: 300,
      } : null,
    };
  } catch (e) {
    console.error(`❌ 추첨 실행 오류: ${e}`);
    throw e;
  }
}

// 매일 오후 5시에 추첨 실행 (한국 시간 기준)
// cron 표현식: 매일 17:00 (한국 시간)
exports.runDailyLottery = functions.pubsub
    .schedule('0 17 * * *') // 한국 시간 17:00 (오후 5시)
    .timeZone('Asia/Seoul')
    .onRun(async (context) => {
      console.log('⏰ 매일 오후 5시 추첨 실행');
      try {
        const result = await runLottery();
        if (result) {
          console.log(`🎉 추첨 완료: 인기작품 당첨자=${result.popularWinner?.name}, 일반작품 당첨자=${result.normalWinner?.name}`);
        }
        return null;
      } catch (e) {
        console.error(`추첨 실행 오류: ${e}`);
        throw e;
      }
    });

// =========================
// 기프트쇼비즈 API 연동
// =========================

// 상품 리스트 조회
async function getGiftCardList(start = 1, size = 20, authCode, authToken) {
  try {
    // 기프트쇼비즈 API 요청 본문 (API CODE 0101: 상품 리스트 조회)
    const requestBody = {
      api_code: '0101',
      custom_auth_code: authCode,
      custom_auth_token: authToken,
      dev_yn: 'N',
      start: String(start),
      size: String(size),
    };
    
    // 인증 정보 확인
    if (!authCode || !authToken) {
      console.error('인증 정보 누락:', { authCode: !!authCode, authToken: !!authToken });
      return {
        success: false,
        error: '인증 정보가 누락되었습니다.',
      };
    }
    
    console.log('기프트쇼비즈 API 요청:', JSON.stringify(requestBody, null, 2));
    console.log('API URL:', `${GIFTSHOWBIZ_BASE_URL}/goods`);
    
    // 모든 필수 파라미터가 비어있지 않은지 확인
    if (!authCode || authCode.trim() === '') {
      console.error('custom_auth_code가 비어있습니다.');
      return {
        success: false,
        error: 'custom_auth_code가 비어있습니다.',
      };
    }
    if (!authToken || authToken.trim() === '') {
      console.error('custom_auth_token이 비어있습니다.');
      return {
        success: false,
        error: 'custom_auth_token이 비어있습니다.',
      };
    }
    
    // form-urlencoded 형식으로 시도 (API 문서에서 "파라미터" 형식 요구)
    const formData = new URLSearchParams();
    formData.append('api_code', '0101');
    formData.append('custom_auth_code', authCode.trim());
    formData.append('custom_auth_token', authToken.trim());
    formData.append('dev_yn', 'N');
    formData.append('start', String(start));
    formData.append('size', String(size));
    
    console.log('Form Data:', formData.toString());
    console.log('각 파라미터 확인:', {
      api_code: '0101',
      custom_auth_code: authCode.trim(),
      custom_auth_token: authToken.trim(),
      dev_yn: 'N',
      start: String(start),
      size: String(size),
    });
    
    // form-urlencoded 형식으로 요청
    const response = await axios.post(
      `${GIFTSHOWBIZ_BASE_URL}/goods`,
      formData.toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    console.log('기프트쇼비즈 API 응답:', JSON.stringify(response.data, null, 2));

    if (response.data.code === '0000') {
      return {
        success: true,
        listNum: response.data.result?.listNum || 0,
        goodsList: response.data.result?.goodsList || [],
      };
    } else {
      console.error('기프트쇼비즈 API 오류:', response.data.message);
      console.error('기프트쇼비즈 API 오류 코드:', response.data.code);
      console.error('기프트쇼비즈 API 전체 응답:', JSON.stringify(response.data, null, 2));
      return {
        success: false,
        error: response.data.message || '알 수 없는 오류',
      };
    }
  } catch (e) {
    console.error('기프트쇼비즈 API 호출 오류:', e);
    if (e.response) {
      console.error('API 응답 상태:', e.response.status);
      console.error('API 응답 데이터:', JSON.stringify(e.response.data, null, 2));
    }
    return {
      success: false,
      error: e.message || 'API 호출 실패',
    };
  }
}

// 상품 리스트 조회 API (HTTP 호출 가능)
exports.getGiftCardList = functions.https.onCall(async (data, context) => {
  try {
    // 인증 확인 (선택사항)
    // if (!context.auth) {
    //   throw new functions.https.HttpsError('unauthenticated', '로그인이 필요합니다.');
    // }

    const start = data.start || 1;
    const size = data.size || 20;

    // Secret 값은 런타임에만 접근 가능
    const authCode = getSecret('GIFTSHOWBIZ_AUTH_CODE');
    const authToken = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');

    console.log('인증 정보 확인:', {
      authCode: authCode ? `${authCode.substring(0, 10)}...` : 'NULL',
      authToken: authToken ? `${authToken.substring(0, 10)}...` : 'NULL',
      authCodeLength: authCode ? authCode.length : 0,
      authTokenLength: authToken ? authToken.length : 0,
    });

    if (!authCode || !authToken) {
      console.error('인증 정보 누락:', { authCode: !!authCode, authToken: !!authToken });
      throw new functions.https.HttpsError('internal', 'API 인증 정보를 가져올 수 없습니다.');
    }

    console.log('API 호출 시작:', { start, size });
    const result = await getGiftCardList(start, size, authCode, authToken);
    console.log('API 호출 결과:', { success: result.success, error: result.error, listNum: result.listNum });
    console.log('goodsList 개수:', result.goodsList ? result.goodsList.length : 0);

    // API 호출 성공 시 결과 반환 (Firestore 캐시는 선택사항)
    if (result.success && result.goodsList && result.goodsList.length > 0) {
      // Firestore에 캐시 저장 (선택사항 - 실패해도 API 결과는 반환)
      try {
        const batch = db.batch();
        let batchCount = 0;
        
        // Firestore batch는 최대 500개까지만 가능하므로 분할 처리
        for (let i = 0; i < result.goodsList.length; i++) {
          const goods = result.goodsList[i];
          
          // goods 객체가 유효한지 확인
          if (!goods || !goods.goodsCode) {
            console.warn(`유효하지 않은 상품 데이터 건너뛰기: ${JSON.stringify(goods)}`);
            continue;
          }
          
          const docRef = db.collection('giftcards').doc(String(goods.goodsCode));
          batch.set(
            docRef,
            {
              goodsCode: String(goods.goodsCode),
              goodsName: String(goods.goodsName || ''),
              salePrice: Number(goods.salePrice) || 0,
              discountPrice: Number(goods.discountPrice) || 0,
              goodsimg: String(goods.goodsimg || goods.mmsGoodsimg || ''),
              brandName: String(goods.brandName || ''),
              goodsTypeNm: String(goods.goodsTypeNm || ''),
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
          batchCount++;
          
          // 500개마다 배치 커밋
          if (batchCount >= 500) {
            await batch.commit();
            console.log(`✅ Firestore 캐시 저장 완료: ${batchCount}개`);
            batchCount = 0;
          }
        }
        
        // 남은 배치 커밋
        if (batchCount > 0) {
          await batch.commit();
          console.log(`✅ Firestore 캐시 저장 완료: ${batchCount}개`);
        }
        
        console.log(`✅ 총 ${result.goodsList.length}개 기프티콘 데이터 처리 완료`);
      } catch (firestoreError) {
        // Firestore 오류는 로그만 남기고 API 결과는 반환
        console.error('❌ Firestore 캐시 저장 중 오류 (무시하고 계속 진행):', firestoreError);
        console.error('오류 상세:', firestoreError.message, firestoreError.stack);
      }
    }

    // 항상 결과 반환 (성공/실패 여부와 관계없이)
    console.log('최종 반환 결과:', { 
      success: result.success, 
      goodsListLength: result.goodsList ? result.goodsList.length : 0 
    });
    return result;
  } catch (e) {
    console.error('상품 리스트 조회 오류:', e);
    throw new functions.https.HttpsError('internal', '상품 리스트 조회 실패', e.message);
  }
});

// 상품 상세 정보 조회
exports.getGiftCardDetail = functions.https.onCall(async (data, context) => {
  try {
    const goodsCode = data.goodsCode;
    if (!goodsCode) {
      throw new functions.https.HttpsError('invalid-argument', '상품 코드가 필요합니다.');
    }

    // Secret 값은 런타임에만 접근 가능
    const authCode = getSecret('GIFTSHOWBIZ_AUTH_CODE');
    const authToken = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');

    if (!authCode || !authToken) {
      throw new functions.https.HttpsError('internal', 'API 인증 정보를 가져올 수 없습니다.');
    }

    const response = await axios.post(
      `${GIFTSHOWBIZ_BASE_URL}/goods/${goodsCode}`,
      {
        api_code: '0111',
        custom_auth_code: authCode,
        custom_auth_token: authToken,
        dev_yn: 'N',
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
      }
    );

    if (response.data.code === '0000') {
      return {
        success: true,
        goodsDetail: response.data.result?.goodsDetail || null,
      };
    } else {
      return {
        success: false,
        error: response.data.message || '알 수 없는 오류',
      };
    }
    } catch (e) {
      console.error('상품 상세 조회 오류:', e);
      throw new functions.https.HttpsError('internal', '상품 상세 조회 실패', e.message);
    }
});

