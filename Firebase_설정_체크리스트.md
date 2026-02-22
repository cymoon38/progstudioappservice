# Firebase 설정 체크리스트

## ✅ 필수 설정 사항

### 1. Firestore 보안 규칙 확인

**위치**: Firebase Console > Firestore Database > 규칙 탭

현재 `firestore_rules.txt` 파일의 규칙이 적용되어 있는지 확인하세요.

**확인 사항**:
- [ ] `userMissions` 컬렉션 규칙이 설정되어 있는지
- [ ] `missions` 컬렉션 규칙이 설정되어 있는지
- [ ] `posts` 컬렉션에서 `isPopular`, `popularDate` 필드 업데이트가 가능한지

**현재 규칙 상태**:
- ✅ `userMissions`: 읽기/쓰기 규칙 설정됨
- ✅ `missions`: 읽기 규칙 설정됨 (생성/수정/삭제는 false - 관리자만 가능)
- ✅ `posts`: `isPopular`, `popularDate` 필드 업데이트 가능

---

### 2. Firestore 인덱스 생성 (중요!)

**위치**: Firebase Console > Firestore Database > 인덱스 탭

다음 인덱스들이 생성되어 있는지 확인하세요. 없으면 생성해야 합니다.

#### 2-1. userMissions 복합 인덱스 (필수)

**컬렉션 ID**: `userMissions`

**필드 추가**:
- `userId` (오름차순, Ascending)
- `missionId` (오름차순, Ascending)

**쿼리 범위**: 컬렉션 (Collection)

**인덱스 생성 이유**:
```dart
_firestore.collection('userMissions')
  .where('userId', isEqualTo: userId)
  .where('missionId', isEqualTo: mission.id)
  .limit(1)
```

**생성 방법**:
1. Firebase Console > Firestore Database > 인덱스 탭
2. "인덱스 만들기" 버튼 클릭
3. 컬렉션 ID: `userMissions` 입력
4. 필드 추가:
   - 필드: `userId`, 정렬: 오름차순
   - 필드: `missionId`, 정렬: 오름차순
5. 쿼리 범위: 컬렉션 선택
6. "만들기" 버튼 클릭

---

#### 2-2. posts 복합 인덱스 (필수)

**컬렉션 ID**: `posts`

**필드 추가**:
- `author` (오름차순, Ascending)
- `date` (내림차순, Descending)

**쿼리 범위**: 컬렉션 (Collection)

**인덱스 생성 이유**:
```dart
_firestore.collection('posts')
  .where('author', isEqualTo: username)
  .orderBy('date', descending: true)
```

**생성 방법**:
1. Firebase Console > Firestore Database > 인덱스 탭
2. "인덱스 만들기" 버튼 클릭
3. 컬렉션 ID: `posts` 입력
4. 필드 추가:
   - 필드: `author`, 정렬: 오름차순
   - 필드: `date`, 정렬: 내림차순
5. 쿼리 범위: 컬렉션 선택
6. "만들기" 버튼 클릭

---

#### 2-3. coinHistory 복합 인덱스 (필수)

**컬렉션 ID**: `coinHistory`

**필드 추가**:
- `userId` (오름차순, Ascending)
- `timestamp` (내림차순, Descending)

**쿼리 범위**: 컬렉션 (Collection)

**인덱스 생성 이유**:
```dart
_firestore.collection('coinHistory')
  .where('userId', isEqualTo: userId)
  .orderBy('timestamp', descending: true)
  .limit(20)
```

**생성 방법**:
1. Firebase Console > Firestore Database > 인덱스 탭
2. "인덱스 만들기" 버튼 클릭
3. 컬렉션 ID: `coinHistory` 입력
4. 필드 추가:
   - 필드: `userId`, 정렬: 오름차순
   - 필드: `timestamp`, 정렬: 내림차순
5. 쿼리 범위: 컬렉션 선택
6. "만들기" 버튼 클릭

---

### 3. Firebase Storage 보안 규칙 확인

**위치**: Firebase Console > Storage > 규칙 탭

**필수 규칙**:
```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // 게시물 이미지 - 모든 사용자가 읽기 가능, 인증된 사용자만 업로드/삭제 가능
    match /posts/{userId}/{allPaths=**} {
      // 읽기는 모든 사용자 허용
      allow read: if true;
      // 쓰기는 인증된 사용자이고 자신의 폴더에만 허용
      allow write: if request.auth != null && request.auth.uid == userId;
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // 기타 모든 파일
    match /{allPaths=**} {
      // 읽기는 모든 사용자 허용
      allow read: if true;
      // 쓰기는 인증된 사용자만 허용
      allow write: if request.auth != null;
      allow delete: if request.auth != null;
    }
  }
}
```

**확인 사항**:
- [ ] Storage 규칙이 위와 같이 설정되어 있는지
- [ ] `posts/{userId}/` 경로에 대한 읽기/쓰기 권한이 올바른지

---

### 4. 미션 데이터 확인

**위치**: Firebase Console > Firestore Database > `missions` 컬렉션

**인기작품 7회 선정 미션 확인**:

다음 필드들이 올바르게 설정되어 있는지 확인하세요:

```javascript
{
  "type": "popular_selected",
  "title": "인기 작품 7회 선정되기",
  "description": "일주일 동안 인기 작품 7회 선정에 도전하세요",
  "targetCount": 7,
  "reward": 350,  // ⚠️ 중요: 350으로 설정되어 있어야 함
  "isRepeatable": true
}
```

**확인 사항**:
- [ ] `type` 필드가 `"popular_selected"`인지
- [ ] `targetCount` 필드가 `7`인지
- [ ] `reward` 필드가 `350`인지 (0이면 안 됨)
- [ ] `isRepeatable` 필드가 `true`인지

**주의**: `reward`가 0이면 앱에서 자동으로 350으로 수정하려고 시도하지만, Firebase에서 직접 수정하는 것이 더 안전합니다.

---

### 5. 사용자 데이터 구조 확인

**위치**: Firebase Console > Firestore Database > `users` 컬렉션

**확인 사항**:
- [ ] 각 사용자 문서에 `coins` 필드가 있는지 (없으면 0으로 초기화)
- [ ] 각 사용자 문서에 `name` 필드가 있는지
- [ ] 각 사용자 문서에 `role` 필드가 있는지 (관리자용, 선택사항)

---

### 6. 게시물 데이터 구조 확인

**위치**: Firebase Console > Firestore Database > `posts` 컬렉션

**확인 사항**:
- [ ] `isPopular` 필드가 있는지 (boolean)
- [ ] `popularDate` 필드가 있는지 (timestamp)
- [ ] `authorUid` 필드가 있는지 (string, 선택사항이지만 권장)

---

## 🔍 인덱스 생성 확인 방법

인덱스가 제대로 생성되었는지 확인하려면:

1. Firebase Console > Firestore Database > 인덱스 탭
2. 생성된 인덱스 목록에서 위의 3개 인덱스가 있는지 확인
3. 각 인덱스의 상태가 "사용 가능" (Enabled)인지 확인

**인덱스 생성 시간**: 보통 1-2분 정도 소요됩니다.

---

## ⚠️ 주의사항

1. **인덱스 생성 전**: 인덱스가 없으면 쿼리 오류가 발생할 수 있습니다. 앱 실행 시 콘솔에 에러 메시지와 함께 인덱스 생성 링크가 표시될 수 있습니다.

2. **보안 규칙**: 프로덕션 환경에서는 더 엄격한 규칙을 권장합니다.

3. **미션 reward**: `popular_selected` 미션의 `reward`가 0이면 앱에서 자동으로 350으로 수정하려고 시도하지만, Firebase Console에서 직접 확인하고 수정하는 것이 좋습니다.

---

## 📝 체크리스트 요약

### 필수 설정 (반드시 확인):
- [ ] Firestore 보안 규칙 적용 확인
- [ ] `userMissions` 복합 인덱스 생성 (userId + missionId)
- [ ] `posts` 복합 인덱스 생성 (author + date)
- [ ] `coinHistory` 복합 인덱스 생성 (userId + timestamp)
- [ ] Firebase Storage 보안 규칙 설정
- [ ] `popular_selected` 미션의 `reward`가 350인지 확인

### 권장 설정 (선택사항):
- [ ] 사용자 문서에 `coins` 필드 초기화
- [ ] 게시물 문서에 `authorUid` 필드 추가

---

## 🚀 설정 완료 후 테스트

모든 설정이 완료되면 다음을 테스트하세요:

1. **미션 시스템**:
   - 미션 목록이 제대로 표시되는지
   - 미션 참가하기 버튼이 작동하는지
   - 인기작품 선정 시 진행도가 증가하는지

2. **인덱스**:
   - 앱 실행 시 인덱스 관련 오류가 없는지
   - 쿼리가 정상적으로 작동하는지

3. **Storage**:
   - 이미지 업로드가 정상적으로 작동하는지
   - 이미지 다운로드가 정상적으로 작동하는지


































