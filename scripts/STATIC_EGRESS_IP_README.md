# 고정 Egress IP 설정 (리포트 서비스 White IP용)

Firebase Cloud Functions에서 **나가는(egress) IP를 고정**해, 리포트 서비스 White IP에 등록할 수 있게 합니다.

## 순서

### 1. GCP에서 리소스 생성 (한 번만)

**Windows:** Git Bash 또는 WSL에서 실행.

```bash
cd scripts
chmod +x setup-static-egress-ip.sh
./setup-static-egress-ip.sh
```

또는 PowerShell에서 gcloud를 직접 실행하려면 [스크립트 내용](setup-static-egress-ip.sh)을 참고해 단계별로 실행하세요.

- 사전 요구: `gcloud` 설치, `gcloud auth login`, `gcloud config set project community-b19fb`
- 생성되는 리소스: 서브넷, Cloud Router, 고정 IP, Cloud NAT, Serverless VPC Access 커넥터
- 스크립트 끝에 **White IP에 등록할 고정 IP**가 출력됩니다.

### 2. Functions 배포

```bash
cd C:\Users\ASUS\Desktop\flutter_project
firebase deploy --only functions
```

- **주의:** `getReportEgressIP` 함수는 VPC 커넥터(`report-egress-connector`)가 있어야 정상 동작합니다. **1번 스크립트를 먼저 실행**한 뒤 배포하세요.

### 3. 고정 IP 확인

브라우저 또는 curl로 접속:

```
https://us-central1-community-b19fb.cloudfunctions.net/getReportEgressIP
```

응답의 `ip` 값이 1번에서 출력한 고정 IP와 같으면 정상입니다. **이 IP를 리포트 서비스 White IP에 등록**하세요.

### 4. 실제 리포트 API를 호출하는 함수에서 사용

리포트 API를 호출하는 함수에도 같은 VPC 설정을 넣으면, 그 함수의 나가는 트래픽이 고정 IP로 나갑니다.

```js
const REPORT_EGRESS_CONNECTOR = 'projects/community-b19fb/locations/us-central1/connectors/report-egress-connector';

exports.리포트호출함수 = functions
  .runWith({
    vpcConnector: REPORT_EGRESS_CONNECTOR,
    vpcConnectorEgressSettings: 'ALL_TRAFFIC',
    timeoutSeconds: 60,
  })
  .https.onRequest(async (req, res) => {
    // 리포트 API 호출 (axios 등)
  });
```

## 문제 해결

- **getReportEgressIP 호출 시 500 / 타임아웃:** VPC 커넥터가 아직 없거나, NAT/서브넷 설정이 잘못됐을 수 있습니다. 1번 스크립트를 다시 확인하고, GCP 콘솔에서 커넥터·NAT 상태를 확인하세요.
- **기존 서비스 영향:** VPC 커넥터는 `getReportEgressIP`(및 위처럼 설정한 함수)에만 적용됩니다. 다른 함수는 기존처럼 동작합니다.
