const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const crypto = require('crypto');

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
  if (secretName === 'GIFTSHOWBIZ_USER_ID') {
    // Giftshowbiz 계정 ID (user_id 파라미터에 사용)
    // Firebase Console > Functions > 설정 > 환경 변수에서 GIFTSHOWBIZ_USER_ID_PROD 설정 가능
    return process.env.GIFTSHOWBIZ_USER_ID_PROD || process.env.GIFTSHOWBIZ_USER_ID || 'cymoon38@gmail.com';
  }
  if (secretName === 'GIFTSHOWBIZ_PHONE_NO') {
    // 고정 전화번호 (테스트용)
    // Firebase Console > Functions > 설정 > 환경 변수에서 GIFTSHOWBIZ_PHONE_NO 설정 가능
    // 또는 아래에 직접 전화번호를 하드코딩할 수 있습니다
    return process.env.GIFTSHOWBIZ_PHONE_NO || '01057049470'; // 고정 전화번호
  }
  if (secretName === 'ADPOPCORN_HASH_KEY') {
    return process.env.ADPOPCORN_HASH_KEY || 'f0914cb6664e4991';
  }
  if (secretName === 'ADPOPCORN_HASH_KEY_STAGING') {
    return process.env.ADPOPCORN_HASH_KEY_STAGING || process.env.ADPOPCORN_HASH_KEY || 'f0914cb6664e4991';
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

// 애드팝콘 리워드 콜백 공통 처리 (스테이징/라이브)
// GET 쿼리: usn, reward_key, quantity, campaign_key, signed_value (애드팝콘 기본 파라미터명)
function buildAdpopcornResponse(result, resultCode, resultMsg) {
  return { Result: result, ResultCode: resultCode, ResultMsg: resultMsg };
}

// 쿼리/바디에서 키 값 읽기 (대소문자·언더스코어 허용)
function getParam(obj, ...keys) {
  if (!obj || typeof obj !== 'object') return '';
  for (const k of keys) {
    const v = obj[k];
    if (v !== undefined && v !== null && String(v).trim() !== '') return String(v).trim();
  }
  return '';
}

async function processAdpopcornRewardCallback(query, isStaging) {
  const tag = isStaging ? '[AdPopcorn Staging]' : '[AdPopcorn Live]';
  console.log(`${tag} 수신 파라미터 키: ${Object.keys(query || {}).join(', ')}`);
  const usn = getParam(query, 'usn', 'USN');
  const rewardkey = getParam(query, 'reward_key', 'rewardkey');
  const quantity = parseInt(String(query.quantity != null ? query.quantity : '0'), 10);
  const campaignkey = getParam(query, 'campaign_key', 'campaignkey');
  const signedValue = getParam(query, 'signed_value', 'SignedValue', 'signedValue');

  if (!usn || !rewardkey) {
    console.warn(`${tag} 필수 파라미터 없음: usn=${usn}, rewardkey=${rewardkey}`);
    return buildAdpopcornResponse(false, 4000, 'missing required parameters');
  }

  const hashKey = isStaging ? getSecret('ADPOPCORN_HASH_KEY_STAGING') : getSecret('ADPOPCORN_HASH_KEY');
  if (!hashKey) {
    console.error(`${tag} HASH KEY 미설정. 환경 변수 ADPOPCORN_HASH_KEY${isStaging ? '_STAGING' : ''} 설정 필요`);
    return buildAdpopcornResponse(false, 1100, 'invalid signed value');
  }

  // SignedValue 검증: 애드팝콘 plainText 형식 시도 (문서마다 순서 상이)
  const receivedSigned = signedValue.toLowerCase();
  const candidates = [
    usn + rewardkey + campaignkey + String(quantity),           // usn, reward_key, campaign_key, quantity
    usn + rewardkey + String(quantity) + campaignkey,           // usn, reward_key, quantity, campaign_key
    usn + campaignkey + rewardkey + String(quantity),          // usn, campaign_key, reward_key, quantity
    campaignkey + String(quantity) + rewardkey + usn,         // campaign_key, quantity, reward_key, usn (일부 문서)
  ];
  const expectedList = candidates.map((pt) =>
    crypto.createHmac('md5', hashKey).update(pt).digest('hex').toLowerCase());
  const match = expectedList.some((exp) => exp === receivedSigned);
  if (!match) {
    console.warn(`${tag} SignedValue 불일치 (received=${receivedSigned})`);
    return buildAdpopcornResponse(false, 1100, 'invalid signed value');
  }

  // 리워드 중복 지급 방지
  const rewardRef = db.collection('offerwallRewards').doc(rewardkey);
  const rewardDoc = await rewardRef.get();
  if (rewardDoc.exists) {
    console.warn(`${tag} 중복 rewardkey: ${rewardkey}`);
    return buildAdpopcornResponse(false, 3100, 'duplicate transaction');
  }

  // 유저 검증
  const userRef = db.collection('users').doc(usn);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    console.warn(`${tag} 존재하지 않는 유저: ${usn}`);
    return buildAdpopcornResponse(false, 3200, 'invalid user');
  }

  if (quantity <= 0) {
    console.warn(`${tag} quantity <= 0: ${quantity}`);
    return buildAdpopcornResponse(false, 4000, 'invalid quantity');
  }

  try {
    await addCoins(
        usn,
        quantity,
        'offerwall',
        `오퍼월 미션 완료로 ${quantity}코인이 지급되었습니다.`,
    );
    await rewardRef.set({
      userId: usn,
      quantity,
      campaignkey,
      isStaging,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`${tag} 리워드 지급 완료: usn=${usn}, quantity=${quantity}, rewardkey=${rewardkey}`);
    return buildAdpopcornResponse(true, 1, 'success');
  } catch (e) {
    console.error(`${tag} 리워드 지급 실패:`, e);
    return buildAdpopcornResponse(false, 4000, 'reward grant failed');
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

// 매일 새벽 3시에 기프트쇼비즈 상품 리스트 동기화 (한국 시간 기준)
// cron 표현식: 매일 03:00 (한국 시간)
// runDailyLottery와 동일한 패턴으로 작성
exports.syncGiftCardsDaily = functions
    .runWith({
      timeoutSeconds: 540, // 9분 (Gen1 최대값) - 예상 작업 시간: 약 1-3분 (충분함)
      memory: '512MB', // 메모리 512MB
    })
    .pubsub
    .schedule('0 3 * * *') // 한국 시간 03:00 (새벽 3시)
    .timeZone('Asia/Seoul')
    .onRun(async (context) => {
      console.log('========================================');
      console.log('⏰ 매일 새벽 3시 기프트쇼비즈 상품 리스트 동기화 시작');
      console.log(`📅 실행 시간: ${new Date().toISOString()}`);
      console.log(`🌏 타임존: Asia/Seoul`);
      console.log('========================================');
      
      try {
        console.log('📝 Step 1: 동기화 상태를 "syncing"으로 설정 시작...');
        // 동기화 상태를 "syncing"으로 설정
        await db.collection('syncStatus').doc('giftcards').set({
          status: 'syncing',
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          message: '상품 업데이트중...',
        });
        console.log('✅ Step 1 완료: 동기화 상태를 "syncing"으로 설정');
        
        console.log('📝 Step 2: API 인증 정보 가져오기 시작...');
        const authCode = getSecret('GIFTSHOWBIZ_AUTH_CODE');
        const authToken = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');
        
        if (!authCode || !authToken) {
          console.error('❌ Step 2 실패: API 인증 정보를 가져올 수 없습니다.');
          console.error(`   - authCode 존재: ${!!authCode}`);
          console.error(`   - authToken 존재: ${!!authToken}`);
          // 오류 발생 시 상태를 "idle"로 변경
          await db.collection('syncStatus').doc('giftcards').set({
            status: 'idle',
            lastError: 'API 인증 정보를 가져올 수 없습니다.',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          throw new Error('API 인증 정보를 가져올 수 없습니다.');
        }
        console.log('✅ Step 2 완료: API 인증 정보 가져오기 성공');
        
        console.log('📝 Step 3: 상품 동기화 변수 초기화...');
        const totalProducts = 4304; // 전체 상품 개수
        const pageSize = 500; // 한 번에 가져올 상품 개수
        let currentPage = 1;
        let totalLoaded = 0;
        let totalUpdated = 0;
        const apiGoodsCodes = new Set(); // API에서 받아온 상품 코드 목록
        
        console.log(`✅ Step 3 완료: 변수 초기화`);
        console.log(`📦 Step 4: 전체 상품 동기화 시작 (예상 개수: ${totalProducts}개, 페이지 크기: ${pageSize}개)`);
        
        // 페이지네이션으로 전체 상품 가져오기
        while (totalLoaded < totalProducts) {
          const remaining = totalProducts - totalLoaded;
          const size = remaining > pageSize ? pageSize : remaining;
          
          console.log(`📦 페이지 ${currentPage} 로드 중... (size: ${size}, 누적: ${totalLoaded}/${totalProducts})`);
          
          console.log(`   📡 API 호출 중... (page: ${currentPage}, size: ${size})`);
          const result = await getGiftCardList(currentPage, size, authCode, authToken);
          console.log(`   📡 API 응답 받음: success=${result.success}, goodsList.length=${result.goodsList?.length || 0}`);
          
          if (!result.success || !result.goodsList || result.goodsList.length === 0) {
            console.warn(`⚠️ 페이지 ${currentPage}에서 더 이상 가져올 상품이 없습니다.`);
            console.warn(`   - result.success: ${result.success}`);
            console.warn(`   - result.goodsList 존재: ${!!result.goodsList}`);
            console.warn(`   - result.goodsList.length: ${result.goodsList?.length || 0}`);
            break;
          }
          
          const goodsList = result.goodsList;
          totalLoaded += goodsList.length;
          console.log(`✅ 페이지 ${currentPage} 완료: ${goodsList.length}개 (누적: ${totalLoaded}/${totalProducts})`);
          
          // Firestore에 저장/업데이트
          try {
            const batch = db.batch();
            let batchCount = 0;
            
            for (let i = 0; i < goodsList.length; i++) {
              const goods = goodsList[i];
              
              // goods 객체가 유효한지 확인
              if (!goods || !goods.goodsCode) {
                console.warn(`⚠️ 유효하지 않은 상품 데이터 건너뛰기: ${JSON.stringify(goods)}`);
                continue;
              }
              
              const goodsCode = String(goods.goodsCode);
              apiGoodsCodes.add(goodsCode); // API에서 받아온 상품 코드 추가
              
              const docRef = db.collection('giftcards').doc(goodsCode);
              
              // 이미지 URL 우선순위: goodsimg > mmsGoodsimg > goodsImgS > goodsImgB
              const imageUrl = goods.goodsimg || 
                              goods.mmsGoodsimg || 
                              goods.goodsImgS || 
                              goods.goodsImgB ||
                              goods.goodsImg ||
                              goods.image ||
                              goods.img ||
                              '';
              
              // 카테고리명 추출 (우선순위: categoryName1 > category1Name > categoryName > goodsTypeNm)
              const categoryName = goods.categoryName1 || 
                                  goods.category1Name || 
                                  goods.categoryName || 
                                  goods.goodsTypeNm || 
                                  '';
              
              // 검색용 키워드 (API의 srchKeyword, 쉼표로 구분된 검색어)
              const srchKeyword = String(goods.srchKeyword || '');
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
                  categoryName1: String(categoryName),
                  category1Name: String(goods.category1Name || ''),
                  categoryName: String(goods.categoryName || ''),
                  srchKeyword: srchKeyword,
                  lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
              );
              batchCount++;
              totalUpdated++;
              
              // 500개마다 배치 커밋
              if (batchCount >= 500) {
                await batch.commit();
                console.log(`✅ Firestore 업데이트 완료: ${batchCount}개`);
                batchCount = 0;
              }
            }
            
            // 남은 배치 커밋
            if (batchCount > 0) {
              await batch.commit();
              console.log(`✅ Firestore 업데이트 완료: ${batchCount}개`);
            }
            
            console.log(`✅ 페이지 ${currentPage} Firestore 저장 완료: ${goodsList.length}개`);
          } catch (firestoreError) {
            console.error(`❌ 페이지 ${currentPage} Firestore 저장 오류:`, firestoreError);
            // Firestore 오류가 발생해도 다음 페이지 계속 진행
          }
          
          // 마지막 페이지이거나 요청한 개수만큼 가져왔으면 종료
          if (goodsList.length < size || totalLoaded >= totalProducts) {
            break;
          }
          
          currentPage++;
          
          // API 호출 제한을 고려하여 약간의 지연 추가 (선택사항)
          await new Promise(resolve => setTimeout(resolve, 1000)); // 1초 대기
        }
        
        console.log('========================================');
        console.log(`✅ Step 4 완료: 전체 상품 동기화 완료`);
        console.log(`   - 총 로드: ${totalLoaded}개`);
        console.log(`   - 총 업데이트: ${totalUpdated}개`);
        console.log(`   - API 상품 코드 수: ${apiGoodsCodes.size}개`);
        console.log('========================================');
        
        // API 응답에 없는 기존 문서 삭제
        console.log('📝 Step 5: API 응답에 없는 기존 문서 삭제 시작...');
        try {
          const allDocsSnapshot = await db.collection('giftcards').get();
          const allDocs = allDocsSnapshot.docs;
          let deletedCount = 0;
          
          console.log(`📊 Firestore에 있는 문서 수: ${allDocs.length}개`);
          console.log(`📊 API에서 받아온 상품 코드 수: ${apiGoodsCodes.size}개`);
          
          const deleteBatch = db.batch();
          let deleteBatchCount = 0;
          
          for (const doc of allDocs) {
            const docGoodsCode = doc.id;
            if (!apiGoodsCodes.has(docGoodsCode)) {
              // API 응답에 없는 문서 삭제
              deleteBatch.delete(doc.ref);
              deleteBatchCount++;
              deletedCount++;
              
              // 500개마다 배치 커밋
              if (deleteBatchCount >= 500) {
                await deleteBatch.commit();
                console.log(`✅ 삭제 배치 커밋: ${deleteBatchCount}개`);
                deleteBatchCount = 0;
              }
            }
          }
          
          // 남은 배치 커밋
          if (deleteBatchCount > 0) {
            await deleteBatch.commit();
            console.log(`✅ 삭제 배치 커밋: ${deleteBatchCount}개`);
          }
          
          console.log(`✅ Step 5 완료: API 응답에 없는 문서 삭제 완료: 총 ${deletedCount}개 삭제`);
        } catch (deleteError) {
          console.error(`❌ Step 5 실패: 문서 삭제 오류: ${deleteError}`);
          console.error(`   - 오류 메시지: ${deleteError.message}`);
          console.error(`   - 오류 스택: ${deleteError.stack}`);
          // 삭제 오류가 발생해도 동기화는 완료된 것으로 처리
        }
        
        // 동기화 완료 시 상태를 "idle"로 변경
        console.log('📝 Step 6: 동기화 상태를 "idle"로 변경 시작...');
        await db.collection('syncStatus').doc('giftcards').set({
          status: 'idle',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          totalLoaded: totalLoaded,
          totalUpdated: totalUpdated,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('✅ Step 6 완료: 동기화 상태를 "idle"로 변경');
        
        console.log('========================================');
        console.log('🎉 동기화 완료!');
        console.log(`   - 총 로드: ${totalLoaded}개`);
        console.log(`   - 총 업데이트: ${totalUpdated}개`);
        console.log('========================================');
        
        return {
          success: true,
          totalLoaded: totalLoaded,
          totalUpdated: totalUpdated,
        };
      } catch (e) {
        console.error('========================================');
        console.error('❌ 기프트쇼비즈 상품 리스트 동기화 오류 발생!');
        console.error(`❌ 오류 타입: ${e.constructor.name}`);
        console.error(`❌ 오류 메시지: ${e.message}`);
        console.error(`❌ 오류 스택: ${e.stack}`);
        console.error('========================================');
        
        // 오류 발생 시 상태를 "idle"로 변경
        try {
          console.log('📝 오류 상태를 Firestore에 저장 중...');
          await db.collection('syncStatus').doc('giftcards').set({
            status: 'idle',
            lastError: e.message || '알 수 없는 오류',
            errorStack: e.stack || '',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log('✅ 오류 상태 저장 완료');
        } catch (statusError) {
          console.error(`❌ 상태 저장 오류: ${statusError.message}`);
          console.error(`❌ 상태 저장 오류 스택: ${statusError.stack}`);
          console.error(`❌ 동기화 상태 업데이트 오류: ${statusError}`);
        }
        
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
      dev_yn: 'N', // 운영 환경
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
    formData.append('dev_yn', 'N'); // 운영 환경
    formData.append('start', String(start));
    formData.append('size', String(size));
    // 인기순 정렬 (API에서 지원하는 경우)
    formData.append('sort', 'popular'); // 또는 'best', 'rank' 등 API에서 지원하는 값
    
    console.log('Form Data:', formData.toString());
    console.log('각 파라미터 확인:', {
      api_code: '0101',
      custom_auth_code: authCode.trim(),
      custom_auth_token: authToken.trim(),
      dev_yn: 'N', // 운영 환경
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
      // 카테고리 관련 필드 확인
      console.log('📊 카테고리 관련 필드 확인:');
      console.log('   categoryName1:', firstGoods.categoryName1);
      console.log('   categoryName:', firstGoods.categoryName);
      console.log('   category1Name:', firstGoods.category1Name);
      console.log('   category2Name:', firstGoods.category2Name);
      console.log('   goodsTypeNm:', firstGoods.goodsTypeNm);
      // 인기 관련 필드 확인
      console.log('📊 인기 관련 필드 확인:');
      console.log('   saleCount:', firstGoods.saleCount);
      console.log('   viewCount:', firstGoods.viewCount);
      console.log('   rank:', firstGoods.rank);
      console.log('   popular:', firstGoods.popular);
    }

    if (response.data.code === '0000') {
      let goodsList = response.data.result?.goodsList || [];
      
      // 인기순 정렬 시도 (API가 sort 파라미터를 지원하지 않는 경우를 대비)
      // saleCount, viewCount, rank 등 인기 관련 필드가 있으면 정렬
      if (goodsList.length > 0) {
        const firstGoods = goodsList[0];
        // 판매량 기준 정렬 시도
        if (firstGoods.saleCount !== undefined) {
          goodsList = goodsList.sort((a, b) => {
            const saleCountA = parseInt(a.saleCount) || 0;
            const saleCountB = parseInt(b.saleCount) || 0;
            return saleCountB - saleCountA; // 내림차순 (판매량 많은 순)
          });
          console.log('✅ 판매량 기준으로 인기순 정렬 완료');
        }
        // 조회수 기준 정렬 시도
        else if (firstGoods.viewCount !== undefined) {
          goodsList = goodsList.sort((a, b) => {
            const viewCountA = parseInt(a.viewCount) || 0;
            const viewCountB = parseInt(b.viewCount) || 0;
            return viewCountB - viewCountA; // 내림차순 (조회수 많은 순)
          });
          console.log('✅ 조회수 기준으로 인기순 정렬 완료');
        }
        // rank 필드 기준 정렬 시도
        else if (firstGoods.rank !== undefined) {
          goodsList = goodsList.sort((a, b) => {
            const rankA = parseInt(a.rank) || 999999;
            const rankB = parseInt(b.rank) || 999999;
            return rankA - rankB; // 오름차순 (랭크 낮은 순 = 인기 높은 순)
          });
          console.log('✅ 랭크 기준으로 인기순 정렬 완료');
        }
      }
      
      return {
        success: true,
        listNum: response.data.result?.listNum || 0,
        goodsList: goodsList,
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

// 브랜드 목록 조회 함수
async function getBrandList(authCode, authToken) {
  try {
    console.log('🔄 브랜드 목록 조회 시작...');
    
    const formData = new URLSearchParams();
    formData.append('api_code', '0102');
    formData.append('custom_auth_code', authCode.trim());
    formData.append('custom_auth_token', authToken.trim());
    formData.append('dev_yn', 'N');
    
    console.log('📞 브랜드 API 호출:', `${GIFTSHOWBIZ_BASE_URL}/brands`);
    
    const response = await axios.post(
      `${GIFTSHOWBIZ_BASE_URL}/brands`,
      formData.toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );
    
    console.log('✅ 브랜드 API 응답:', response.data.code);
    
    if (response.data.code === '0000') {
      const brandList = response.data.result?.brandList || [];
      console.log(`✅ 브랜드 목록 조회 성공: ${brandList.length}개`);
      return {
        success: true,
        brandList: brandList,
        listNum: response.data.result?.listNum || 0,
      };
    } else {
      console.error('❌ 브랜드 API 오류:', response.data.message);
      return {
        success: false,
        error: response.data.message || '알 수 없는 오류',
      };
    }
  } catch (e) {
    console.error('❌ 브랜드 API 호출 오류:', e);
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

// GET/POST 모두에서 파라미터 수집 (테스트 도구가 POST body로 보낼 수 있음)
function getAdpopcornParams(req) {
  const query = req.query || {};
  const body = req.body || {};
  return { ...query, ...body };
}

// ----- 애드팝콘 오퍼월 리워드 콜백 (스테이징 / 라이브) -----
// 애드팝콘 관리자 > 콜백 서버 설정 > 스테이징 서버 주소에 등록할 URL
exports.adpopcornRewardCallbackStaging = functions.https.onRequest(async (req, res) => {
  try {
    const method = (req.method || '').toUpperCase();
    if (method !== 'GET' && method !== 'POST') {
      res.status(405).json(buildAdpopcornResponse(false, 4000, 'method not allowed'));
      return;
    }
    const params = getAdpopcornParams(req);
    const result = await processAdpopcornRewardCallback(params, true);
    res.set('Content-Type', 'application/json');
    res.status(200).json(result);
  } catch (e) {
    console.error('[AdPopcorn Staging] 콜백 오류:', e);
    res.set('Content-Type', 'application/json');
    res.status(200).json(buildAdpopcornResponse(false, 4000, 'server error'));
  }
});

// 애드팝콘 관리자 > 콜백 서버 설정 > 라이브 서버 주소에 등록할 URL
exports.adpopcornRewardCallback = functions.https.onRequest(async (req, res) => {
  try {
    const method = (req.method || '').toUpperCase();
    if (method !== 'GET' && method !== 'POST') {
      res.status(405).json(buildAdpopcornResponse(false, 4000, 'method not allowed'));
      return;
    }
    const params = getAdpopcornParams(req);
    const result = await processAdpopcornRewardCallback(params, false);
    res.set('Content-Type', 'application/json');
    res.status(200).json(result);
  } catch (e) {
    console.error('[AdPopcorn Live] 콜백 오류:', e);
    res.set('Content-Type', 'application/json');
    res.status(200).json(buildAdpopcornResponse(false, 4000, 'server error'));
  }
});

// 브랜드 목록 조회 API (HTTP 호출 가능)
exports.getBrandList = functions.https.onCall(async (data, context) => {
  try {
    const authCode = getSecret('GIFTSHOWBIZ_AUTH_CODE');
    const authToken = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');
    
    if (!authCode || !authToken) {
      throw new functions.https.HttpsError('internal', 'API 인증 정보를 가져올 수 없습니다.');
    }
    
    const result = await getBrandList(authCode, authToken);
    return result;
  } catch (e) {
    console.error('❌ 브랜드 목록 조회 오류:', e);
    if (e instanceof functions.https.HttpsError) {
      throw e;
    }
    throw new functions.https.HttpsError('internal', `브랜드 목록 조회 실패: ${e.message}`);
  }
});

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
    
    // form-urlencoded 형식으로 요청
    // goods_code는 URL에 포함되므로 파라미터로 보내지 않음
    const formData = new URLSearchParams();
    formData.append('api_code', '0111');
    formData.append('custom_auth_code', authCode.trim());
    formData.append('custom_auth_token', authToken.trim());
    formData.append('dev_yn', 'N'); // 운영 환경
    
    console.log(`📤 Form Data:`, formData.toString());
    console.log(`📤 각 파라미터 확인:`, {
      api_code: '0111',
      custom_auth_code: authCode.trim().substring(0, 10) + '...',
      custom_auth_token: authToken.trim().substring(0, 10) + '...',
      dev_yn: 'N', // 운영 환경
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
          // 카테고리 관련 필드 확인
          console.log('📊 상세정보 카테고리 관련 필드 확인:');
          console.log('   categoryName1:', goodsDetail.categoryName1);
          console.log('   categoryName:', goodsDetail.categoryName);
          console.log('   category1Name:', goodsDetail.category1Name);
          console.log('   category2Name:', goodsDetail.category2Name);
          console.log('   goodsTypeNm:', goodsDetail.goodsTypeNm);
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

// 기프티콘 구매
exports.purchaseGiftCard = functions.https.onCall(async (data, context) => {
  try {
    console.log('📥 purchaseGiftCard 함수 호출됨');
    console.log('📋 받은 data:', JSON.stringify(data, null, 2));
    console.log('📋 data 타입:', typeof data);
    console.log('📋 data가 null인가?', data === null);
    console.log('📋 data가 undefined인가?', data === undefined);
    
    // 인증 확인
    if (!context.auth) {
      console.error('❌ 인증되지 않은 사용자');
      throw new functions.https.HttpsError('unauthenticated', '로그인이 필요합니다.');
    }

    const userId = context.auth.uid;
    console.log('👤 사용자 ID:', userId);
    
    // data 검증
    if (!data) {
      console.error('❌ data가 없습니다.');
      throw new functions.https.HttpsError('invalid-argument', '요청 데이터가 없습니다.');
    }
    
    if (typeof data !== 'object') {
      console.error('❌ data가 객체가 아닙니다. 타입:', typeof data);
      throw new functions.https.HttpsError('invalid-argument', '요청 데이터 형식이 올바르지 않습니다.');
    }
    
    const goodsCode = data.goodsCode;
    const quantity = data.quantity || 1;
    
    console.log('📦 추출된 파라미터:', {
      goodsCode: goodsCode,
      goodsCodeType: typeof goodsCode,
      goodsCodeIsEmpty: !goodsCode || goodsCode === '',
      quantity: quantity,
      quantityType: typeof quantity,
    });

    if (!goodsCode) {
      console.error('❌ goodsCode가 없습니다.');
      console.error('   data 전체:', JSON.stringify(data, null, 2));
      throw new functions.https.HttpsError('invalid-argument', '상품 코드가 필요합니다.');
    }
    
    // goodsCode를 문자열로 변환
    const goodsCodeStr = String(goodsCode).trim();
    if (goodsCodeStr === '') {
      console.error('❌ goodsCode가 빈 문자열입니다.');
      throw new functions.https.HttpsError('invalid-argument', '상품 코드가 비어있습니다.');
    }
    
    console.log('🛒 기프티콘 구매 요청:', { 
      userId, 
      goodsCode: goodsCodeStr, 
      quantity: parseInt(quantity) || 1 
    });

    // Secret 값 가져오기
    const authCode = getSecret('GIFTSHOWBIZ_AUTH_CODE');
    const authToken = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');

    if (!authCode || !authToken) {
      throw new functions.https.HttpsError('internal', 'API 인증 정보를 가져올 수 없습니다.');
    }

    // 사용자 코인 확인
    const userRef = admin.firestore().collection('users').doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', '사용자 정보를 찾을 수 없습니다.');
    }

    const userData = userDoc.data();
    const userCoins = userData.coins || 0;

    // 사용자 전화번호 확인 (다양한 필드명 지원)
    console.log('📞 사용자 전화번호 확인:');
    console.log('   userData.phone:', userData.phone);
    console.log('   userData.phoneNumber:', userData.phoneNumber);
    console.log('   userData.phone_number:', userData.phone_number);
    console.log('   userData 전체 키:', Object.keys(userData));

    // 상품 상세 정보 조회 (가격 확인) - 직접 API 호출
    const detailApiUrl = `${GIFTSHOWBIZ_BASE_URL}/goods/${goodsCodeStr}`;
    const detailFormData = new URLSearchParams();
    detailFormData.append('api_code', '0111');
    detailFormData.append('custom_auth_code', authCode.trim());
    detailFormData.append('custom_auth_token', authToken.trim());
    detailFormData.append('dev_yn', 'N'); // 운영 환경
    // goods_code는 URL에 포함되므로 파라미터로 보내지 않음

    let detailResponse;
    try {
      console.log('📞 상품 상세 정보 조회 API 호출:', {
        url: detailApiUrl,
        goodsCode: goodsCodeStr,
        dev_yn: 'N', // 운영 환경
      });
      
      detailResponse = await axios.post(
        detailApiUrl,
        detailFormData.toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          timeout: 30000,
        }
      );
      
      console.log('📥 상품 상세 정보 API 응답:', {
        status: detailResponse.status,
        code: detailResponse.data?.code,
        message: detailResponse.data?.message,
        hasResult: !!detailResponse.data?.result,
        hasGoodsDetail: !!detailResponse.data?.result?.goodsDetail,
        hasDirectGoodsDetail: !!detailResponse.data?.goodsDetail,
      });
    } catch (error) {
      console.error('❌ 상품 정보 조회 실패:', error.message);
      if (error.response) {
        console.error('   응답 상태:', error.response.status);
        console.error('   응답 데이터:', JSON.stringify(error.response.data, null, 2));
      }
      throw new functions.https.HttpsError('not-found', `상품 정보를 찾을 수 없습니다. (${error.message})`);
    }

    if (!detailResponse.data) {
      console.error('❌ API 응답 데이터가 없습니다.');
      throw new functions.https.HttpsError('not-found', '상품 정보를 찾을 수 없습니다. (응답 데이터 없음)');
    }
    
    if (detailResponse.data.code !== '0000') {
      console.error('❌ API 오류 응답:', {
        code: detailResponse.data.code,
        message: detailResponse.data.message,
      });
      throw new functions.https.HttpsError('not-found', `상품 정보를 찾을 수 없습니다. (${detailResponse.data.message || detailResponse.data.code})`);
    }
    
    // getGiftCardDetail과 동일한 방식으로 goodsDetail 추출
    const goodsDetail = detailResponse.data.result?.goodsDetail || detailResponse.data.result || detailResponse.data.goodsDetail || null;
    
    console.log('📋 goodsDetail 추출 시도:', {
      'result?.goodsDetail': detailResponse.data.result?.goodsDetail ? '존재' : '없음',
      'result': detailResponse.data.result ? '존재' : '없음',
      'data.goodsDetail': detailResponse.data.goodsDetail ? '존재' : '없음',
      '최종 goodsDetail': goodsDetail ? '존재' : 'null',
    });
    
    if (!goodsDetail) {
      console.error('❌ goodsDetail이 없습니다.');
      console.error('   전체 응답:', JSON.stringify(detailResponse.data, null, 2));
      throw new functions.https.HttpsError('not-found', '상품 정보를 찾을 수 없습니다. (goodsDetail 없음)');
    }
    
    console.log('✅ goodsDetail 추출 성공:', {
      goodsName: goodsDetail.goodsName || '없음',
      discountPrice: goodsDetail.discountPrice || '없음',
      salePrice: goodsDetail.salePrice || '없음',
    });
    const price = parseInt(goodsDetail.discountPrice || goodsDetail.salePrice || '0');
    const totalPrice = price * quantity;

    console.log('💰 가격 정보:', { price, quantity, totalPrice, userCoins });

    // 코인 부족 확인
    if (userCoins < totalPrice) {
      throw new functions.https.HttpsError('failed-precondition', `코인이 부족합니다. 필요: ${totalPrice}, 보유: ${userCoins}`);
    }

    // 쿠폰 발송 요청 API 호출 (구매 = 쿠폰 발송)
    // TR_ID 생성 (고유값, 최대 25자, 형식: service_YYYYMMDD_HHMMSS)
    const now = new Date();
    const dateStr = now.toISOString().slice(0, 10).replace(/-/g, '');
    const timeStr = now.toTimeString().slice(0, 8).replace(/:/g, '');
    const trId = `canvas_${dateStr}_${timeStr}`.substring(0, 25);
    
    // 전화번호 가져오기 (우선순위: 환경 변수 > 사용자 데이터)
    // 환경 변수에 고정 전화번호가 설정되어 있으면 사용 (테스트용)
    const fixedPhoneNo = getSecret('GIFTSHOWBIZ_PHONE_NO');
    
    let userPhone = '';
    if (fixedPhoneNo && fixedPhoneNo.trim() !== '') {
      // 환경 변수에 고정 전화번호가 있으면 사용
      userPhone = fixedPhoneNo.trim();
      console.log('📞 고정 전화번호 사용 (환경 변수):', userPhone.substring(0, 3) + '****' + userPhone.substring(7));
    } else {
      // 사용자 정보에서 전화번호 가져오기 (다양한 필드명 지원)
      userPhone = userData.phone || 
                   userData.phoneNumber || 
                   userData.phone_number || 
                   '';
      
      console.log('📞 전화번호 추출 (사용자 데이터):');
      console.log('   원본 userPhone:', userPhone);
      
      if (!userPhone || userPhone.trim() === '') {
        console.error('❌ 사용자 전화번호가 없습니다!');
        console.error('   userData:', JSON.stringify(userData, null, 2));
        throw new functions.https.HttpsError('invalid-argument', '전화번호가 등록되어 있지 않습니다. 프로필에서 전화번호를 등록해주세요.');
      }
    }
    
    const callbackNo = userPhone; // 발신번호도 동일한 전화번호 사용
    
    // 파라미터 검증 및 준비
    const phoneNo = userPhone.replace(/-/g, '').trim();
    const callbackNoClean = callbackNo.replace(/-/g, '').trim();
    const mmsTitle = '기프티콘';
    const mmsMsg = `${goodsDetail.goodsName || '기프티콘'} 구매 완료`;
    
    // user_id 준비 (Giftshowbiz 계정 ID - 필수 파라미터)
    // user_id는 Giftshowbiz API를 사용하는 서비스 제공자(우리)의 Giftshowbiz 계정 ID입니다
    // custom_auth_code, custom_auth_token과 함께 사용하는 계정 ID
    const giftshowbizAccountId = getSecret('GIFTSHOWBIZ_USER_ID');
    
    console.log('👤 Giftshowbiz 계정 ID 확인:');
    console.log('   GIFTSHOWBIZ_USER_ID:', giftshowbizAccountId ? `${giftshowbizAccountId.substring(0, 5)}...` : '없음');
    
    // user_id는 Giftshowbiz 계정 ID를 사용
    const giftshowbizUserId = giftshowbizAccountId || 
                              userData.giftshowbizUserId || 
                              userData.giftshowbiz_user_id || 
                              phoneNo; // 폴백: 전화번호 사용
    
    // 파라미터 검증
    console.log('🔍 쿠폰 발송 요청 파라미터 검증:');
    console.log('   goodsCodeStr:', goodsCodeStr, '(비어있음:', goodsCodeStr === '', ')');
    console.log('   trId:', trId, '(비어있음:', trId === '', ')');
    console.log('   phoneNo:', phoneNo, '(비어있음:', phoneNo === '', ')');
    console.log('   callbackNoClean:', callbackNoClean, '(비어있음:', callbackNoClean === '', ')');
    console.log('   mmsTitle:', mmsTitle, '(비어있음:', mmsTitle === '', ')');
    console.log('   mmsMsg:', mmsMsg, '(비어있음:', mmsMsg === '', ')');
    console.log('   giftshowbizUserId:', giftshowbizUserId, '(비어있음:', giftshowbizUserId === '', ')');
    
    if (!goodsCodeStr || goodsCodeStr === '') {
      throw new functions.https.HttpsError('invalid-argument', 'goods_code가 비어있습니다.');
    }
    if (!trId || trId === '') {
      throw new functions.https.HttpsError('internal', 'tr_id 생성 실패');
    }
    if (!phoneNo || phoneNo === '') {
      throw new functions.https.HttpsError('invalid-argument', 'phone_no가 비어있습니다.');
    }
    if (!callbackNoClean || callbackNoClean === '') {
      throw new functions.https.HttpsError('invalid-argument', 'callback_no가 비어있습니다.');
    }
    // user_id 검증 (Giftshowbiz 계정 ID)
    if (!giftshowbizUserId || giftshowbizUserId === '') {
      console.error('❌ Giftshowbiz 계정 ID (user_id)가 설정되지 않았습니다.');
      console.error('   Firebase Console > Functions > 설정 > 환경 변수에서');
      console.error('   GIFTSHOWBIZ_USER_ID_PROD 또는 GIFTSHOWBIZ_USER_ID를 설정해주세요.');
      console.error('   이 값은 Giftshowbiz API 계정 ID입니다.');
      throw new functions.https.HttpsError('internal', 'Giftshowbiz 계정 ID가 설정되지 않았습니다. 환경 변수를 확인해주세요.');
    }
    
    console.log('👤 user_id 준비 완료:');
    console.log('   Giftshowbiz 계정 ID:', giftshowbizUserId);
    console.log('   (이 값은 custom_auth_code, custom_auth_token과 함께 사용하는 계정 ID입니다)');
    
    const apiUrl = `${GIFTSHOWBIZ_BASE_URL}/send`;
    const formData = new URLSearchParams();
    formData.append('api_code', '0204'); // 쿠폰 발송 요청 API
    formData.append('custom_auth_code', authCode.trim());
    formData.append('custom_auth_token', authToken.trim());
    formData.append('dev_yn', 'N'); // 운영 환경
    formData.append('goods_code', goodsCodeStr);
    formData.append('tr_id', trId);
    formData.append('phone_no', phoneNo); // 수신번호 ('-' 제외)
    formData.append('callback_no', callbackNoClean); // 발신번호 ('-' 제외)
    formData.append('mms_title', mmsTitle); // MMS 제목 (최대 10자)
    formData.append('mms_msg', mmsMsg); // MMS 메시지
    formData.append('gubun', 'I'); // 바코드 이미지 수신 (I: 이미지, Y: 핀번호, N: MMS)
    // user_id는 Giftshowbiz에 등록된 회원 ID가 필요하지만, 
    // 현재는 전화번호를 사용하거나 빈 값으로 시도
    // 실제 운영 시에는 Giftshowbiz API 제공업체에 문의하여 테스트용 user_id를 받아야 함
    if (giftshowbizUserId && giftshowbizUserId !== '') {
      formData.append('user_id', String(giftshowbizUserId).trim()); // 회원 ID
    } else {
      // user_id가 없으면 전화번호를 사용
      formData.append('user_id', phoneNo);
      console.warn('⚠️ user_id가 없어서 전화번호를 user_id로 사용합니다:', phoneNo);
    }

    console.log('📞 Giftshowbiz 쿠폰 발송 요청 API 호출:');
    console.log('   URL:', apiUrl);
    console.log('   api_code: 0204');
    console.log('   custom_auth_code:', authCode.trim().substring(0, 10) + '...');
    console.log('   custom_auth_token:', authToken.trim().substring(0, 10) + '...');
    console.log('   dev_yn: N');
    console.log('   goods_code:', goodsCodeStr);
    console.log('   tr_id:', trId);
    console.log('   phone_no:', phoneNo);
    console.log('   callback_no:', callbackNoClean);
    console.log('   mms_title:', mmsTitle);
    console.log('   mms_msg:', mmsMsg);
    console.log('   gubun: I (바코드 이미지 수신)');
    console.log('   user_id:', giftshowbizUserId, '(필수)');
    console.log('   전체 FormData:', formData.toString());

    let response;
    try {
      response = await axios.post(
        apiUrl,
        formData.toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          timeout: 30000,
        }
      );
      console.log('✅ 쿠폰 발송 요청 API 응답 받음:', response.status);
      console.log('📥 응답 데이터:', JSON.stringify(response.data, null, 2));
    } catch (axiosError) {
      console.error('❌ 쿠폰 발송 요청 API 호출 실패:', axiosError.message);
      if (axiosError.response) {
        console.error('   응답 상태:', axiosError.response.status);
        console.error('   응답 헤더:', JSON.stringify(axiosError.response.headers, null, 2));
        console.error('   응답 데이터:', JSON.stringify(axiosError.response.data, null, 2));
        const errorCode = axiosError.response.data?.code || 'UNKNOWN';
        const errorMessage = axiosError.response.data?.message || axiosError.message;
        throw new functions.https.HttpsError('internal', `쿠폰 발송 요청 API 오류 (${errorCode}): ${errorMessage}`);
      }
      throw new functions.https.HttpsError('internal', `쿠폰 발송 요청 API 호출 실패: ${axiosError.message}`);
    }

    // API 응답 확인
    console.log('🔍 API 응답 검증:');
    console.log('   response.data 존재:', !!response.data);
    console.log('   response.data.code:', response.data?.code);
    console.log('   response.data.message:', response.data?.message);
    console.log('   response.data.result:', response.data?.result);
    
    if (!response.data) {
      console.error('❌ API 응답 데이터가 없습니다.');
      throw new functions.https.HttpsError('internal', '쿠폰 발송 요청 API 응답 데이터가 없습니다.');
    }
    
    if (response.data.code === '0000') {
      // 쿠폰 발송 요청 성공 (실제 문자 발송은 하지 않음, 앱 내에서 바로 바코드 표시)
      // 중요: code === '0000'이면 Giftshowbiz 비즈머니가 차감되었을 수 있음
      // 따라서 바코드 정보를 먼저 확인하고, 없으면 구매를 실패 처리해야 함
      console.log('✅ 쿠폰 발송 요청 성공:', response.data);
      
      // 응답에 바로 바코드 정보가 포함되어 있는지 확인 (gubun: 'I'로 설정했으므로 포함될 수 있음)
      // API 규격서에 따르면: response.data.result.result에 pinNo, couponImgUrl, orderNo가 있음
      let giftCardInfo = null;
      const responseData = response.data;
      
      console.log('🔍 쿠폰 발송 응답 분석 (gubun: I - 바코드 이미지 수신):');
      console.log('   responseData 전체 키:', Object.keys(responseData));
      console.log('   responseData.result:', responseData.result);
      console.log('   responseData.result.result:', responseData.result?.result);
      console.log('   responseData.result.result 타입:', typeof responseData.result?.result);
      if (responseData.result?.result) {
        console.log('   responseData.result.result 키:', Object.keys(responseData.result.result));
        console.log('   responseData.result.result 값:', JSON.stringify(responseData.result.result, null, 2));
      }
      console.log('   responseData 전체:', JSON.stringify(responseData, null, 2));
      
      // API 규격서에 따른 응답 구조 파싱
      // 구조: response.data.result.result = { orderNo, pinNo, couponImgUrl }
      if (responseData.result && responseData.result.result) {
        const resultData = responseData.result.result;
        console.log('✅ API 규격서 구조 발견: result.result');
        console.log('   result.result 키:', Object.keys(resultData));
        console.log('   orderNo:', resultData.orderNo);
        console.log('   pinNo:', resultData.pinNo);
        console.log('   couponImgUrl:', resultData.couponImgUrl);
        
        // API 규격서에 따른 필드명 매핑
        giftCardInfo = {
          orderNo: resultData.orderNo || '',
          pinNumber: resultData.pinNo || '', // pinNo → pinNumber로 매핑
          barcodeImage: resultData.couponImgUrl || '', // couponImgUrl → barcodeImage로 매핑
          // pinNo를 바코드 번호로도 사용 (바코드 번호가 없을 경우)
          barcode: resultData.pinNo || '',
        };
        
        console.log('✅ API 규격서 구조에서 바코드 정보 추출 완료:', {
          orderNo: giftCardInfo.orderNo,
          pinNumber: giftCardInfo.pinNumber,
          barcodeImage: giftCardInfo.barcodeImage ? `${giftCardInfo.barcodeImage.substring(0, 50)}...` : '(없음)',
          barcode: giftCardInfo.barcode,
        });
      } else {
        // 기존 방식으로도 확인 (하위 호환성)
        console.log('⚠️ API 규격서 구조가 아닙니다. 기존 방식으로 확인합니다.');
        const possibleFields = [
          'result',
          'couponDetail',
          'coupon',
          'barcodeInfo',
          'barcode',
        ];
        
        for (const field of possibleFields) {
          if (responseData[field]) {
            const info = responseData[field];
            console.log(`   ${field} 필드 확인:`, typeof info, Array.isArray(info) ? '배열' : '객체');
            
            // 배열인 경우 첫 번째 요소 확인
            const checkInfo = Array.isArray(info) ? info[0] : info;
            
            if (checkInfo && typeof checkInfo === 'object') {
              // API 규격서 필드명도 확인
              const hasBarcode = checkInfo.barcode || checkInfo.barcodeNumber || checkInfo.barcode_no || checkInfo.pinNo;
              const hasBarcodeImage = checkInfo.barcodeImage || checkInfo.barcodeImageUrl || checkInfo.barcode_img || checkInfo.barcode_image || checkInfo.couponImgUrl;
              const hasPin = checkInfo.pinNumber || checkInfo.pin || checkInfo.pin_no || checkInfo.pinNo;
              
              console.log(`   ${field} 필드 내용:`, {
                hasBarcode: !!hasBarcode,
                hasBarcodeImage: !!hasBarcodeImage,
                hasPin: !!hasPin,
                keys: Object.keys(checkInfo),
              });
              
              if (hasBarcode || hasBarcodeImage || hasPin) {
                console.log(`✅ ${field} 필드에서 바코드 정보 발견!`);
                giftCardInfo = checkInfo;
                // API 규격서 필드명 매핑
                if (checkInfo.pinNo && !checkInfo.pinNumber) {
                  giftCardInfo.pinNumber = checkInfo.pinNo;
                }
                if (checkInfo.couponImgUrl && !checkInfo.barcodeImage) {
                  giftCardInfo.barcodeImage = checkInfo.couponImgUrl;
                }
                break;
              }
            }
          }
        }
      }
      
      // 직접 응답 데이터에 바코드 정보가 있는지 확인
      if (!giftCardInfo) {
        const directBarcode = responseData.barcode || responseData.barcodeNumber || responseData.barcode_no;
        const directBarcodeImage = responseData.barcodeImage || responseData.barcodeImageUrl || responseData.barcode_img || responseData.barcode_image;
        const directPin = responseData.pinNumber || responseData.pin || responseData.pin_no;
        
        if (directBarcode || directBarcodeImage || directPin) {
          console.log('✅ 응답 데이터에 직접 바코드 정보 포함됨');
          giftCardInfo = responseData;
        }
      }
      
      // 구매 시에는 API 0201을 호출하지 않음
      // PIN 상태 정보는 기본값(pinStatusCd: '01', pinStatusNm: '발행')으로 저장
      // 이후 refreshGiftCardBarcode 함수에서 API 0201을 호출하여 상태 정보만 업데이트
      console.log('ℹ️ 구매 시 API 0201 호출 생략 - PIN 상태는 기본값(01, 발행)으로 저장');
      
      // 바코드 정보 정리 (다양한 필드명 지원)
      // "발행" 같은 상태 메시지는 실제 바코드/PIN 번호가 아니므로 제외
      function isValidBarcodeOrPin(value) {
        if (!value || typeof value !== 'string') return false;
        const trimmed = value.trim();
        // 빈 문자열이거나 "발행" 같은 상태 메시지 제외
        if (trimmed === '' || trimmed === '발행' || trimmed === '발행됨' || trimmed === 'issued') return false;
        // 하이픈, 공백 등을 제거한 후 숫자와 영문으로만 구성된 값인지 확인
        const cleaned = trimmed.replace(/[^0-9A-Za-z]/g, '');
        // 숫자와 영문이 포함되어 있고 최소 3자 이상이면 유효한 바코드/PIN으로 인식
        return /^[0-9A-Za-z]+$/.test(cleaned) && cleaned.length >= 3;
      }
      
      if (giftCardInfo) {
        // 바코드 추출 (유효한 값만)
        // API 규격서: pinNo를 바코드 번호로 사용할 수 있음
        let barcode = '';
        const barcodeCandidates = [
          giftCardInfo.barcode,
          giftCardInfo.barcodeNumber,
          giftCardInfo.barcode_no,
          giftCardInfo.barcodeNo,
          giftCardInfo.barCode,
          giftCardInfo.pinNo, // API 규격서: pinNo도 바코드로 사용 가능
        ];
        for (const candidate of barcodeCandidates) {
          if (isValidBarcodeOrPin(candidate)) {
            barcode = String(candidate).trim();
            break;
          }
        }
        
        // PIN 번호 추출 (유효한 값만)
        // API 규격서: pinNo 필드명 사용
        let pinNumber = '';
        const pinCandidates = [
          giftCardInfo.pinNumber,
          giftCardInfo.pin,
          giftCardInfo.pin_no,
          giftCardInfo.pinNo, // API 규격서 필드명
        ];
        for (const candidate of pinCandidates) {
          if (isValidBarcodeOrPin(candidate)) {
            pinNumber = String(candidate).trim();
            console.log('✅ PIN 번호 추출 성공:', pinNumber);
            break;
          }
        }
        
        // PIN 번호가 없으면 경고
        if (!pinNumber) {
          console.warn('⚠️ PIN 번호를 찾을 수 없습니다. 후보 값들:', pinCandidates);
        }
        
        // 바코드 이미지 URL 추출
        // API 규격서: couponImgUrl 필드명 사용
        const barcodeImage = giftCardInfo.barcodeImage || 
                            giftCardInfo.barcodeImageUrl || 
                            giftCardInfo.barcode_img || 
                            giftCardInfo.barcode_image ||
                            giftCardInfo.couponImgUrl || // API 규격서 필드명
                            '';
        
        // 구매 시 PIN 상태 정보는 기본값으로 설정
        // API 0201에서는 PIN 번호가 나오지 않으므로, 구매 시에는 기본 상태로 저장
        // 이후 refreshGiftCardBarcode에서 API 0201 호출 시 상태 정보만 업데이트
        const pinStatusCd = '01'; // 기본값: 발행
        const pinStatusNm = '발행'; // 기본값: 발행
        
        console.log('📊 PIN 상태 정보 설정 (구매 시 기본값):', {
          pinStatusCd: pinStatusCd,
          pinStatusNm: pinStatusNm,
          note: '구매 시 기본 상태로 저장, 이후 API 0201 호출 시 업데이트',
        });
        
        const barcodeInfo = {
          barcode: barcode,
          barcodeImage: barcodeImage,
          pinNumber: pinNumber,
          expiryDate: giftCardInfo.expiryDate || giftCardInfo.expireDate || giftCardInfo.expiry_date || giftCardInfo.expire_date || '',
          trId: trId,
          orderNo: giftCardInfo.orderNo || '', // API 규격서: orderNo도 저장
          pinStatusCd: pinStatusCd, // PIN 상태 코드 추가
          pinStatusNm: pinStatusNm, // PIN 상태 이름 추가
        };
        
        console.log('✅ 바코드 정보 추출 완료:', {
          hasBarcode: !!barcodeInfo.barcode,
          hasBarcodeImage: !!barcodeInfo.barcodeImage,
          hasPin: !!barcodeInfo.pinNumber,
          hasExpiryDate: !!barcodeInfo.expiryDate,
          barcode: barcodeInfo.barcode || '(없음)',
          barcodeImage: barcodeInfo.barcodeImage ? `${barcodeInfo.barcodeImage.substring(0, 50)}...` : '(없음)',
          pinNumber: barcodeInfo.pinNumber || '(없음)',
          expiryDate: barcodeInfo.expiryDate || '(없음)',
          pinStatusCd: barcodeInfo.pinStatusCd || '(없음)',
          pinStatusNm: barcodeInfo.pinStatusNm || '(없음)',
        });
        console.log('📦 저장될 barcodeInfo 전체:', JSON.stringify(barcodeInfo, null, 2));
        
        // 원본 giftCardInfo에 바코드 정보가 없으면 원본 데이터의 모든 필드를 확인
        if (!barcodeInfo.barcode && !barcodeInfo.barcodeImage && !barcodeInfo.pinNumber) {
          console.warn('⚠️ 바코드 정보가 모두 비어있습니다. 원본 giftCardInfo의 모든 필드를 확인합니다.');
          console.warn('   원본 giftCardInfo 키 목록:', Object.keys(giftCardInfo));
          console.warn('   원본 giftCardInfo 전체:', JSON.stringify(giftCardInfo, null, 2));
          
          // 원본 데이터에서 바코드 관련 필드 직접 확인 (대소문자 구분 없이, 재귀적으로)
          // isValidBarcodeOrPin 함수를 재사용
          function searchForBarcodeInfo(obj, path = '') {
            if (!obj || typeof obj !== 'object') return;
            
            for (const key in obj) {
              const currentPath = path ? `${path}.${key}` : key;
              const value = obj[key];
              const lowerKey = key.toLowerCase();
              
              // 바코드 관련 필드 확인
              if (lowerKey.includes('barcode')) {
                console.log(`   발견: ${currentPath} = ${value}`);
                if (lowerKey.includes('image') || lowerKey.includes('img') || lowerKey.includes('url')) {
                  if (value && typeof value === 'string' && value.trim() !== '') {
                    barcodeInfo.barcodeImage = value.trim();
                  }
                } else {
                  if (value && (typeof value === 'string' || typeof value === 'number') && String(value).trim() !== '') {
                    barcodeInfo.barcode = String(value).trim();
                  }
                }
              }
              
              // PIN 관련 필드 확인
              if (lowerKey.includes('pin')) {
                console.log(`   발견: ${currentPath} = ${value}`);
                if (value && (typeof value === 'string' || typeof value === 'number') && String(value).trim() !== '') {
                  barcodeInfo.pinNumber = String(value).trim();
                }
              }
              
              // 만료일 관련 필드 확인
              if (lowerKey.includes('expir') || lowerKey.includes('expire')) {
                console.log(`   발견: ${currentPath} = ${value}`);
                if (value && typeof value === 'string' && value.trim() !== '') {
                  barcodeInfo.expiryDate = value.trim();
                }
              }
              
              // 중첩된 객체나 배열인 경우 재귀적으로 확인
              if (value && typeof value === 'object' && !Array.isArray(value)) {
                searchForBarcodeInfo(value, currentPath);
              } else if (Array.isArray(value) && value.length > 0) {
                // 배열의 첫 번째 요소 확인
                if (typeof value[0] === 'object') {
                  searchForBarcodeInfo(value[0], `${currentPath}[0]`);
                }
              }
            }
          }
          
          searchForBarcodeInfo(giftCardInfo);
          
          // PIN 번호만 있는 경우, PIN 번호를 바코드 번호로 사용
          if (!barcodeInfo.barcode && !barcodeInfo.barcodeImage && barcodeInfo.pinNumber) {
            console.log('ℹ️ PIN 번호만 있습니다. PIN 번호를 바코드 번호로 사용합니다:', barcodeInfo.pinNumber);
            barcodeInfo.barcode = barcodeInfo.pinNumber;
          }
          
          // barcodeInfo를 giftCardInfo에 할당 (모든 필드 포함)
          giftCardInfo = { ...barcodeInfo };
          console.log('✅ giftCardInfo에 barcodeInfo 할당 완료 (검색 후):', {
            pinNumber: giftCardInfo.pinNumber,
            pinStatusCd: giftCardInfo.pinStatusCd,
            pinStatusNm: giftCardInfo.pinStatusNm,
            barcode: giftCardInfo.barcode,
            barcodeImage: giftCardInfo.barcodeImage,
          });
        } else {
          // barcodeInfo를 giftCardInfo에 할당 (모든 필드 포함)
          giftCardInfo = { ...barcodeInfo };
          console.log('✅ giftCardInfo에 barcodeInfo 할당 완료 (else):', {
            pinNumber: giftCardInfo.pinNumber,
            pinStatusCd: giftCardInfo.pinStatusCd,
            pinStatusNm: giftCardInfo.pinStatusNm,
            barcode: giftCardInfo.barcode,
            barcodeImage: giftCardInfo.barcodeImage,
          });
        }
      } else {
        console.warn('⚠️ 바코드 정보를 찾을 수 없습니다. tr_id만 저장합니다.');
        giftCardInfo = { trId: trId };
      }
      
      // 바코드 정보 검증: 바코드, 바코드 이미지, PIN 번호 중 하나라도 있어야 함
      // 중요: 바코드 정보가 없으면 코인을 차감하지 않고 구매를 실패 처리
      // 이렇게 하면 Giftshowbiz 비즈머니도 차감되지 않음 (쿠폰 발송 요청 API가 실패한 것으로 처리)
      const hasValidBarcodeInfo = giftCardInfo && (
        (giftCardInfo.barcode && giftCardInfo.barcode.trim() !== '') ||
        (giftCardInfo.barcodeImage && giftCardInfo.barcodeImage.trim() !== '') ||
        (giftCardInfo.pinNumber && giftCardInfo.pinNumber.trim() !== '')
      );
      
      if (!hasValidBarcodeInfo) {
        console.error('❌ 바코드 정보가 없습니다. 구매를 실패 처리합니다.');
        console.error('   giftCardInfo:', JSON.stringify(giftCardInfo, null, 2));
        console.error('   ⚠️ 코인은 차감되지 않았으며, Giftshowbiz 비즈머니도 차감되지 않았습니다.');
        throw new functions.https.HttpsError('internal', '기프티콘 바코드 정보를 받을 수 없습니다. 구매가 취소되었으며 코인은 차감되지 않았습니다. 잠시 후 다시 시도해주세요.');
      }

      // 코인 차감 (바코드 정보가 확인된 후에만)
      // 바코드 정보가 없으면 위에서 오류가 발생하므로 여기까지 오지 않음
      const newCoins = userCoins - totalPrice;
      await userRef.update({ coins: newCoins });
      console.log('💰 코인 차감 완료:', { 이전: userCoins, 차감: totalPrice, 이후: newCoins });

      // 구매 내역 저장
      const purchaseData = {
        userId,
        goodsCode: goodsCodeStr,
        goodsName: goodsDetail.goodsName || '',
        goodsImg: goodsDetail.goodsImgB || goodsDetail.goodsimg || goodsDetail.mmsGoodsimg || goodsDetail.goodsImgS || '', // 기프티콘 이미지 URL
        quantity: parseInt(quantity) || 1,
        price,
        totalPrice,
        purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
        trId: trId, // 거래 ID 저장
        giftCardInfo: giftCardInfo, // 쿠폰 상세 정보 (바코드 포함)
      };

      console.log('💾 구매 내역 저장:', purchaseData);
      await admin.firestore().collection('purchases').add(purchaseData);
      console.log('✅ 구매 내역 저장 완료');

      // 보유 기프티콘에 추가 (바코드 정보가 있을 때만)
      if (hasValidBarcodeInfo && giftCardInfo) {
        // 저장 직전에 giftCardInfo 확인
        console.log('🔍 저장 직전 giftCardInfo 확인:');
        console.log('   giftCardInfo 타입:', typeof giftCardInfo);
        console.log('   giftCardInfo 키:', Object.keys(giftCardInfo));
        console.log('   giftCardInfo 전체:', JSON.stringify(giftCardInfo, null, 2));
        console.log('   barcode:', giftCardInfo.barcode);
        console.log('   pinNumber:', giftCardInfo.pinNumber);
        console.log('   barcodeImage:', giftCardInfo.barcodeImage);
        console.log('   pinStatusCd:', giftCardInfo.pinStatusCd);
        console.log('   pinStatusNm:', giftCardInfo.pinStatusNm);
        
        const ownedGiftCardData = {
          userId,
          goodsCode: goodsCodeStr,
          goodsName: goodsDetail.goodsName || '',
          goodsImg: goodsDetail.goodsImgB || goodsDetail.goodsimg || goodsDetail.mmsGoodsimg || goodsDetail.goodsImgS || '', // 기프티콘 이미지 URL
          purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
          trId: trId,
          giftCardInfo: giftCardInfo,
          status: 'active',
        };
        console.log('💾 보유 기프티콘 저장:', JSON.stringify(ownedGiftCardData, null, 2));
        await admin.firestore().collection('ownedGiftCards').add(ownedGiftCardData);
        console.log('✅ 보유 기프티콘 저장 완료');
      } else {
        console.warn('⚠️ 바코드 정보가 없어서 보유 기프티콘에 추가하지 않습니다.');
      }

      // 코인 내역 추가
      const coinHistoryData = {
        userId,
        amount: -totalPrice,
        type: 'giftcard_purchase',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        goodsCode: goodsCodeStr,
        goodsName: goodsDetail.goodsName || '',
      };
      console.log('💾 코인 내역 저장:', coinHistoryData);
      await admin.firestore().collection('coinHistory').add(coinHistoryData);
      console.log('✅ 코인 내역 저장 완료');

      return {
        success: true,
        message: '구매가 완료되었습니다.',
        remainingCoins: newCoins,
        purchaseInfo: purchaseData,
      };
    } else {
      // 쿠폰 발송 실패
      console.error('═══════════════════════════════════════');
      console.error('❌ 쿠폰 발송 실패');
      console.error('───────────────────────────────────────');
      console.error('   응답 코드:', response.data.code);
      console.error('   응답 메시지:', response.data.message);
      console.error('   응답 전체:', JSON.stringify(response.data, null, 2));
      console.error('───────────────────────────────────────');
      console.error('   요청 파라미터 확인:');
      console.error('     goods_code:', goodsCodeStr);
      console.error('     tr_id:', trId);
      console.error('     phone_no:', phoneNo);
      console.error('     callback_no:', callbackNoClean);
      console.error('     mms_title:', mmsTitle);
      console.error('     mms_msg:', mmsMsg);
      console.error('     gubun: I');
      console.error('     user_id:', giftshowbizUserId, '(필수)');
      console.error('═══════════════════════════════════════');
      throw new functions.https.HttpsError('internal', response.data.message || '쿠폰 발송에 실패했습니다.');
    }
  } catch (e) {
    console.error('❌ 기프티콘 구매 오류:', e);
    if (e instanceof functions.https.HttpsError) {
      throw e;
    }
      throw new functions.https.HttpsError('internal', `구매 처리 중 오류가 발생했습니다: ${e.message}`);
    }
  });

// 기프티콘 바코드 정보 재조회 (이미 구매한 기프티콘의 바코드 정보를 다시 가져오기)
exports.refreshGiftCardBarcode = functions.https.onCall(async (data, context) => {
  try {
    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '로그인이 필요합니다.');
    }

    const userId = context.auth.uid;
    const { trId, useResend = false } = data; // useResend: 재전송 API 사용 여부

    console.log('🔄 기프티콘 바코드 정보 재조회 요청:', { userId, trId, useResend });

    if (!trId) {
      throw new functions.https.HttpsError('invalid-argument', '거래 ID가 필요합니다.');
    }

    // Secret 값 가져오기
    const authCode = getSecret('GIFTSHOWBIZ_AUTH_CODE');
    const authToken = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');

    if (!authCode || !authToken) {
      throw new functions.https.HttpsError('internal', 'API 인증 정보를 가져올 수 없습니다.');
    }

    // 보유 기프티콘 정보 가져오기
    const ownedCardsQuery = await db.collection('ownedGiftCards')
      .where('userId', '==', userId)
      .where('trId', '==', trId)
      .limit(1)
      .get();

    if (ownedCardsQuery.empty) {
      throw new functions.https.HttpsError('not-found', '보유 기프티콘을 찾을 수 없습니다.');
    }

    const ownedCardDoc = ownedCardsQuery.docs[0];
    const ownedCardData = ownedCardDoc.data();
    const goodsCode = ownedCardData.goodsCode || '';

    console.log('📦 기존 구매 정보:', {
      goodsCode: goodsCode,
      trId: trId,
      hasBarcodeInfo: !!ownedCardData.giftCardInfo,
    });

    // 재전송 API 사용 여부에 따라 분기
    if (useResend && goodsCode) {
      console.log('📤 재전송 API 사용: 기존 구매 정보로 다시 발송 요청');
      
      // 고정 전화번호 가져오기 (참고용, 재전송 API에는 필요 없음)
      const fixedPhoneNo = getSecret('GIFTSHOWBIZ_PHONE_NO');
      const phoneNo = fixedPhoneNo ? fixedPhoneNo.replace(/-/g, '').trim() : '01057049470';
      const callbackNo = phoneNo;
      
      console.log('📞 전화번호 확인 (참고용, 재전송 API에는 사용 안 함):', {
        phone_no: phoneNo,
        callback_no: callbackNo,
        source: fixedPhoneNo ? 'GIFTSHOWBIZ_PHONE_NO' : '기본값',
      });
      
      // Giftshowbiz User ID
      const giftshowbizAccountId = getSecret('GIFTSHOWBIZ_USER_ID');
      const giftshowbizUserId = giftshowbizAccountId || 'cymoon38@gmail.com';
      
      // 재전송 API 호출 (0203 - 쿠폰 재전송 API)
      // 주의: 재전송 API는 phone_no, callback_no 파라미터가 필요 없음
      const resendApiUrl = `${GIFTSHOWBIZ_BASE_URL}/resend`;
      const resendFormData = new URLSearchParams();
      resendFormData.append('api_code', '0203'); // 쿠폰 재전송 API
      resendFormData.append('custom_auth_code', authCode.trim());
      resendFormData.append('custom_auth_token', authToken.trim());
      resendFormData.append('dev_yn', 'N');
      resendFormData.append('tr_id', trId); // 거래 ID (필수)
      resendFormData.append('sms_flag', 'N'); // N: MMS (기본값), Y: SMS
      resendFormData.append('user_id', String(giftshowbizUserId).trim()); // 회원 ID (필수)

      console.log('📞 재전송 API 호출 (0203):', {
        api_code: '0203',
        tr_id: trId,
        sms_flag: 'N',
        user_id: giftshowbizUserId,
        url: resendApiUrl,
        note: '재전송 API는 phone_no, callback_no 파라미터가 필요 없습니다',
      });

      const resendResponse = await axios.post(
        resendApiUrl,
        resendFormData.toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          timeout: 30000,
        }
      );

      console.log('📥 재전송 API 응답:', JSON.stringify(resendResponse.data, null, 2));

      if (resendResponse.data && resendResponse.data.code === '0000') {
        // 재전송 성공 - 재전송 API(0203)는 result가 null이므로 쿠폰 상세 정보 조회로 바코드 정보 가져오기
        console.log('✅ 재전송 성공 (code: 0000), 쿠폰 상세 정보 조회로 바코드 정보 가져오기');
        // 아래 쿠폰 상세 정보 조회 로직으로 계속 진행
      } else {
        console.warn('⚠️ 재전송 API 실패:', resendResponse.data);
        console.warn('   쿠폰 상세 정보 조회로 전환');
      }
    }

    // 쿠폰 상세 정보 조회 API 호출 (기존 방식)
    const couponDetailUrl = `${GIFTSHOWBIZ_BASE_URL}/coupons`;
    const couponDetailFormData = new URLSearchParams();
    couponDetailFormData.append('api_code', '0201'); // 쿠폰 상세 정보 API
    couponDetailFormData.append('custom_auth_code', authCode.trim());
    couponDetailFormData.append('custom_auth_token', authToken.trim());
    couponDetailFormData.append('dev_yn', 'N');
    couponDetailFormData.append('tr_id', trId);

    console.log('📞 쿠폰 상세 정보 조회 API 호출 (바코드 정보 재조회):', { tr_id: trId });

    const couponDetailResponse = await axios.post(
      couponDetailUrl,
      couponDetailFormData.toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        timeout: 30000,
      }
    );

    console.log('📥 쿠폰 상세 정보 조회 API 응답:', {
      status: couponDetailResponse.status,
      code: couponDetailResponse.data?.code,
      message: couponDetailResponse.data?.message,
      전체응답: JSON.stringify(couponDetailResponse.data, null, 2),
    });

    if (couponDetailResponse.data && couponDetailResponse.data.code === '0000') {
      // 쿠폰 상세 정보는 result.result 구조일 수 있음 (API 규격서 참고)
      const responseData = couponDetailResponse.data;
      
      // API 규격서 구조 확인: response.data.result.result
      let detailInfo = null;
      if (responseData.result && responseData.result.result) {
        detailInfo = responseData.result.result;
        console.log('✅ API 규격서 구조 발견: result.result');
      } else {
        // 기존 방식 (하위 호환성)
        detailInfo = responseData.result || 
                    responseData.couponDetail || 
                    responseData.coupon ||
                    responseData.data ||
                    responseData;
      }

      let giftCardInfo = null;
      if (Array.isArray(detailInfo) && detailInfo.length > 0) {
        giftCardInfo = detailInfo[0];
      } else if (typeof detailInfo === 'object' && detailInfo !== null) {
        giftCardInfo = detailInfo;
        
        // API 규격서 필드명 매핑 (pinNo → pinNumber, couponImgUrl → barcodeImage)
        if (giftCardInfo.pinNo && !giftCardInfo.pinNumber) {
          giftCardInfo.pinNumber = giftCardInfo.pinNo;
        }
        if (giftCardInfo.couponImgUrl && !giftCardInfo.barcodeImage) {
          giftCardInfo.barcodeImage = giftCardInfo.couponImgUrl;
        }
        if (giftCardInfo.pinNo && !giftCardInfo.barcode) {
          giftCardInfo.barcode = giftCardInfo.pinNo;
        }
      }

      if (giftCardInfo) {
        // 바코드 정보 추출 (유효한 값만)
        function isValidBarcodeOrPin(value) {
          if (!value || typeof value !== 'string') return false;
          const trimmed = value.trim();
          if (trimmed === '' || trimmed === '발행' || trimmed === '발행됨' || trimmed === 'issued') return false;
          return /^[0-9A-Za-z]+$/.test(trimmed) && trimmed.length >= 3;
        }

        console.log('🔍 바코드/PIN 추출 시작');
        console.log('   giftCardInfo 전체 키:', Object.keys(giftCardInfo));
        console.log('   giftCardInfo 값들:', JSON.stringify(giftCardInfo, null, 2));
        
        let barcode = '';
        const barcodeCandidates = [
          giftCardInfo.barcode,
          giftCardInfo.barcodeNumber,
          giftCardInfo.barcode_no,
          giftCardInfo.barcodeNo,
          giftCardInfo.barCode,
          giftCardInfo.pinNo,
        ];
        console.log('   바코드 후보:', barcodeCandidates);
        for (const candidate of barcodeCandidates) {
          if (isValidBarcodeOrPin(candidate)) {
            barcode = String(candidate).trim();
            console.log('   ✅ 유효한 바코드 발견:', barcode);
            break;
          }
        }
        if (!barcode) {
          console.warn('   ⚠️ 유효한 바코드를 찾을 수 없습니다');
        }

        let pinNumber = '';
        const pinCandidates = [
          giftCardInfo.pinNumber,
          giftCardInfo.pin,
          giftCardInfo.pin_no,
          giftCardInfo.pinNo,
        ];
        console.log('   PIN 후보:', pinCandidates);
        for (const candidate of pinCandidates) {
          if (isValidBarcodeOrPin(candidate)) {
            pinNumber = String(candidate).trim();
            console.log('   ✅ 유효한 PIN 발견:', pinNumber);
            break;
          }
        }
        if (!pinNumber) {
          console.warn('   ⚠️ 유효한 PIN을 찾을 수 없습니다');
        }

        const barcodeImage = giftCardInfo.barcodeImage || 
                            giftCardInfo.barcodeImageUrl || 
                            giftCardInfo.barcode_img || 
                            giftCardInfo.barcode_image ||
                            giftCardInfo.couponImgUrl ||
                            '';

        // pinStatusCd와 pinStatusNm 추출 (API 응답에서)
        // API 0201에서는 PIN 번호가 나오지 않으므로 상태 정보만 추출
        const pinStatusCd = giftCardInfo.pinStatusCd || 
                           giftCardInfo.pin_status_cd || 
                           giftCardInfo.pin_status_code ||
                           giftCardInfo.statusCd ||
                           '';
        const pinStatusNm = giftCardInfo.pinStatusNm || 
                           giftCardInfo.pin_status_nm || 
                           giftCardInfo.pin_status_name ||
                           giftCardInfo.statusNm ||
                           '';
        
        console.log('📊 PIN 상태 정보 추출 (API 0201):', {
          pinStatusCd: pinStatusCd || '(없음)',
          pinStatusNm: pinStatusNm || '(없음)',
          note: 'PIN 번호는 업데이트하지 않고 상태 정보만 업데이트',
        });

        // 기존 giftCardInfo 가져오기 (PIN 번호 보존)
        const existingOwnedCard = ownedCardData.giftCardInfo || {};
        console.log('📦 기존 giftCardInfo:', {
          pinNumber: existingOwnedCard.pinNumber || '(없음)',
          pinStatusCd: existingOwnedCard.pinStatusCd || '(없음)',
          pinStatusNm: existingOwnedCard.pinStatusNm || '(없음)',
        });

        // 업데이트할 pinStatusCd와 pinStatusNm 결정
        // API에서 추출한 값이 있으면 사용, 없으면 기존 값 유지, 둘 다 없으면 기본값
        const updatedPinStatusCd = pinStatusCd || existingOwnedCard.pinStatusCd || '01';
        const updatedPinStatusNm = pinStatusNm || existingOwnedCard.pinStatusNm || '발행';

        console.log('📦 업데이트될 PIN 상태 정보:', {
          기존_pinNumber: existingOwnedCard.pinNumber || '(없음)',
          기존_pinStatusCd: existingOwnedCard.pinStatusCd || '(없음)',
          기존_pinStatusNm: existingOwnedCard.pinStatusNm || '(없음)',
          업데이트_pinStatusCd: updatedPinStatusCd,
          업데이트_pinStatusNm: updatedPinStatusNm,
          note: 'PIN 번호는 기존 값 유지, 상태 정보만 업데이트',
        });

        // 보유 기프티콘 업데이트 (pinStatusCd와 pinStatusNm만)
        await ownedCardDoc.ref.update({
          'giftCardInfo.pinStatusCd': updatedPinStatusCd,
          'giftCardInfo.pinStatusNm': updatedPinStatusNm,
          'giftCardInfo.lastRefreshed': admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('✅ 보유 기프티콘 PIN 상태 정보 업데이트 완료 (pinStatusCd, pinStatusNm만)');

        // 구매 내역도 업데이트
        const purchasesQuery = await admin.firestore()
          .collection('purchases')
          .where('userId', '==', userId)
          .where('trId', '==', trId)
          .limit(1)
          .get();

        if (!purchasesQuery.empty) {
          const purchaseRef = purchasesQuery.docs[0].ref;
          await purchaseRef.update({
            'giftCardInfo.pinStatusCd': updatedPinStatusCd,
            'giftCardInfo.pinStatusNm': updatedPinStatusNm,
            'giftCardInfo.lastRefreshed': admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log('✅ 구매 내역 PIN 상태 정보 업데이트 완료 (pinStatusCd, pinStatusNm만)');
        }

        // 반환할 giftCardInfo 생성 (기존 정보 유지 + 업데이트된 상태 정보)
        const updatedGiftCardInfo = {
          ...existingOwnedCard,
          pinStatusCd: updatedPinStatusCd,
          pinStatusNm: updatedPinStatusNm,
        };

        return {
          success: true,
          message: 'PIN 상태 정보를 성공적으로 업데이트했습니다.',
          giftCardInfo: updatedGiftCardInfo,
        };
      } else {
        throw new functions.https.HttpsError('not-found', '쿠폰 정보를 찾을 수 없습니다.');
      }
    } else {
      throw new functions.https.HttpsError('internal', couponDetailResponse.data?.message || '쿠폰 정보 조회에 실패했습니다.');
    }
  } catch (e) {
    console.error('❌ 기프티콘 바코드 정보 재조회 오류:', e);
    if (e instanceof functions.https.HttpsError) {
      throw e;
    }
    throw new functions.https.HttpsError('internal', `바코드 정보 조회 중 오류가 발생했습니다: ${e.message}`);
  }
});

