# Firebase Cloud Functions 고정 Egress IP 설정
# 실행 전: Google Cloud SDK 설치 후 gcloud auth login, 이 스크립트를 PowerShell에서 실행

$ErrorActionPreference = "Stop"
$PROJECT_ID = "community-b19fb"
$REGION = "us-central1"
$NETWORK = "default"
$SUBNET_NAME = "report-egress-subnet"
$SUBNET_RANGE = "10.8.0.0/28"
$ROUTER_NAME = "report-egress-router"
$NAT_NAME = "report-egress-nat"
$STATIC_IP_NAME = "report-egress-ip"
$CONNECTOR_NAME = "report-egress-connector"

Write-Host "Project: $PROJECT_ID, Region: $REGION"
gcloud config set project $PROJECT_ID

# 1. 서브넷 생성
Write-Host ">>> 1. 서브넷 생성: $SUBNET_NAME"
try {
  gcloud compute networks subnets create $SUBNET_NAME `
    --network=$NETWORK --region=$REGION --range=$SUBNET_RANGE
} catch { Write-Host "  (이미 존재할 수 있음)" }

# 2. Private Google Access 활성화
Write-Host ">>> 2. Private Google Access 활성화"
gcloud compute networks subnets update $SUBNET_NAME `
  --region=$REGION --enable-private-ip-google-access

# 3. 고정 IP 예약
Write-Host ">>> 3. 고정 IP 예약: $STATIC_IP_NAME"
try {
  gcloud compute addresses create $STATIC_IP_NAME --region=$REGION
} catch { Write-Host "  (이미 존재할 수 있음)" }

# 4. Cloud Router 생성
Write-Host ">>> 4. Cloud Router 생성: $ROUTER_NAME"
try {
  gcloud compute routers create $ROUTER_NAME `
    --network=$NETWORK --region=$REGION
} catch { Write-Host "  (이미 존재할 수 있음)" }

# 5. Cloud NAT 생성
Write-Host ">>> 5. Cloud NAT 생성: $NAT_NAME"
try {
  gcloud compute routers nats create $NAT_NAME `
    --router=$ROUTER_NAME --region=$REGION `
    --nat-custom-subnet-ip-ranges=$SUBNET_NAME `
    --nat-external-ip-pool=$STATIC_IP_NAME
} catch { Write-Host "  (이미 존재할 수 있음)" }

# 6. VPC 커넥터 생성 (몇 분 소요)
Write-Host ">>> 6. VPC 커넥터 생성: $CONNECTOR_NAME (몇 분 소요)"
try {
  gcloud compute networks vpc-access connectors create $CONNECTOR_NAME `
    --network=$NETWORK --region=$REGION --subnet=$SUBNET_NAME `
    --min-instances=2 --max-instances=3
} catch { Write-Host "  (이미 존재할 수 있음)" }

# 7. 고정 IP 출력
Write-Host ""
Write-Host "=========================================="
Write-Host "White IP에 등록할 고정 IP:"
gcloud compute addresses describe $STATIC_IP_NAME `
  --region=$REGION --format="get(address)"
Write-Host "=========================================="
Write-Host ""
Write-Host "다음: Firebase Functions 배포 후 아래 URL로 접속해 위 IP가 나오는지 확인하세요."
Write-Host "  https://us-central1-$PROJECT_ID.cloudfunctions.net/getReportEgressIP"
