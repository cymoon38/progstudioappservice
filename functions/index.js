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
  // 상용 환경 키 사용 (운영 환경)
  if (secretName === 'GIFTSHOWBIZ_AUTH_CODE') {
    // 상용 환경 키
    return process.env.GIFTSHOWBIZ_AUTH_CODE_PROD || 'REAL56bf67edd37e4733af8ddba2d5387150';
  }
  if (secretName === 'GIFTSHOWBIZ_AUTH_TOKEN') {
    // 상용 환경 토큰
    return process.env.GIFTSHOWBIZ_AUTH_TOKEN_PROD || '3RXSN9gtle+bE63cH3vnSg==';
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
  
  console.log(`🔍 게시물 작성자 UID 찾기 시작 (게시물 수: ${posts.length})`);
  
  for (const post of posts) {
    if (post.authorUid && post.authorUid.length > 0) {
      authorUids.add(post.authorUid);
      console.log(`  ✅ authorUid로 찾음: ${post.authorUid} (게시물: ${post.id})`);
    } else if (post.author && post.author.length > 0) {
      // authorUid가 없으면 author 이름으로 UID 찾기
      try {
        const userQuery = await db
            .collection('users')
            .where('name', '==', post.author)
            .limit(1)
            .get();
        
        if (!userQuery.empty) {
          const foundUid = userQuery.docs[0].id;
          authorUids.add(foundUid);
          console.log(`  ✅ 이름으로 찾음: ${post.author} -> ${foundUid} (게시물: ${post.id})`);
        } else {
          console.warn(`  ⚠️ 사용자를 찾을 수 없음: ${post.author} (게시물: ${post.id})`);
        }
      } catch (e) {
        console.error(`  ❌ 사용자 UID 찾기 오류: ${e} (author: ${post.author}, 게시물: ${post.id})`);
      }
    } else {
      console.warn(`  ⚠️ authorUid와 author가 모두 없음 (게시물: ${post.id})`);
    }
  }
  
  console.log(`🔍 게시물 작성자 UID 찾기 완료 (총 ${authorUids.size}명)`);
  return authorUids;
}

// 코인 지급
async function addCoins(userId, amount, type, notificationMessage = null) {
  try {
    console.log(`💰 코인 지급 시작: userId=${userId}, amount=${amount}, type=${type}`);
    
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      const error = `사용자 문서가 없습니다: ${userId}`;
      console.error(`❌ ${error}`);
      throw new Error(error);
    }
    
    const userData = userDoc.data();
    const currentCoins = userData.coins || 0;
    const newCoins = currentCoins + amount;
    
    console.log(`💰 코인 업데이트: ${currentCoins} -> ${newCoins} (${amount} 추가)`);
    
    await userRef.update({ coins: newCoins });
    console.log(`✅ 코인 업데이트 완료`);
    
    await db.collection('coinHistory').add({
      userId: userId,
      amount: amount,
      type: type,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ 코인 히스토리 추가 완료`);
    
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
        console.log(`🔔 알림 생성 완료: ${userId} - ${notificationMessage}`);
      } catch (e) {
        console.error(`⚠️ 알림 생성 오류 (무시): ${e}`);
      }
    }
    
    console.log(`✅ 코인 지급 완료: ${userId} - ${amount}코인 (${type}), 총 ${newCoins}코인`);
    return newCoins;
  } catch (e) {
    console.error(`❌ 코인 지급 오류: ${e}`);
    console.error(`❌ 코인 지급 오류 스택: ${e.stack}`);
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
    console.log(`📅 Firestore Timestamp: startTime=${startTime.toMillis()}, endTime=${endTime.toMillis()}`);
    
    // 디버깅: 전체 게시물 수 확인
    const allPostsSnapshot = await db.collection('posts').limit(10).get();
    console.log(`📊 전체 게시물 샘플 (최대 10개):`);
    allPostsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`  게시물 ${index + 1}: id=${doc.id}, date=${data.date?.toDate?.()?.toISOString() || data.date}, isPopular=${data.isPopular}, type=${data.type}, author=${data.author}`);
    });
    
    // 디버깅: 시간 범위 내 전체 게시물 확인
    const timeRangePostsSnapshot = await db
        .collection('posts')
        .where('date', '>=', startTime)
        .where('date', '<', endTime)
        .limit(10)
        .get();
    console.log(`📊 시간 범위 내 게시물 수: ${timeRangePostsSnapshot.size}`);
    timeRangePostsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`  시간 범위 내 게시물 ${index + 1}: id=${doc.id}, date=${data.date?.toDate?.()?.toISOString() || data.date}, isPopular=${data.isPopular}, type=${data.type}`);
    });
    
    // 1. 인기작품에서 먼저 추첨 (어제 오후 5시 ~ 오늘 오후 5시 사이 게시물)
    // 주의: type != 'notice'와 date 범위 필터를 함께 사용하면 복합 인덱스가 필요하므로
    // 먼저 시간 범위 내 모든 게시물을 가져온 후 클라이언트 측에서 필터링
    const allTimeRangePostsForPopularSnapshot = await db
        .collection('posts')
        .where('date', '>=', startTime) // 어제 오후 5시 이후
        .where('date', '<', endTime) // 오늘 오후 5시 이전
        .get();
    
    console.log(`📊 시간 범위 내 전체 게시물 수 (인기작품 필터링 전): ${allTimeRangePostsForPopularSnapshot.size}개`);
    
    // 클라이언트 측에서 isPopular == true이고 type != 'notice'인 게시물 필터링
    const popularPostsSnapshot = {
      docs: allTimeRangePostsForPopularSnapshot.docs.filter(doc => {
        const data = doc.data();
        return data.isPopular === true && data.type !== 'notice';
      })
    };
    
    console.log(`📊 인기작품 쿼리 결과 (원본): ${popularPostsSnapshot.docs.length}개`);
    
    const popularPosts = popularPostsSnapshot.docs
        .map(doc => {
          const data = doc.data();
          return {
            id: doc.id,
            author: data.author || '',
            authorUid: data.authorUid || null,
            type: data.type || null,
            date: data.date,
            isPopular: data.isPopular,
          };
        })
        .filter(post => post.authorUid || post.author);
    
    console.log(`📊 인기작품 수 (작성자 필터링 후): ${popularPosts.length}`);
    if (popularPosts.length > 0) {
      console.log(`📊 인기작품 샘플:`, popularPosts.slice(0, 3).map(p => ({ id: p.id, author: p.author, authorUid: p.authorUid })));
    }
    
    let popularWinnerUid = null;
    let popularWinnerName = null;
    let popularWinnerPostId = null;
    
    if (popularPosts.length > 0) {
      const popularAuthors = await getPostAuthors(popularPosts);
      console.log(`📊 인기작품 작성자 수: ${popularAuthors.size}`);
      console.log(`📊 인기작품 작성자 UID 목록: ${Array.from(popularAuthors).join(', ')}`);
      
      if (popularAuthors.size > 0) {
        const winnerList = Array.from(popularAuthors);
        const winnerIndex = Math.floor(Math.random() * winnerList.length);
        popularWinnerUid = winnerList[winnerIndex];
        console.log(`🎯 인기작품 당첨자 UID 선택: ${popularWinnerUid}`);
        
        // 당첨자 이름 찾기
        try {
          const winnerDoc = await db.collection('users').doc(popularWinnerUid).get();
          if (winnerDoc.exists) {
            popularWinnerName = winnerDoc.data().name || '알 수 없음';
            console.log(`✅ 당첨자 이름 찾기 성공: ${popularWinnerName}`);
          } else {
            console.warn(`⚠️ 당첨자 문서가 존재하지 않음: ${popularWinnerUid}`);
            popularWinnerName = '알 수 없음';
          }
        } catch (e) {
          console.error(`❌ 당첨자 이름 찾기 오류: ${e}`);
          popularWinnerName = '알 수 없음';
        }
        
        // 당첨자의 인기작품 중 하나를 랜덤 선택
        const winnerPosts = popularPosts.filter(post => post.authorUid === popularWinnerUid || 
          (post.authorUid === null && post.author === popularWinnerName));
        if (winnerPosts.length > 0) {
          const postIndex = Math.floor(Math.random() * winnerPosts.length);
          popularWinnerPostId = winnerPosts[postIndex].id;
          console.log(`📝 당첨자 게시물 선택: ${popularWinnerPostId}`);
        } else {
          console.warn(`⚠️ 당첨자의 인기작품을 찾을 수 없음`);
        }
        
        // 인기작품 당첨자에게 500코인 지급
        try {
          await addCoins(
            popularWinnerUid, 
            500, 
            '오늘의 당첨자 보상',
            `${popularWinnerName}님, 오늘의 당첨자 보상으로 500코인을 받았습니다!`
          );
          console.log(`🎉 인기작품 추첨 당첨자: ${popularWinnerName} (${popularWinnerUid}) - 게시물: ${popularWinnerPostId} - 500코인 지급 완료`);
        } catch (e) {
          console.error(`❌ 인기작품 당첨자 코인 지급 실패: ${e}`);
          // 코인 지급 실패해도 결과는 저장
        }
      } else {
        console.log(`⚠️ 인기작품 작성자가 없어 인기작품 당첨자를 선택할 수 없습니다.`);
      }
    } else {
      console.log(`⚠️ 인기작품이 없어 인기작품 추첨을 건너뜁니다.`);
    }
    
    // 2. 일반 작품에서 추첨 (인기작품 당첨자 제외, 어제 오후 5시 ~ 오늘 오후 5시 사이 게시물)
    // 주의: type != 'notice'와 date 범위 필터를 함께 사용하면 복합 인덱스가 필요하므로
    // 먼저 시간 범위 내 모든 게시물을 가져온 후 클라이언트 측에서 필터링
    const allTimeRangePostsSnapshot = await db
        .collection('posts')
        .where('date', '>=', startTime) // 어제 오후 5시 이후
        .where('date', '<', endTime) // 오늘 오후 5시 이전
        .get();
    
    console.log(`📊 시간 범위 내 전체 게시물 수 (필터링 전): ${allTimeRangePostsSnapshot.size}`);
    
    // 클라이언트 측에서 isPopular과 type 필터링
    // isPopular이 false이거나 없고, type이 'notice'가 아닌 게시물
    const generalPostsSnapshot = {
      docs: allTimeRangePostsSnapshot.docs.filter(doc => {
        const data = doc.data();
        const isPopular = data.isPopular;
        const type = data.type;
        // isPopular이 false이거나 undefined/null이고, type이 'notice'가 아닌 경우
        return isPopular !== true && type !== 'notice';
      })
    };
    
    console.log(`📊 일반작품 쿼리 결과 (원본): ${generalPostsSnapshot.docs.length}개`);
    
    const generalPosts = generalPostsSnapshot.docs
        .map(doc => {
          const data = doc.data();
          return {
            id: doc.id,
            author: data.author || '',
            authorUid: data.authorUid || null,
            type: data.type || null,
            isPopular: data.isPopular || false,
            date: data.date,
          };
        })
        .filter(post => post.authorUid || post.author);
    
    console.log(`📊 일반작품 수 (작성자 필터링 후): ${generalPosts.length}`);
    if (generalPosts.length > 0) {
      console.log(`📊 일반작품 샘플:`, generalPosts.slice(0, 3).map(p => ({ id: p.id, author: p.author, authorUid: p.authorUid, isPopular: p.isPopular })));
    }
    
    let normalWinnerUid = null;
    let normalWinnerName = null;
    let normalWinnerPostId = null;
    
    if (generalPosts.length > 0) {
      
      const allAuthors = await getPostAuthors(generalPosts);
      console.log(`📊 일반작품 전체 작성자 수: ${allAuthors.size}`);
      console.log(`📊 일반작품 전체 작성자 UID 목록: ${Array.from(allAuthors).join(', ')}`);
      
      // 인기작품 당첨자 제외
      const normalAuthors = popularWinnerUid
          ? Array.from(allAuthors).filter(uid => uid !== popularWinnerUid)
          : Array.from(allAuthors);
      
      console.log(`📊 일반작품 작성자 수 (인기작품 당첨자 제외): ${normalAuthors.length}`);
      console.log(`📊 일반작품 작성자 UID 목록 (인기작품 당첨자 제외): ${normalAuthors.join(', ')}`);
      
      if (normalAuthors.length > 0) {
        const winnerIndex = Math.floor(Math.random() * normalAuthors.length);
        normalWinnerUid = normalAuthors[winnerIndex];
        console.log(`🎯 일반작품 당첨자 UID 선택: ${normalWinnerUid}`);
        
        // 당첨자 이름 찾기
        try {
          const winnerDoc = await db.collection('users').doc(normalWinnerUid).get();
          if (winnerDoc.exists) {
            normalWinnerName = winnerDoc.data().name || '알 수 없음';
            console.log(`✅ 당첨자 이름 찾기 성공: ${normalWinnerName}`);
          } else {
            console.warn(`⚠️ 당첨자 문서가 존재하지 않음: ${normalWinnerUid}`);
            normalWinnerName = '알 수 없음';
          }
        } catch (e) {
          console.error(`❌ 당첨자 이름 찾기 오류: ${e}`);
          normalWinnerName = '알 수 없음';
        }
        
        // 당첨자의 일반작품 중 하나를 랜덤 선택
        const winnerPosts = generalPosts.filter(post => 
          (post.authorUid === normalWinnerUid) || 
          (post.authorUid === null && post.author === normalWinnerName));
        if (winnerPosts.length > 0) {
          const postIndex = Math.floor(Math.random() * winnerPosts.length);
          normalWinnerPostId = winnerPosts[postIndex].id;
          console.log(`📝 당첨자 게시물 선택: ${normalWinnerPostId}`);
        } else {
          console.warn(`⚠️ 당첨자의 일반작품을 찾을 수 없음`);
        }
        
        // 일반작품 당첨자에게 300코인 지급
        try {
          await addCoins(
            normalWinnerUid, 
            300, 
            '오늘의 당첨자 보상',
            `${normalWinnerName}님, 오늘의 당첨자 보상으로 300코인을 받았습니다!`
          );
          console.log(`🎉 일반작품 추첨 당첨자: ${normalWinnerName} (${normalWinnerUid}) - 게시물: ${normalWinnerPostId} - 300코인 지급 완료`);
        } catch (e) {
          console.error(`❌ 일반작품 당첨자 코인 지급 실패: ${e}`);
          // 코인 지급 실패해도 결과는 저장
        }
      } else {
        console.log(`⚠️ 일반작품 작성자가 없어 일반작품 당첨자를 선택할 수 없습니다.`);
      }
    } else {
      console.log(`⚠️ 일반작품이 없어 일반작품 추첨을 건너뜁니다.`);
    }
    
    // 추첨 결과 저장
    const lotteryResult = {
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
    };
    
    console.log(`💾 추첨 결과 저장 중...`, JSON.stringify(lotteryResult, null, 2));
    
    try {
      await db.collection('lotteryResults').doc(today).set(lotteryResult);
      console.log('✅ 추첨 완료 및 결과 저장 성공');
    } catch (e) {
      console.error(`❌ 추첨 결과 저장 실패: ${e}`);
      throw e; // 저장 실패는 치명적 오류이므로 throw
    }
    
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
          console.log(`🎉 추첨 완료: 인기작품 당첨자=${result.popularWinner?.name || '없음'}, 일반작품 당첨자=${result.normalWinner?.name || '없음'}`);
        } else {
          console.log(`⚠️ 추첨 결과가 null입니다. 이미 실행되었거나 당첨자가 없을 수 있습니다.`);
        }
        return null;
      } catch (e) {
        console.error(`❌ 추첨 실행 오류: ${e}`);
        console.error(`❌ 오류 스택: ${e.stack}`);
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
      dev_yn: 'N', // 상용 환경
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
    formData.append('dev_yn', 'N'); // 상용 환경
    formData.append('start', String(start));
    formData.append('size', String(size));
    
    console.log('Form Data:', formData.toString());
    console.log('각 파라미터 확인:', {
      api_code: '0101',
      custom_auth_code: authCode.trim(),
      custom_auth_token: authToken.trim(),
      dev_yn: 'N', // 상용 환경
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
    
    // 첫 번째 상품의 이미지 필드 확인 (디버깅)
    if (response.data.code === '0000' && response.data.result?.goodsList?.length > 0) {
      const firstGoods = response.data.result.goodsList[0];
      console.log('📦 첫 번째 상품 데이터 구조:', JSON.stringify(firstGoods, null, 2));
      console.log('🖼️ 첫 번째 상품 이미지 필드들:');
      console.log('   goodsimg:', firstGoods.goodsimg);
      console.log('   mmsGoodsimg:', firstGoods.mmsGoodsimg);
      console.log('   goodsImgS:', firstGoods.goodsImgS);
      console.log('   goodsImgB:', firstGoods.goodsImgB);
      console.log('   모든 키:', Object.keys(firstGoods));
    }

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

    // API 호출 실패 시 Firestore 캐시에서 데이터 반환 시도
    if (!result.success || !result.goodsList || result.goodsList.length === 0) {
      console.log('⚠️ API 호출 실패, Firestore 캐시에서 데이터 조회 시도...');
      try {
        const cachedSnapshot = await db.collection('giftcards')
          .orderBy('lastUpdated', 'desc')
          .limit(size)
          .get();
        
        if (!cachedSnapshot.empty) {
          const cachedGoodsList = cachedSnapshot.docs.map(doc => doc.data());
          console.log(`✅ Firestore 캐시에서 ${cachedGoodsList.length}개 상품 조회 성공`);
          return {
            success: true,
            goodsList: cachedGoodsList,
            fromCache: true,
          };
        }
      } catch (cacheError) {
        console.error('❌ Firestore 캐시 조회 오류:', cacheError);
      }
      
      // 캐시도 없으면 에러 반환
      return {
        success: false,
        error: result.error || '상품 목록을 가져올 수 없습니다.',
        goodsList: [],
      };
    }

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
          
          // 이미지 URL 우선순위: goodsimg > mmsGoodsimg > goodsImgS > goodsImgB
          // 모든 가능한 이미지 필드 확인
          const imageUrl = goods.goodsimg || 
                          goods.mmsGoodsimg || 
                          goods.goodsImgS || 
                          goods.goodsImgB ||
                          goods.goodsImg ||
                          goods.image ||
                          goods.img ||
                          '';
          
          console.log(`📦 상품 ${goods.goodsCode} 이미지 필드 확인:`);
          console.log(`   goodsimg: ${goods.goodsimg}`);
          console.log(`   mmsGoodsimg: ${goods.mmsGoodsimg}`);
          console.log(`   goodsImgS: ${goods.goodsImgS}`);
          console.log(`   goodsImgB: ${goods.goodsImgB}`);
          console.log(`   goodsImg: ${goods.goodsImg}`);
          console.log(`   image: ${goods.image}`);
          console.log(`   img: ${goods.img}`);
          console.log(`   최종 이미지 URL: ${imageUrl}`);
          
          batch.set(
            docRef,
            {
              goodsCode: String(goods.goodsCode),
              goodsName: String(goods.goodsName || ''),
              salePrice: Number(goods.salePrice) || 0,
              discountPrice: Number(goods.discountPrice) || 0,
              goodsimg: String(imageUrl),
              mmsGoodsimg: String(goods.mmsGoodsimg || ''),
              goodsImgS: String(goods.goodsImgS || ''),
              goodsImgB: String(goods.goodsImgB || ''),
              goodsImg: String(goods.goodsImg || ''),
              image: String(goods.image || ''),
              img: String(goods.img || ''),
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
  console.log('🔍 getGiftCardDetail 함수 호출 시작');
  console.log('📥 받은 데이터:', JSON.stringify(data, null, 2));
  console.log('📥 데이터 타입:', typeof data);
  console.log('📥 context.auth:', context.auth ? `uid: ${context.auth.uid}` : 'null');
  
  try {
    // 데이터 검증
    if (!data) {
      console.error('❌ data가 null 또는 undefined입니다.');
      throw new functions.https.HttpsError('invalid-argument', '데이터가 필요합니다.');
    }
    
    const goodsCode = data.goodsCode;
    console.log(`📦 goodsCode: ${goodsCode} (타입: ${typeof goodsCode})`);
    
    if (!goodsCode) {
      console.error('❌ goodsCode가 없습니다.');
      console.error('📋 전체 data 객체:', JSON.stringify(data, null, 2));
      throw new functions.https.HttpsError('invalid-argument', '상품 코드가 필요합니다.');
    }

    if (typeof goodsCode !== 'string' || goodsCode.trim().length === 0) {
      console.error('❌ goodsCode가 유효한 문자열이 아닙니다.');
      throw new functions.https.HttpsError('invalid-argument', '유효한 상품 코드가 필요합니다.');
    }

    // Secret 값은 런타임에만 접근 가능
    console.log('🔑 인증 정보 가져오기 시작...');
    const authCode = getSecret('GIFTSHOWBIZ_AUTH_CODE');
    const authToken = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');
    
    console.log(`🔑 authCode 존재: ${!!authCode} (길이: ${authCode ? authCode.length : 0})`);
    console.log(`🔑 authToken 존재: ${!!authToken} (길이: ${authToken ? authToken.length : 0})`);

    if (!authCode || !authToken) {
      console.error('❌ API 인증 정보를 가져올 수 없습니다.');
      console.error(`   authCode: ${authCode ? '존재' : '없음'}`);
      console.error(`   authToken: ${authToken ? '존재' : '없음'}`);
      throw new functions.https.HttpsError('internal', 'API 인증 정보를 가져올 수 없습니다.');
    }

    // API URL 확인 (goodsCode를 URL에 포함할지 본문에 포함할지 확인 필요)
    // 일단 getGiftCardList와 동일하게 form-urlencoded 형식 사용
    const apiUrl = `${GIFTSHOWBIZ_BASE_URL}/goods/${goodsCode}`;
    console.log(`📞 Giftshowbiz API 호출 시작`);
    console.log(`   URL: ${apiUrl}`);
    console.log(`   goodsCode: ${goodsCode}`);
    
    // form-urlencoded 형식으로 요청 (getGiftCardList와 동일)
    const formData = new URLSearchParams();
    formData.append('api_code', '0111');
    formData.append('custom_auth_code', authCode.trim());
    formData.append('custom_auth_token', authToken.trim());
    formData.append('dev_yn', 'N'); // 상용 환경
    formData.append('goodsCode', String(goodsCode).trim()); // 필수 파라미터
    
    console.log(`📤 Form Data:`, formData.toString());
    console.log(`📤 각 파라미터 확인:`, {
      api_code: '0111',
      custom_auth_code: authCode.trim().substring(0, 10) + '...',
      custom_auth_token: authToken.trim().substring(0, 10) + '...',
      dev_yn: 'N',
      goodsCode: String(goodsCode).trim(),
    });
    
    // 모든 필수 파라미터가 비어있지 않은지 확인
    if (!authCode || authCode.trim() === '') {
      console.error('❌ custom_auth_code가 비어있습니다.');
      throw new functions.https.HttpsError('internal', 'custom_auth_code가 비어있습니다.');
    }
    if (!authToken || authToken.trim() === '') {
      console.error('❌ custom_auth_token이 비어있습니다.');
      throw new functions.https.HttpsError('internal', 'custom_auth_token이 비어있습니다.');
    }
    if (!goodsCode || String(goodsCode).trim() === '') {
      console.error('❌ goodsCode가 비어있습니다.');
      throw new functions.https.HttpsError('invalid-argument', 'goodsCode가 비어있습니다.');
    }
    
    let response;
    try {
      response = await axios.post(
        apiUrl,
        formData.toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          timeout: 30000, // 30초 타임아웃
        }
      );
      console.log(`✅ API 응답 받음 (상태 코드: ${response.status})`);
    } catch (axiosError) {
      console.error('❌ axios 요청 실패:', axiosError.message);
      if (axiosError.response) {
        console.error('   응답 상태:', axiosError.response.status);
        console.error('   응답 데이터:', JSON.stringify(axiosError.response.data, null, 2));
      } else if (axiosError.request) {
        console.error('   요청은 전송되었지만 응답을 받지 못함');
      }
      throw axiosError;
    }

    console.log(`📥 API 응답 코드: ${response.data.code}`);
    console.log(`📥 API 응답 메시지: ${response.data.message || '없음'}`);
    console.log(`📥 API 응답 전체 구조:`, JSON.stringify(response.data, null, 2));
    
    if (!response.data) {
      console.error('❌ API 응답 데이터가 없습니다.');
      throw new functions.https.HttpsError('internal', 'API 응답 데이터가 없습니다.');
    }
    
    if (response.data.code === '0000') {
      console.log('✅ API 응답 성공 (code: 0000)');
      console.log('📋 response.data.result 존재:', !!response.data.result);
      console.log('📋 response.data.result 타입:', typeof response.data.result);
      
      const goodsDetail = response.data.result?.goodsDetail || response.data.result || null;
      console.log(`✅ goodsDetail 추출 시도`);
      console.log(`   response.data.result?.goodsDetail: ${response.data.result?.goodsDetail ? '존재' : '없음'}`);
      console.log(`   response.data.result: ${response.data.result ? '존재' : '없음'}`);
      console.log(`   최종 goodsDetail: ${goodsDetail ? '존재' : 'null'}`);
      
      if (goodsDetail) {
        console.log(`📋 goodsDetail 타입: ${typeof goodsDetail}`);
        if (typeof goodsDetail === 'object') {
          console.log(`📋 goodsDetail 키 목록:`, Object.keys(goodsDetail));
          console.log(`📋 goodsDetail 전체 내용:`, JSON.stringify(goodsDetail, null, 2));
        } else {
          console.log(`📋 goodsDetail 값:`, goodsDetail);
        }
      } else {
        console.warn('⚠️ goodsDetail이 null입니다.');
        console.warn('📋 response.data 전체:', JSON.stringify(response.data, null, 2));
      }
      
      const returnData = {
        success: true,
        goodsDetail: goodsDetail,
      };
      console.log('✅ 반환 데이터 준비 완료');
      console.log('📤 반환 데이터:', JSON.stringify(returnData, null, 2));
      return returnData;
    } else {
      console.error(`❌ API 오류 응답`);
      console.error(`   코드: ${response.data.code}`);
      console.error(`   메시지: ${response.data.message || '알 수 없는 오류'}`);
      const errorData = {
        success: false,
        error: response.data.message || '알 수 없는 오류',
        code: response.data.code,
      };
      console.log('📤 오류 응답 반환:', JSON.stringify(errorData, null, 2));
      return errorData;
    }
  } catch (e) {
    console.error('❌ 상품 상세 조회 오류 발생');
    console.error('   오류 타입:', e.constructor.name);
    console.error('   오류 메시지:', e.message);
    console.error('   오류 스택:', e.stack);
    
    if (e instanceof functions.https.HttpsError) {
      console.error('   HttpsError로 재던지기');
      throw e;
    } else if (e.response) {
      console.error('   axios 응답 오류:', JSON.stringify(e.response.data, null, 2));
      throw new functions.https.HttpsError('internal', `API 호출 실패: ${e.message}`, e.response.data);
    } else if (e.request) {
      console.error('   요청은 전송되었지만 응답을 받지 못함');
      throw new functions.https.HttpsError('internal', 'API 서버에 연결할 수 없습니다.', e.message);
    } else {
      console.error('   알 수 없는 오류');
      throw new functions.https.HttpsError('internal', `상품 상세 조회 실패: ${e.message}`, e.message);
    }
  }
});

