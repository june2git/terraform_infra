#!/bin/bash
#
# Bastion Host user_data 설치 진행 상황 확인 스크립트
#

set -e

echo "=========================================="
echo "Bastion Host 설정 상태 확인"
echo "=========================================="

# Bastion Public IP 가져오기
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null)

if [ -z "$BASTION_IP" ]; then
  echo "❌ Bastion Host가 아직 생성되지 않았습니다."
  echo "먼저 'terraform apply'를 실행해주세요."
  exit 1
fi

echo "✓ Bastion Public IP: $BASTION_IP"
echo ""

# SSH 키 확인
KEY_NAME=$(terraform output -raw bastion_key_name 2>/dev/null)
if [ ! -f "${KEY_NAME}.pem" ]; then
  echo "❌ SSH 키 파일을 찾을 수 없습니다: ${KEY_NAME}.pem"
  exit 1
fi

echo "SSH 연결 테스트 중..."
SSH_OPTS="-i ${KEY_NAME}.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5"

# SSH 연결 가능 여부 확인
if ! ssh $SSH_OPTS ubuntu@$BASTION_IP "echo 'SSH 연결 성공'" 2>/dev/null; then
  echo "⚠️  SSH 연결 실패 - Bastion이 아직 부팅 중이거나 보안 그룹 설정을 확인해주세요."
  echo ""
  echo "다음 명령어로 직접 접속해보세요:"
  echo "  ssh -i ${KEY_NAME}.pem ubuntu@$BASTION_IP"
  exit 1
fi

echo ""
echo "=========================================="
echo "User Data 스크립트 실행 상태"
echo "=========================================="

# cloud-init 상태 확인
CLOUD_INIT_STATUS=$(ssh $SSH_OPTS ubuntu@$BASTION_IP "cloud-init status 2>/dev/null" || echo "unknown")
echo "Cloud-Init 상태: $CLOUD_INIT_STATUS"
echo ""

# user-data 로그 확인
echo "📋 User Data 실행 로그 (최근 50줄):"
echo "=========================================="
ssh $SSH_OPTS ubuntu@$BASTION_IP "sudo tail -50 /var/log/user-data.log 2>/dev/null || echo '로그 파일이 아직 생성되지 않았습니다.'"
echo ""

echo "=========================================="
echo "설치된 도구 확인"
echo "=========================================="

# kubectl 확인
KUBECTL_VER=$(ssh $SSH_OPTS ubuntu@$BASTION_IP "kubectl version --client --short 2>/dev/null | head -1 || echo '❌ 미설치'")
echo "kubectl: $KUBECTL_VER"

# AWS CLI 확인
AWS_VER=$(ssh $SSH_OPTS ubuntu@$BASTION_IP "aws --version 2>/dev/null || echo '❌ 미설치'")
echo "AWS CLI: $AWS_VER"

# Helm 확인
HELM_VER=$(ssh $SSH_OPTS ubuntu@$BASTION_IP "helm version --short 2>/dev/null || echo '❌ 미설치'")
echo "Helm: $HELM_VER"

# Docker 확인
DOCKER_VER=$(ssh $SSH_OPTS ubuntu@$BASTION_IP "docker --version 2>/dev/null || echo '❌ 미설치'")
echo "Docker: $DOCKER_VER"

echo ""
echo "=========================================="
echo "환경 변수 확인"
echo "=========================================="
ssh $SSH_OPTS ubuntu@$BASTION_IP "bash -lc 'echo \"CLUSTER_NAME: \$CLUSTER_NAME\"'"
ssh $SSH_OPTS ubuntu@$BASTION_IP "bash -lc 'echo \"AWS_DEFAULT_REGION: \$AWS_DEFAULT_REGION\"'"
ssh $SSH_OPTS ubuntu@$BASTION_IP "bash -lc 'echo \"VPCID: \$VPCID\"'"

echo ""
echo "=========================================="
echo "Kubernetes 클러스터 연결 확인"
echo "=========================================="
NODES=$(ssh $SSH_OPTS ubuntu@$BASTION_IP "kubectl get nodes --no-headers 2>/dev/null | wc -l" || echo "0")
if [ "$NODES" -gt 0 ]; then
  echo "✅ EKS 클러스터 연결 성공! ($NODES개 노드)"
  ssh $SSH_OPTS ubuntu@$BASTION_IP "kubectl get nodes 2>/dev/null"
else
  echo "⚠️  EKS 클러스터 연결 실패 또는 kubeconfig 미설정"
fi

echo ""
echo "=========================================="
echo "완료!"
echo "=========================================="
echo ""
echo "💡 전체 로그 확인:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@$BASTION_IP"
echo "  sudo cat /var/log/user-data.log"
echo ""
echo "💡 실시간 로그 모니터링:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@$BASTION_IP"
echo "  sudo tail -f /var/log/user-data.log"

