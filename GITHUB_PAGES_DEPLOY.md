# GitHub Pages 배포 가이드

## 1. 저장소 원격 설정

저장소 ID가 `cy moon38 / progstudioservice`인 경우, 다음 명령어로 원격 저장소를 설정하세요:

```bash
git remote add origin https://github.com/cy moon38/progstudioservice.git
```

**참고**: GitHub 사용자명에 공백이 있다면 URL 인코딩이 필요할 수 있습니다. 
실제 저장소 URL을 확인하려면 GitHub에서 저장소 페이지로 이동한 후 "Code" 버튼을 클릭하여 URL을 복사하세요.

## 2. 파일 푸시

```bash
# 현재 브랜치를 main으로 변경 (이미 완료됨)
git branch -M main

# 원격 저장소에 푸시
git push -u origin main
```

## 3. GitHub Pages 활성화

1. GitHub 저장소 페이지로 이동
2. **Settings** 탭 클릭
3. 왼쪽 메뉴에서 **Pages** 클릭
4. **Source** 섹션에서:
   - Branch: `main` 선택
   - Folder: `/ (root)` 선택
5. **Save** 버튼 클릭

## 4. 웹사이트 접속

배포가 완료되면 (보통 1-2분 소요) 다음 URL로 접속할 수 있습니다:

```
https://cy moon38.github.io/progstudioservice/
```

**참고**: 실제 사용자명에 따라 URL이 달라질 수 있습니다.

## 5. 배포된 파일 확인

다음 파일들이 배포되어야 합니다:
- ✅ `index.html` - 메인 페이지
- ✅ `privacy_policy.html` - 개인정보처리방침
- ✅ `terms_of_service.html` - 이용약관
- ✅ `메인화면.jpg` - 메인 화면 이미지
- ✅ `작품업로드화면.jpg` - 작품 업로드 화면 이미지
- ✅ `미션화면.jpg` - 미션 화면 이미지
- ✅ `기프티콘화면.jpg` - 기프티콘 화면 이미지

## 문제 해결

### 원격 저장소가 이미 있는 경우
```bash
git remote set-url origin https://github.com/cy moon38/progstudioservice.git
```

### 푸시 권한 오류가 발생하는 경우
- GitHub 인증 정보를 확인하세요
- Personal Access Token을 사용해야 할 수 있습니다

### 이미지가 표시되지 않는 경우
- 파일 경로가 정확한지 확인하세요
- GitHub Pages 설정에서 브랜치와 폴더가 올바르게 설정되었는지 확인하세요

