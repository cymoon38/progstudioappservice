const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const axios = require('axios');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();

// 기프트쇼비즈 API 설정
const GIFTSHOWBIZ_BASE_URL = 'https://bizapi.giftishow.com/bizApi';
const GIFTSHOWBIZ_DEFAULT_PHONE = '01057049470'; // API 전달용 기본 전화번호 (phone_no, callback_no)

// 환경 변수에서 Secret 가져오기
// Firebase Console > Functions > 설정 > 환경 변수에서 설정
function getSecret(secretName) {
  // 상용 환경 키 사용 (운영 환경)
  if (secretName === 'GIFTSHOWBIZ_AUTH_CODE') {
    // 상용 환경 키
    return process.env.GIFTSHOWBIZ_AUTH_CODE_PROD || 'REAL56bf67edd37e4733af8ddba2d5387150';
  }
  if (secretName === 'GIFTSHOWBIZ_AUTH_TOKEN') {
    // 상용 환경 토큰 (auth_code와 다른 값 사용)
    return process.env.GIFTSHOWBIZ_AUTH_TOKEN_PROD || '3RXSN9gtle+bE63cH3vnSg==';
  }
  if (secretName === 'GIFTSHOWBIZ_USER_ID_PROD') {
    // 상용 환경 User ID (fallback)
    return process.env.GIFTSHOWBIZ_USER_ID_PROD || 'cymoon38@gmail.com';
  }
  return process.env[secretName] || '';
}

// 기프트쇼비즈 API 인증 정보
const GIFTSHOWBIZ_AUTH_CODE = getSecret('GIFTSHOWBIZ_AUTH_CODE');
const GIFTSHOWBIZ_AUTH_TOKEN = getSecret('GIFTSHOWBIZ_AUTH_TOKEN');
const GIFTSHOWBIZ_USER_ID = getSecret('GIFTSHOWBIZ_USER_ID_PROD'); // 쿠폰 발송 시 회원 식별용 (기프트쇼비즈에 등록된 ID)

// 애드팝콘 리워드 서버 검증용 해시 키 (운영/스테이징)
const ADPOPCORN_HASH_KEY = process.env.ADPOPCORN_HASH_KEY || 'f0914cb6664e4991';
const ADPOPCORN_HASH_KEY_STAGING =
  process.env.ADPOPCORN_HASH_KEY_STAGING || ADPOPCORN_HASH_KEY;

// 일일 추첨: 매일 오후 5시, 최근 24시간 인기작품 1명(500코인)·일반작품 1명(300코인)
function getTodayDateString() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function getPostAuthors(posts) {
  const uids = new Set();
  for (const p of posts) {
    if (p.authorUid && p.authorUid.trim()) uids.add(p.authorUid.trim());
  }
  return uids;
}

function pickRandom(iterable) {
  const arr = Array.from(iterable);
  return arr[Math.floor(Math.random() * arr.length)];
}

exports.runDailyLottery = functions.pubsub
  .schedule('0 17 * * *')
  .timeZone('Asia/Seoul')
  .onRun(async () => {
    try {
      console.log('🎰 일일 작품 추첨 시작 (오후 5시)');
      const today = getTodayDateString();
      const todayRef = db.collection('lotteryResults').doc(today);
      const todaySnap = await todayRef.get();
      if (todaySnap.exists && (todaySnap.data().popularWinner || todaySnap.data().normalWinner)) {
        console.log('⚠️ 오늘 추첨은 이미 실행되었습니다.');
        return null;
      }

      const ts = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));

      let popularWinnerUid = null, popularWinnerName = null, popularWinnerPostId = null;
      const popularSnap = await db.collection('posts').where('isPopular', '==', true).where('date', '>=', ts).get();
      const popularPosts = popularSnap.docs.map((doc) => {
        const d = doc.data();
        return { id: doc.id, authorUid: d.authorUid || '', author: d.author || '', type: d.type };
      }).filter((p) => (p.authorUid || p.author) && p.type !== 'notice');

      if (popularPosts.length > 0) {
        const popularAuthors = getPostAuthors(popularPosts);
        if (popularAuthors.size > 0) {
          popularWinnerUid = pickRandom(popularAuthors);
          popularWinnerPostId = popularPosts.find((p) => p.authorUid === popularWinnerUid)?.id || null;
          const us = await db.collection('users').doc(popularWinnerUid).get();
          popularWinnerName = us.exists ? (us.data().name || '알 수 없음') : '알 수 없음';
          await db.collection('users').doc(popularWinnerUid).update({ coins: admin.firestore.FieldValue.increment(500) });
          await db.collection('coinHistory').add({ userId: popularWinnerUid, amount: 500, type: '인기작품 추첨 당첨', timestamp: admin.firestore.FieldValue.serverTimestamp() });
          console.log('🎉 인기작품 당첨:', popularWinnerName, '500코인');
        }
      }

      let normalWinnerUid = null, normalWinnerName = null, normalWinnerPostId = null;
      const allSnap = await db.collection('posts').where('date', '>=', ts).get();
      const allPosts = allSnap.docs.map((doc) => {
        const d = doc.data();
        return { id: doc.id, authorUid: d.authorUid || '', author: d.author || '', type: d.type, isPopular: d.isPopular === true };
      }).filter((p) => (p.authorUid || p.author) && p.type !== 'notice' && !p.isPopular);

      if (allPosts.length > 0) {
        const allAuthors = getPostAuthors(allPosts);
        const normalAuthors = popularWinnerUid ? [...allAuthors].filter((uid) => uid !== popularWinnerUid) : [...allAuthors];
        if (normalAuthors.length > 0) {
          normalWinnerUid = pickRandom(normalAuthors);
          normalWinnerPostId = allPosts.find((p) => p.authorUid === normalWinnerUid)?.id || null;
          const us = await db.collection('users').doc(normalWinnerUid).get();
          normalWinnerName = us.exists ? (us.data().name || '알 수 없음') : '알 수 없음';
          await db.collection('users').doc(normalWinnerUid).update({ coins: admin.firestore.FieldValue.increment(300) });
          await db.collection('coinHistory').add({ userId: normalWinnerUid, amount: 300, type: '일반작품 추첨 당첨', timestamp: admin.firestore.FieldValue.serverTimestamp() });
          console.log('🎉 일반작품 당첨:', normalWinnerName, '300코인');
        }
      }

      await todayRef.set({
        date: today,
        popularWinner: popularWinnerUid ? { userId: popularWinnerUid, name: popularWinnerName, reward: 500, postId: popularWinnerPostId } : null,
        normalWinner: normalWinnerUid ? { userId: normalWinnerUid, name: normalWinnerName, reward: 300, postId: normalWinnerPostId } : null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('✅ 일일 작품 추첨 완료');
      return null;
    } catch (error) {
      console.error('❌ 일일 추첨 오류:', error);
      throw error;
    }
  });

// 기프티콘 목록 조회
exports.getGiftCardList = functions.https.onCall(async (data, context) => {
  try {
    console.log('📋 기프티콘 목록 조회 요청');

    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
    }

    // 예전과 동일하게 상품 리스트 API(0101, /goods) 사용
    const apiUrl = `${GIFTSHOWBIZ_BASE_URL}/goods`;
    const formData = new URLSearchParams();
    formData.append('api_code', '0101'); // 상품 리스트 조회
    formData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
    formData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
    formData.append('dev_yn', 'N'); // 운영 환경

    console.log('📞 Giftshowbiz API 호출:', apiUrl);
    console.log('   api_code: 0101');
    console.log('   dev_yn: N (운영 환경)');

    const response = await axios.post(apiUrl, formData.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      timeout: 30000,
    });

    console.log('✅ API 응답 받음:', response.status);

    if (response.data && response.data.code === '0000') {
      // 성공 응답
      const giftCards = response.data.result || response.data.data || [];
      console.log('📦 기프티콘 개수:', giftCards.length);

      // 기프티콘 데이터 정리
      const formattedGiftCards = giftCards.map((card) => ({
        goodsCode: card.goodsCode || card.goods_code || '',
        goodsName: card.goodsName || card.goods_name || '',
        goodsPrice: card.goodsPrice || card.goods_price || 0,
        goodsImg: card.goodsImg || card.goods_img || '',
        brandName: card.brandName || card.brand_name || '',
        categoryName: card.categoryName || card.category_name || '',
        description: card.description || '',
      }));

      return {
        success: true,
        giftCards: formattedGiftCards,
      };
    } else {
      // 오류 응답
      console.error('❌ API 오류:', response.data);
      throw new functions.https.HttpsError(
        'internal',
        response.data?.message || '기프티콘 목록 조회에 실패했습니다.'
      );
    }
  } catch (error) {
    console.error('❌ 기프티콘 목록 조회 오류:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', `기프티콘 목록 조회 중 오류가 발생했습니다: ${error.message}`);
  }
});

// 기프티콘 상세 정보 조회
exports.getGiftCardDetail = functions.https.onCall(async (data, context) => {
  try {
    console.log('📋 기프티콘 상세 정보 조회 요청');

    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
    }

    const { goodsCode } = data;

    if (!goodsCode) {
      throw new functions.https.HttpsError('invalid-argument', '상품 코드가 필요합니다.');
    }

    // 상품 상세는 /goods/{goodsCode} + api_code 0111 사용 (/detail은 404 발생 가능)
    const apiUrl = `https://bizapi.giftishow.com/bizApi/goods/${String(goodsCode)}`;
    const formData = new URLSearchParams();
    formData.append('api_code', '0111'); // 상품 상세 정보 조회
    formData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
    formData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
    formData.append('dev_yn', 'N'); // 운영 환경

    console.log('📞 Giftshowbiz API 호출:', apiUrl);
    console.log('   api_code: 0111, goods_code:', goodsCode);

    let response;
    try {
      response = await axios.post(apiUrl, formData.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        timeout: 30000,
      });
    } catch (axiosError) {
      const status = axiosError.response?.status;
      const msg = axiosError.response?.data?.message || axiosError.message;
      console.error('❌ Giftshowbiz API 요청 실패:', status, msg);
      if (status === 404) {
        throw new functions.https.HttpsError('not-found', '해당 기프티콘 상세 정보를 찾을 수 없습니다.');
      }
      throw new functions.https.HttpsError('internal', `기프티콘 상세 정보 조회 실패: ${msg}`);
    }

    console.log('✅ API 응답 받음:', response.status);

    if (!response.data || response.data.code !== '0000') {
      console.error('❌ API 오류 응답:', response.data);
      throw new functions.https.HttpsError(
        'not-found',
        response.data?.message || '기프티콘 상세 정보를 찾을 수 없습니다.'
      );
    }

    const raw = response.data.result?.goodsDetail || response.data.result || response.data.data || response.data.goodsDetail || {};
    const giftCard = typeof raw === 'object' ? raw : {};

    const formattedGiftCard = {
      goodsCode: giftCard.goodsCode || giftCard.goods_code || String(goodsCode),
      goodsName: giftCard.goodsName || giftCard.goods_name || '',
      goodsPrice: giftCard.goodsPrice || giftCard.goods_price || giftCard.discountPrice || giftCard.salePrice || 0,
      goodsImg: giftCard.goodsImg || giftCard.goods_img || '',
      goodsImgB: giftCard.goodsImgB || giftCard.goods_img_b || giftCard.goodsImg || giftCard.goods_img || '',
      goodsImgS: giftCard.goodsImgS || giftCard.goods_img_s || '',
      mmsGoodsimg: giftCard.mmsGoodsimg || giftCard.mms_goodsimg || '',
      brandName: giftCard.brandName || giftCard.brand_name || '',
      categoryName: giftCard.categoryName || giftCard.category_name || '',
      description: giftCard.description || giftCard.desc || '',
      content: giftCard.content || giftCard.description || giftCard.desc || '',
      expiryDate: giftCard.expiryDate || giftCard.expiry_date || '',
      usageInfo: giftCard.usageInfo || giftCard.usage_info || '',
      discountPrice: giftCard.discountPrice ?? giftCard.discount_price ?? giftCard.goodsPrice ?? giftCard.goods_price,
      salePrice: giftCard.salePrice ?? giftCard.sale_price ?? giftCard.goodsPrice ?? giftCard.goods_price,
    };

    return {
      success: true,
      goodsDetail: formattedGiftCard,
    };
  } catch (error) {
    console.error('❌ 기프티콘 상세 정보 조회 오류:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', `기프티콘 상세 정보 조회 중 오류가 발생했습니다: ${error.message}`);
  }
});

// 기프티콘 구매
exports.purchaseGiftCard = functions.https.onCall(async (data, context) => {
  try {
    console.log('📥 purchaseGiftCard 함수 호출됨');
    console.log('   받은 데이터:', JSON.stringify(data, null, 2));

    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
    }

    const userId = context.auth.uid;
    const { goodsCode, quantity = 1 } = data;

    // 필수 파라미터 확인
    if (!goodsCode) {
      console.error('❌ 필수 파라미터 누락: goodsCode');
      throw new functions.https.HttpsError('invalid-argument', '상품 코드가 필요합니다.');
    }

    console.log('✅ 파라미터 검증 완료:');
    console.log('   userId:', userId);
    console.log('   goodsCode:', goodsCode);
    console.log('   quantity:', quantity);

    // 사용자 정보 가져오기
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', '사용자 정보를 찾을 수 없습니다.');
    }

    const userData = userDoc.data();
    const userCoins = userData.coins || 0;
    const phoneNo = userData.phoneNumber || userData.phone || '';

    console.log('👤 사용자 정보:');
    console.log('   coins:', userCoins);
    console.log('   phoneNo:', phoneNo);

    // 기프티콘 상세 정보 조회 (가격 확인) - /goods/{goodsCode} + api_code 0111
    const detailApiUrl = `https://bizapi.giftishow.com/bizApi/goods/${String(goodsCode)}`;
    const detailFormData = new URLSearchParams();
    detailFormData.append('api_code', '0111');
    detailFormData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
    detailFormData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
    detailFormData.append('dev_yn', 'N');

    console.log('📞 기프티콘 상세 정보 조회 API 호출:', detailApiUrl);
    let detailResponse;
    try {
      detailResponse = await axios.post(detailApiUrl, detailFormData.toString(), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        timeout: 30000,
      });
    } catch (err) {
      console.error('❌ 기프티콘 상세 API 요청 실패:', err.response?.status, err.message);
      throw new functions.https.HttpsError('not-found', '기프티콘 정보를 가져올 수 없습니다.');
    }

    if (!detailResponse.data || detailResponse.data.code !== '0000') {
      console.error('❌ 기프티콘 상세 정보 조회 실패:', detailResponse.data);
      throw new functions.https.HttpsError('not-found', '기프티콘 정보를 가져올 수 없습니다.');
    }

    const giftCardDetail = detailResponse.data.result?.goodsDetail || detailResponse.data.result || detailResponse.data.data || {};
    const giftCardPrice = parseInt(giftCardDetail.goodsPrice || giftCardDetail.goods_price || giftCardDetail.discountPrice || giftCardDetail.salePrice || '0', 10);
    const totalPrice = giftCardPrice * quantity;
    const goodsImg = giftCardDetail.goodsImg || giftCardDetail.goods_img || '';

    console.log('💰 가격 정보:');
    console.log('   giftCardPrice:', giftCardPrice);
    console.log('   quantity:', quantity);
    console.log('   totalPrice:', totalPrice);

    // 코인 확인
    if (userCoins < totalPrice) {
      throw new functions.https.HttpsError('failed-precondition', '코인이 부족합니다.');
    }

    // API 전달용 전화번호: phone_no, callback_no 모두 01057049470으로 고정
    const phoneNoClean = GIFTSHOWBIZ_DEFAULT_PHONE;
    const callbackNoClean = GIFTSHOWBIZ_DEFAULT_PHONE;

    // 쿠폰 발송 API user_id: 기프트쇼비즈에 등록된 회원 ID 사용 (ERR0300 방지)
    const giftshowbizUserId = (GIFTSHOWBIZ_USER_ID && GIFTSHOWBIZ_USER_ID.trim() !== '')
      ? GIFTSHOWBIZ_USER_ID.trim()
      : (userData.giftshowbizUserId || userData.giftshowbiz_user_id || phoneNoClean);
    console.log('🔑 Giftshowbiz User ID (회원 식별):', giftshowbizUserId);

    // TR_ID 생성 (고유한 거래 ID)
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 9);
    const trId = `service_${timestamp}_${randomStr}`.substring(0, 25); // 최대 25자

    console.log('🆔 TR_ID 생성:', trId);

    // Giftshowbiz API 호출 (쿠폰 발송 요청)
    const apiUrl = `${GIFTSHOWBIZ_BASE_URL}/send`;
    const formData = new URLSearchParams();
    formData.append('api_code', '0204'); // 쿠폰 발송 요청
    formData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
    formData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
    formData.append('dev_yn', 'N'); // 운영 환경
    formData.append('goods_code', String(goodsCode));
    formData.append('quantity', String(quantity));
    formData.append('tr_id', trId);
    formData.append('phone_no', phoneNoClean);
    formData.append('callback_no', phoneNoClean); // 발신번호도 동일하게 설정
    formData.append('mms_title', '기프티콘'); // MMS 제목 (10자 이하)
    formData.append('mms_msg', '기프티콘이 발송되었습니다.'); // MMS 메시지
    formData.append('gubun', 'I'); // 바코드 이미지 수신 (I: 이미지, Y: 핀번호, N: MMS)
    
    // user_id 파라미터 추가 (필수)
    // 실제 운영 시에는 Giftshowbiz API 제공업체에 문의하여 테스트용 user_id를 받아야 함
    if (giftshowbizUserId && giftshowbizUserId !== '') {
      formData.append('user_id', String(giftshowbizUserId).trim()); // 회원 ID
    } else {
      // user_id가 없으면 전화번호를 사용
      formData.append('user_id', phoneNoClean);
      console.warn('⚠️ user_id가 없어서 전화번호를 user_id로 사용합니다:', phoneNoClean);
    }

    console.log('📞 Giftshowbiz 쿠폰 발송 요청 API 호출:');
    console.log('   URL:', apiUrl);
    console.log('   api_code: 0204');
    console.log('   dev_yn: N');
    console.log('   goods_code:', goodsCode);
    console.log('   tr_id:', trId);
    console.log('   phone_no:', phoneNoClean);
    console.log('   callback_no:', callbackNoClean);
    console.log('   mms_title: 기프티콘');
    console.log('   mms_msg: 기프티콘이 발송되었습니다.');
    console.log('   gubun: I (바코드 이미지 수신)');
    console.log('   user_id:', giftshowbizUserId);

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
      
      // 바코드 정보가 없으면 쿠폰 상세 정보 조회 API 호출 (0201)
      if (!giftCardInfo || (!giftCardInfo.barcode && !giftCardInfo.barcodeImage && !giftCardInfo.pinNumber)) {
        console.log('⚠️ 응답에 바코드 정보가 없습니다. 쿠폰 상세 정보 조회 API를 호출합니다.');
        
        try {
          const couponDetailUrl = `${GIFTSHOWBIZ_BASE_URL}/coupons`;
          const couponDetailFormData = new URLSearchParams();
          couponDetailFormData.append('api_code', '0201'); // 쿠폰 상세 정보 조회
          couponDetailFormData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
          couponDetailFormData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
          couponDetailFormData.append('dev_yn', 'N');
          couponDetailFormData.append('tr_id', trId);
          
          console.log('📞 쿠폰 상세 정보 조회 API 호출:');
          console.log('   api_code: 0201');
          console.log('   tr_id: trId');
          console.log('   url: couponDetailUrl');
          console.log('   formData: couponDetailFormData.toString()');
          
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
          
          console.log('═══════════════════════════════════════');
          console.log('📥 쿠폰 상세 정보 조회 API 응답:');
          console.log('   status:', couponDetailResponse.status);
          console.log('   code:', couponDetailResponse.data?.code);
          console.log('   message:', couponDetailResponse.data?.message);
          console.log('   전체 응답 키:', couponDetailResponse.data ? Object.keys(couponDetailResponse.data) : []);
          console.log('   전체 응답:', JSON.stringify(couponDetailResponse.data, null, 2));
          console.log('═══════════════════════════════════════');
          
          // 응답 코드가 '0000'이 아니면 오류 로깅
          if (couponDetailResponse.data && couponDetailResponse.data.code !== '0000') {
            console.error('❌ 쿠폰 상세 정보 조회 API 오류:', {
              code: couponDetailResponse.data.code,
              message: couponDetailResponse.data.message,
              전체응답: JSON.stringify(couponDetailResponse.data, null, 2),
            });
          }
          
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
            
            console.log('═══════════════════════════════════════');
            console.log('✅ 쿠폰 상세 정보 조회 성공:');
            console.log('   responseData.result:', !!responseData.result);
            console.log('   responseData.result.result:', !!responseData.result?.result);
            console.log('   responseData.couponDetail:', !!responseData.couponDetail);
            console.log('   responseData.coupon:', !!responseData.coupon);
            console.log('   responseData.data:', !!responseData.data);
            console.log('   detailInfo 타입:', typeof detailInfo);
            console.log('   detailInfo 배열 여부:', Array.isArray(detailInfo));
            if (detailInfo && typeof detailInfo === 'object') {
              console.log('   detailInfo 키:', Object.keys(detailInfo));
            }
            console.log('   detailInfo 전체:', JSON.stringify(detailInfo, null, 2));
            console.log('═══════════════════════════════════════');
            
            // detailInfo가 배열인 경우 첫 번째 요소 사용
            if (Array.isArray(detailInfo) && detailInfo.length > 0) {
              console.log('⚠️ detailInfo가 배열입니다. 첫 번째 요소를 사용합니다.');
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
              
              // 바코드 정보가 있는지 확인
              console.log('🔍 detailInfo에서 바코드 정보 확인:');
              console.log('   모든 키:', Object.keys(giftCardInfo));
              console.log('   barcode 관련 필드:', {
                barcode: giftCardInfo.barcode,
                barcodeNumber: giftCardInfo.barcodeNumber,
                barcode_no: giftCardInfo.barcode_no,
                pinNo: giftCardInfo.pinNo,
                barcodeImage: giftCardInfo.barcodeImage,
                barcodeImageUrl: giftCardInfo.barcodeImageUrl,
                barcode_img: giftCardInfo.barcode_img,
                barcode_image: giftCardInfo.barcode_image,
                couponImgUrl: giftCardInfo.couponImgUrl,
              });
              console.log('   pin 관련 필드:', {
                pinNumber: giftCardInfo.pinNumber,
                pin: giftCardInfo.pin,
                pin_no: giftCardInfo.pin_no,
                pinNo: giftCardInfo.pinNo,
              });
            } else {
              console.warn('⚠️ detailInfo가 유효한 객체가 아닙니다.');
              giftCardInfo = null;
            }
          } else {
            console.warn('⚠️ 쿠폰 상세 정보 조회 실패:', couponDetailResponse.data);
          }
        } catch (couponError) {
          console.error('❌ 쿠폰 상세 정보 조회 오류:', couponError.message);
          // 쿠폰 상세 정보 조회 실패해도 구매는 성공한 것으로 처리
        }
      }
      
      // 바코드 정보 정리 (다양한 필드명 지원)
      // "발행" 같은 상태 메시지는 실제 바코드/PIN 번호가 아니므로 제외
      function isValidBarcodeOrPin(value) {
        if (!value || typeof value !== 'string') return false;
        const trimmed = value.trim();
        // 빈 문자열이거나 "발행" 같은 상태 메시지 제외
        if (trimmed === '' || trimmed === '발행' || trimmed === '발행됨' || trimmed === 'issued') return false;
        // 숫자와 영문으로만 구성된 값만 유효한 바코드/PIN으로 인식
        return /^[0-9A-Za-z]+$/.test(trimmed) && trimmed.length >= 3;
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
            break;
          }
        }
        
        // 바코드 이미지 URL 추출
        // API 규격서: couponImgUrl 필드명 사용
        const barcodeImage = giftCardInfo.barcodeImage || 
                            giftCardInfo.barcodeImageUrl || 
                            giftCardInfo.barcode_img || 
                            giftCardInfo.barcode_image ||
                            giftCardInfo.couponImgUrl || // API 규격서 필드명
                            '';
        
        const barcodeInfo = {
          barcode: barcode,
          barcodeImage: barcodeImage,
          pinNumber: pinNumber,
          expiryDate: giftCardInfo.expiryDate || giftCardInfo.expireDate || giftCardInfo.expiry_date || giftCardInfo.expire_date || '',
          trId: trId,
          orderNo: giftCardInfo.orderNo || '', // API 규격서: orderNo도 저장
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
        });
        
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
                  // 유효한 바코드 번호만 저장 ("발행" 같은 상태 메시지 제외)
                  if (isValidBarcodeOrPin(value)) {
                    barcodeInfo.barcode = String(value).trim();
                    console.log(`   ✅ 유효한 바코드 번호 발견: ${barcodeInfo.barcode}`);
                  } else {
                    console.log(`   ⚠️ 유효하지 않은 바코드 값 (무시): ${value}`);
                  }
                }
              }
              
              // PIN 관련 필드 확인
              if (lowerKey.includes('pin')) {
                console.log(`   발견: ${currentPath} = ${value}`);
                // 유효한 PIN 번호만 저장 ("발행" 같은 상태 메시지 제외)
                if (isValidBarcodeOrPin(value)) {
                  barcodeInfo.pinNumber = String(value).trim();
                  console.log(`   ✅ 유효한 PIN 번호 발견: ${barcodeInfo.pinNumber}`);
                } else {
                  console.log(`   ⚠️ 유효하지 않은 PIN 값 (무시): ${value}`);
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
          
          giftCardInfo = barcodeInfo;
        } else {
          giftCardInfo = barcodeInfo;
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

      // 코인 차감
      await userRef.update({
        coins: admin.firestore.FieldValue.increment(-totalPrice),
      });

      console.log(`💰 코인 차감 완료: ${totalPrice} 코인 차감`);

      // 구매 기록 저장
      const purchaseRef = db.collection('purchases').doc();
      await purchaseRef.set({
        userId: userId,
        goodsCode: goodsCode,
        goodsName: giftCardDetail.goodsName || giftCardDetail.goods_name || '',
        goodsPrice: giftCardPrice,
        quantity: quantity,
        totalPrice: totalPrice,
        trId: trId,
        purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
      });

      // 보유 기프티콘 저장
      const ownedGiftCardRef = db.collection('ownedGiftCards').doc();
      await ownedGiftCardRef.set({
        userId: userId,
        goodsCode: goodsCode,
        goodsName: giftCardDetail.goodsName || giftCardDetail.goods_name || '',
        goodsImg: goodsImg,
        goodsPrice: giftCardPrice,
        quantity: quantity,
        trId: trId,
        purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
        status: 'active',
        giftCardInfo: giftCardInfo, // 바코드 정보 포함
      });

      console.log('✅ 구매 완료 및 데이터 저장 완료');

      return {
        success: true,
        message: '기프티콘 구매가 완료되었습니다.',
        giftCard: {
          id: ownedGiftCardRef.id,
          goodsCode: goodsCode,
          goodsName: giftCardDetail.goodsName || giftCardDetail.goods_name || '',
          goodsImg: goodsImg,
          trId: trId,
          giftCardInfo: giftCardInfo,
        },
      };
    } else {
      // API 오류 응답
      console.error('❌ 쿠폰 발송 요청 API 오류:', response.data);
      const errorCode = response.data?.code || 'UNKNOWN';
      const errorMessage = response.data?.message || '쿠폰 발송 요청에 실패했습니다.';
      throw new functions.https.HttpsError('internal', `쿠폰 발송 요청 API 오류 (${errorCode}): ${errorMessage}`);
    }
  } catch (error) {
    console.error('❌ 기프티콘 구매 오류:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', `기프티콘 구매 중 오류가 발생했습니다: ${error.message}`);
  }
});

// 기프티콘 바코드 정보 재조회
exports.refreshGiftCardBarcode = functions.https.onCall(async (data, context) => {
  try {
    console.log('📥 refreshGiftCardBarcode 함수 호출됨');

    // 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
    }

    const userId = context.auth.uid;
    const { trId } = data;

    if (!trId) {
      throw new functions.https.HttpsError('invalid-argument', '거래 ID가 필요합니다.');
    }

    // 보유 기프티콘 찾기
    const ownedGiftCardsSnapshot = await db.collection('ownedGiftCards')
      .where('userId', '==', userId)
      .where('trId', '==', trId)
      .limit(1)
      .get();

    if (ownedGiftCardsSnapshot.empty) {
      throw new functions.https.HttpsError('not-found', '보유 기프티콘을 찾을 수 없습니다.');
    }

    const ownedGiftCardDoc = ownedGiftCardsSnapshot.docs[0];
    const ownedGiftCardData = ownedGiftCardDoc.data();

    // 쿠폰 상세 정보 조회 API 호출
    const couponDetailUrl = `${GIFTSHOWBIZ_BASE_URL}/coupons`;
    const couponDetailFormData = new URLSearchParams();
    couponDetailFormData.append('api_code', '0201'); // 쿠폰 상세 정보 조회
    couponDetailFormData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
    couponDetailFormData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
    couponDetailFormData.append('dev_yn', 'N');
    couponDetailFormData.append('tr_id', trId);

    console.log('📞 쿠폰 상세 정보 조회 API 호출:');
    console.log('   api_code: 0201');
    console.log('   tr_id:', trId);

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

    console.log('📥 쿠폰 상세 정보 조회 API 응답:', JSON.stringify(couponDetailResponse.data, null, 2));

    if (couponDetailResponse.data && couponDetailResponse.data.code === '0000') {
      // 쿠폰 상세 정보는 result.result 구조일 수 있음 (API 규격서 참고)
      const responseData = couponDetailResponse.data;
      
      // API 0201 응답에서 쿠폰 행 추출 (result / result.result / result[0] 등 다양한 구조)
      const pickFirstNonEmpty = (obj, ...keys) => {
        if (obj == null) return null;
        for (const k of keys) {
          const v = obj[k];
          if (v != null && String(v).trim() !== '') return String(v).trim();
        }
        return null;
      };

      // pinStatusCd는 result[0].couponInfoList[0] 안에 있음 (API 0201 실제 응답 구조)
      let apiRow = null;
      const r = responseData.result;
      if (Array.isArray(r) && r.length > 0) {
        const first = r[0];
        const list = first.couponInfoList ?? first.coupon_info_list ?? first.list ?? first.data;
        if (Array.isArray(list) && list.length > 0) {
          apiRow = list[0];
          console.log('✅ 응답 구조: result[0].couponInfoList[0] 사용');
        } else {
          apiRow = first;
          console.log('✅ 응답 구조: result[0] 사용');
        }
      } else if (r && Array.isArray(r.result) && r.result.length > 0) {
        const first = r.result[0];
        const list = first.couponInfoList ?? first.coupon_info_list;
        apiRow = (Array.isArray(list) && list.length > 0) ? list[0] : first;
        console.log('✅ 응답 구조: result.result[0] 또는 couponInfoList[0] 사용');
      } else if (r && typeof r.result === 'object' && r.result !== null && !Array.isArray(r.result)) {
        apiRow = r.result;
        console.log('✅ 응답 구조: result.result 객체 사용');
      } else if (r && typeof r === 'object') {
        apiRow = r;
        console.log('✅ 응답 구조: result 객체 사용');
      }

      const statusKeys = ['pinStatusCd', 'pin_status_cd', 'statusCd', 'status_cd', 'pinStatus', 'statusCode', 'pin_status'];
      const statusNmKeys = ['pinStatusNm', 'pin_status_nm', 'statusNm', 'status_nm', 'pinStatusName', 'statusName'];
      const pinStatusCdFromApi = pickFirstNonEmpty(apiRow, ...statusKeys)
        ?? pickFirstNonEmpty(r, ...statusKeys)
        ?? pickFirstNonEmpty(responseData, ...statusKeys);
      const pinStatusNmFromApi = pickFirstNonEmpty(apiRow, ...statusNmKeys)
        ?? pickFirstNonEmpty(r, ...statusNmKeys)
        ?? pickFirstNonEmpty(responseData, ...statusNmKeys);

      if (!pinStatusCdFromApi) {
        console.log('⚠️ API 0201 pinStatusCd 미발견. apiRow 키:', apiRow ? Object.keys(apiRow) : 'null');
      }

      // 기존 giftCardInfo 유지하고 pinStatusCd / pinStatusNm 만 반영
      const existing = ownedGiftCardData.giftCardInfo && typeof ownedGiftCardData.giftCardInfo === 'object'
        ? { ...ownedGiftCardData.giftCardInfo }
        : { trId };

      if (pinStatusCdFromApi != null) existing.pinStatusCd = pinStatusCdFromApi;
      if (pinStatusNmFromApi != null) existing.pinStatusNm = pinStatusNmFromApi;
      if (!existing.trId) existing.trId = trId;

      await ownedGiftCardDoc.ref.update({
        giftCardInfo: existing,
      });

      console.log('✅ pinStatusCd만 반영 완료:', existing.pinStatusCd);

      return {
        success: true,
        message: '쿠폰 상태가 업데이트되었습니다.',
        giftCardInfo: existing,
      };
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

// 애드팝콘 리워드 콜백 (운영/스테이징)
// IGAWorks 리워드 서버 스펙에 맞춘 응답 포맷:
// - 성공:   {"Result":true,"ResultCode":1,"ResultMsg":"success"}
// - 서명 실패: {"Result":false,"ResultCode":1100,"ResultMsg":"invalid signed value"}
// - 중복 지급: {"Result":false,"ResultCode":3100,"ResultMsg":"duplicate transaction"}
// - 유저 없음: {"Result":false,"ResultCode":3200,"ResultMsg":"invalid user"}
function handleAdpopcornRewardCallback(req, res, isStaging) {
  const params = req.method === 'GET' ? req.query : req.body || {};

  const usn = String(params.usn || '').trim();
  const rewardKey = String(params.reward_key || '').trim();
  const quantityRaw = params.quantity;
  const campaignKey = String(params.campaign_key || '').trim();
  const signedValue = String(params.signed_value || '').trim();

  const quantity = Math.max(0, parseInt(String(quantityRaw ?? ''), 10) || 0);

  const hashKey = isStaging ? ADPOPCORN_HASH_KEY_STAGING : ADPOPCORN_HASH_KEY;

  const json = (obj) => res.status(200).json(obj);

  // 필수값 체크
  if (!usn || !rewardKey || !campaignKey || !signedValue || quantity <= 0) {
    return json({
      Result: false,
      ResultCode: 4000,
      ResultMsg: 'required parameter missing',
    });
  }

  // signed_value 검증 (HMAC-MD5)
  try {
    const plain = `${usn}${rewardKey}${quantity}${campaignKey}`;
    const expected = crypto
      .createHmac('md5', hashKey)
      .update(plain)
      .digest('hex');

    if (expected.toLowerCase() !== signedValue.toLowerCase()) {
      console.error('AdPopcorn signed value mismatch', {
        usn,
        rewardKey,
        quantity,
        campaignKey,
      });
      return json({
        Result: false,
        ResultCode: 1100,
        ResultMsg: 'invalid signed value',
      });
    }
  } catch (e) {
    console.error('AdPopcorn signed value check error:', e);
    return json({
      Result: false,
      ResultCode: 4000,
      ResultMsg: 'signed value check error',
    });
  }

  (async () => {
    try {
      // reward_key 중복 지급 방지
      const txRef = db.collection('adpopcornRewards').doc(rewardKey);
      const txSnap = await txRef.get();
      if (txSnap.exists) {
        console.warn('AdPopcorn duplicate reward_key:', rewardKey);
        return json({
          Result: false,
          ResultCode: 3100,
          ResultMsg: 'duplicate transaction',
        });
      }

      // 유저 확인
      const userRef = db.collection('users').doc(usn);
      const userSnap = await userRef.get();
      if (!userSnap.exists) {
        console.error('AdPopcorn invalid user:', usn);
        return json({
          Result: false,
          ResultCode: 3200,
          ResultMsg: 'invalid user',
        });
      }

      // 코인 지급
      await userRef.update({
        coins: admin.firestore.FieldValue.increment(quantity),
      });
      await db.collection('coinHistory').add({
        userId: usn,
        amount: quantity,
        type: 'offerwall',
        rewardKey,
        campaignKey,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 트랜잭션 기록
      await txRef.set({
        usn,
        rewardKey,
        quantity,
        campaignKey,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return json({
        Result: true,
        ResultCode: 1,
        ResultMsg: 'success',
      });
    } catch (e) {
      console.error('adpopcornRewardCallback error:', e);
      return json({
        Result: false,
        ResultCode: 4000,
        ResultMsg: e.message || 'server error',
      });
    }
  })();
}
exports.adpopcornRewardCallback = functions.https.onRequest((req, res) => { handleAdpopcornRewardCallback(req, res, false); });
exports.adpopcornRewardCallbackStaging = functions.https.onRequest((req, res) => { handleAdpopcornRewardCallback(req, res, true); });

// 브랜드 목록
exports.getBrandList = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '인증이 필요합니다.');
    const formData = new URLSearchParams();
    formData.append('api_code', '0202');
    formData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
    formData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
    formData.append('dev_yn', 'N');
    const response = await axios.post(`${GIFTSHOWBIZ_BASE_URL}/list`, formData.toString(), { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, timeout: 30000 });
    if (!response.data || response.data.code !== '0000') throw new functions.https.HttpsError('internal', response.data?.message || '브랜드 목록 조회에 실패했습니다.');
    const items = response.data.result || response.data.data || [];
    const brandSet = new Set();
    items.forEach((card) => { const name = (card.brandName || card.brand_name || '').toString().trim(); if (name) brandSet.add(name); });
    const list = Array.from(brandSet).sort();
    return { success: true, listNum: list.length, list };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    console.error('getBrandList error:', e);
    throw new functions.https.HttpsError('internal', `브랜드 목록 조회 중 오류: ${e.message}`);
  }
});

// 기프트카드 캐시 무효화 (매일 03:15 KST)
exports.invalidateGiftCardCacheDaily = functions.pubsub.schedule('15 3 * * *').timeZone('Asia/Seoul').onRun(async () => {
  await db.collection('syncStatus').doc('giftcardCacheInvalidation').set(
    { invalidatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  console.log('invalidateGiftCardCacheDaily: 완료');
});

// 기프트카드 일일 동기화 (매일 03:00 KST)
// - API 0101(/goods)로 전체 상품을 받아 Firestore `giftcards` 컬렉션을 동기화
// - API에 있는 상품은 추가/갱신, API에 없는 기존 문서는 삭제
exports.syncGiftCardsDaily = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('Asia/Seoul')
  .onRun(async () => {
    try {
      // 동기화 상태 표시
      await db.collection('syncStatus').doc('giftcards').set(
        {
          status: 'syncing',
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          message: '상품 업데이트중...',
        },
        { merge: true }
      );

      // 1. API 호출 (0101 + /goods) – 페이지당 size=500으로 모든 페이지 조회
      const apiGoodsCodes = new Set();

      const BATCH_SIZE = 500;
      let written = 0;

      const pageSize = 500;
      let page = 1;

      while (true) {
        const formData = new URLSearchParams();
        formData.append('api_code', '0101');
        formData.append('custom_auth_code', GIFTSHOWBIZ_AUTH_CODE);
        formData.append('custom_auth_token', GIFTSHOWBIZ_AUTH_TOKEN);
        formData.append('dev_yn', 'N');
        formData.append('start', String(page)); // 시작 페이지
        formData.append('size', String(pageSize)); // 페이지당 개수 (500)

        console.log(`📞 syncGiftCardsDaily: 상품 리스트 API 호출 (/goods, api_code=0101, page=${page}, size=${pageSize})`);

        const response = await axios.post(
          `${GIFTSHOWBIZ_BASE_URL}/goods`,
          formData.toString(),
          {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            timeout: 60000,
          }
        );

        if (!response.data || response.data.code !== '0000') {
          console.error('❌ 기프트카드 목록 API 실패:', response.data);
          throw new Error(response.data?.message || response.data?.code || '기프트카드 목록 API 실패');
        }

        const itemsPage =
          response.data.result?.goodsList ||
          response.data.result ||
          response.data.data ||
          [];

        if (!Array.isArray(itemsPage) || itemsPage.length === 0) {
          console.log(`📭 페이지 ${page}에서 더 이상 상품이 없습니다. 동기화 종료.`);
          break;
        }

        console.log(`📦 페이지 ${page} 상품 수: ${itemsPage.length}`);

        // 2. 이 페이지의 상품들을 Firestore에 upsert
        for (let i = 0; i < itemsPage.length; i += BATCH_SIZE) {
          const batch = db.batch();
          const chunk = itemsPage.slice(i, i + BATCH_SIZE);

          chunk.forEach((card) => {
            const goodsCode = (card.goodsCode || card.goods_code || '').toString();
            if (!goodsCode) return;

            apiGoodsCodes.add(goodsCode);

            const docRef = db.collection('giftcards').doc(goodsCode);

            // 이미지/카테고리 등은 루트 functions 버전과 최대한 비슷하게 저장
            const imageUrl =
              card.goodsimg ||
              card.mmsGoodsimg ||
              card.goodsImgS ||
              card.goodsImgB ||
              card.goodsImg ||
              card.image ||
              card.img ||
              '';

            const categoryName =
              card.categoryName1 ||
              card.category1Name ||
              card.categoryName ||
              card.goodsTypeNm ||
              '';

            batch.set(
              docRef,
              {
                goodsCode,
                goodsName: String(card.goodsName || card.goods_name || ''),
                salePrice: Number(card.salePrice) || 0,
                discountPrice: Number(card.discountPrice) || 0,
                goodsimg: String(imageUrl),
                mmsGoodsimg: String(card.mmsGoodsimg || ''),
                goodsImgS: String(card.goodsImgS || ''),
                goodsImgB: String(card.goodsImgB || ''),
                goodsImg: String(card.goodsImg || ''),
                image: String(card.image || ''),
                img: String(card.img || ''),
                brandName: String(card.brandName || card.brand_name || ''),
                goodsTypeNm: String(card.goodsTypeNm || ''),
                categoryName1: String(categoryName),
                category1Name: String(card.category1Name || ''),
                categoryName: String(card.categoryName || ''),
                srchKeyword: String(card.srchKeyword || ''),
                lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          });

          await batch.commit();
          written += chunk.length;
          console.log(`✅ syncGiftCardsDaily: upsert 배치 완료 (page=${page}), 누적: ${written}`);
        }

        // 마지막 페이지면 종료
        if (itemsPage.length < pageSize) {
          console.log(`📭 페이지 ${page}의 상품 수가 ${pageSize} 미만이므로 마지막 페이지로 간주하고 종료합니다.`);
          break;
        }

        page += 1;
      }

      console.log('📊 syncGiftCardsDaily: API 상품 코드 수:', apiGoodsCodes.size);

      // 3. API에는 없고 Firestore에만 있는 문서 삭제
      console.log('🧹 syncGiftCardsDaily: API에 없는 상품 삭제 시작');
      const allDocsSnap = await db.collection('giftcards').get();
      const deleteBatch = db.batch();
      let deleteCount = 0;
      let deleteBatchCount = 0;

      allDocsSnap.docs.forEach((doc) => {
        const goodsCode = doc.id;
        if (!apiGoodsCodes.has(goodsCode)) {
          deleteBatch.delete(doc.ref);
          deleteCount++;
          deleteBatchCount++;
        }
      });

      if (deleteBatchCount > 0) {
        await deleteBatch.commit();
      }

      console.log('✅ syncGiftCardsDaily: 삭제된 상품 수:', deleteCount);

      // 4. 상태 idle로 업데이트
      await db.collection('syncStatus').doc('giftcards').set(
        {
          status: 'idle',
          lastSync: admin.firestore.FieldValue.serverTimestamp(),
          totalSynced: written,
          deleted: deleteCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      console.log('syncGiftCardsDaily: 완료', written, '건, 삭제', deleteCount, '건');
    } catch (e) {
      console.error('syncGiftCardsDaily error:', e);
      await db
        .collection('syncStatus')
        .doc('giftcards')
        .set(
          {
            status: 'error',
            error: String(e.message || e),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        )
        .catch(() => {});
      throw e;
    }
  });
