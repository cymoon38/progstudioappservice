const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// 오늘 날짜를 YYYY-MM-DD 형식으로 반환 (한국 시간 기준)
function getTodayDateString() {
  // 한국 시간(UTC+9)으로 현재 날짜 계산
  const now = new Date();
  const koreaTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Seoul' }));
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
    
    // 지난 24시간 기준 시간 계산
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    console.log(`📅 추첨 대상 기간: ${twentyFourHoursAgo.toISOString()} ~ ${now.toISOString()}`);
    
    // 1. 인기작품에서 먼저 추첨 (지난 24시간 내 게시물만)
    const popularPostsSnapshot = await db
        .collection('posts')
        .where('isPopular', '==', true)
        .where('type', '!=', 'notice') // 공지사항 제외
        .where('date', '>=', admin.firestore.Timestamp.fromDate(twentyFourHoursAgo)) // 지난 24시간 내
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
    
    // 2. 일반 작품에서 추첨 (인기작품 당첨자 제외, 지난 24시간 내 게시물만)
    const generalPostsSnapshot = await db
        .collection('posts')
        .where('isPopular', '==', false) // 인기작품이 아닌 것
        .where('type', '!=', 'notice') // 공지사항 제외
        .where('date', '>=', admin.firestore.Timestamp.fromDate(twentyFourHoursAgo)) // 지난 24시간 내
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

