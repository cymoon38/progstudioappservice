#!/bin/bash
# Firebase Cloud Functions 고정 Egress IP 설정
# 리포트 서비스 White IP 등록용. 실행 전: gcloud auth login, gcloud config set project PROJECT_ID

set -e
PROJECT_ID="${PROJECT_ID:-community-b19fb}"
REGION="${REGION:-us-central1}"
NETWORK="default"
SUBNET_NAME="report-egress-subnet"
SUBNET_RANGE="10.8.0.0/28"
ROUTER_NAME="report-egress-router"
NAT_NAME="report-egress-nat"
STATIC_IP_NAME="report-egress-ip"
CONNECTOR_NAME="report-egress-connector"

echo "Project: $PROJECT_ID, Region: $REGION"
gcloud config set project "$PROJECT_ID"

# 1. 전용 서브넷 생성 (커넥터용)
echo ">>> 1. 서브넷 생성: $SUBNET_NAME ($SUBNET_RANGE)"
gcloud compute networks subnets create "$SUBNET_NAME" \
  --network="$NETWORK" \
  --region="$REGION" \
  --range="$SUBNET_RANGE" \
  --quiet 2>/dev/null || echo "  (이미 존재할 수 있음)"

# 2. Private Google Access 활성화 (Google API 접근 유지)
echo ">>> 2. Private Google Access 활성화"
gcloud compute networks subnets update "$SUBNET_NAME" \
  --region="$REGION" \
  --enable-private-ip-google-access \
  --quiet

# 3. 고정 IP 예약
echo ">>> 3. 고정 IP 예약: $STATIC_IP_NAME"
gcloud compute addresses create "$STATIC_IP_NAME" \
  --region="$REGION" \
  --quiet 2>/dev/null || echo "  (이미 존재할 수 있음)"

# 4. Cloud Router 생성
echo ">>> 4. Cloud Router 생성: $ROUTER_NAME"
gcloud compute routers create "$ROUTER_NAME" \
  --network="$NETWORK" \
  --region="$REGION" \
  --quiet 2>/dev/null || echo "  (이미 존재할 수 있음)"

# 5. Cloud NAT 생성 (위 서브넷만 NAT)
echo ">>> 5. Cloud NAT 생성: $NAT_NAME"
gcloud compute routers nats create "$NAT_NAME" \
  --router="$ROUTER_NAME" \
  --region="$REGION" \
  --nat-custom-subnet-ip-ranges="$SUBNET_NAME" \
  --nat-external-ip-pool="$STATIC_IP_NAME" \
  --quiet 2>/dev/null || echo "  (이미 존재할 수 있음)"

# 6. Serverless VPC Access 커넥터 생성 (위에서 만든 서브넷 사용)
echo ">>> 6. VPC 커넥터 생성: $CONNECTOR_NAME (몇 분 소요)"
gcloud compute networks vpc-access connectors create "$CONNECTOR_NAME" \
  --network="$NETWORK" \
  --region="$REGION" \
  --subnet="$SUBNET_NAME" \
  --min-instances=2 \
  --max-instances=3 \
  --quiet 2>/dev/null || echo "  (이미 존재할 수 있음)"

# 7. 고정 IP 출력 (White IP에 등록할 값)
echo ""
echo "=========================================="
echo "White IP에 등록할 고정 IP:"
gcloud compute addresses describe "$STATIC_IP_NAME" \
  --region="$REGION" \
  --format="get(address)"
echo "=========================================="
echo ""
echo "다음: Firebase Functions 배포 후 아래 URL로 접속해 위 IP가 나오는지 확인하세요."
echo "  https://us-central1-${PROJECT_ID}.cloudfunctions.net/getReportEgressIP"
echo ""
