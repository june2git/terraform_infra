# EKS 인프라 배포 순서 및 의존성

이 문서는 Terraform을 통한 EKS 인프라 배포 시 11단계 순서와 의존성을 설명합니다.

## 📋 배포 단계 (Phase)

### **Phase 1: VPC 및 네트워크 인프라 생성** (5-10분)
**파일**: `vpc.tf`

```
module "vpc"
```

**생성 리소스**:
- VPC
- Public Subnets (2개)
- Private Subnets (2개)
- Internet Gateway
- NAT Gateway
- Route Tables

**의존성**: 없음 (가장 먼저 생성)

---

### **Phase 2: Bastion Host 생성** (2-3분)
**파일**: `bastion.tf`

```
aws_security_group.bastion_sg
  ↓
aws_instance.eks_bastion
  depends_on: [module.vpc]
```

**생성 리소스**:
- Bastion Security Group
- Bastion EC2 Instance
- user_data 스크립트 실행 (백그라운드)

**의존성**:
- ✅ Phase 1: VPC 완료 필요

**참고**: 
- `aws_security_group_rule.bastion_to_eks_api`는 Phase 5 이후 생성됨

---

### **Phase 3: IAM 역할 생성** (2-3분)
**파일**: `iam_roles.tf`

```
data.aws_caller_identity.current
  ↓
aws_iam_role.devops_admin
aws_iam_role.dev_team
  ↓
aws_iam_role_policy_attachment.devops_admin_*
aws_iam_role_policy.dev_team_limited
```

**생성 리소스**:
- DevOps Admin IAM Role
- Dev Team IAM Role
- 정책 연결

**의존성**: 없음 (VPC와 병렬 생성 가능)

---

### **Phase 4: CloudWatch Log Groups 생성** (1분)
**파일**: `cloudwatch_logs.tf`

**상태**: ❌ 현재 비활성화됨 (비용 절감)

**생성 리소스**:
- (주석 처리됨) EKS API 로그 그룹
- (주석 처리됨) EKS Scheduler 로그 그룹

**의존성**: 없음

---

### **Phase 5: EKS 클러스터 및 노드 그룹 생성** (15-20분)
**파일**: `eks.tf`

```
module.eks
  depends_on: [
    module.vpc,              # Phase 1
    aws_iam_role.devops_admin,  # Phase 3
    aws_iam_role.dev_team,      # Phase 3
  ]
  ↓
  - EKS Control Plane
  - OIDC Provider
  - 기본 애드온 (CoreDNS, kube-proxy, VPC-CNI)
  - Managed Node Groups
```

**생성 리소스**:
- EKS Cluster Control Plane
- OIDC Provider (IRSA용)
- EKS Managed Node Groups
- Node Security Groups
- 기본 애드온 (CoreDNS, kube-proxy, VPC-CNI)

**의존성**:
- ✅ Phase 1: VPC 완료 필요
- ✅ Phase 3: IAM 역할 완료 필요

**이후 생성**:
- `aws_security_group_rule.bastion_to_eks_api` (EKS 클러스터 SG에 규칙 추가)

---

### **Phase 6: kubeconfig 설정 및 검증**
**상태**: ⏭️ 스킵 (Bastion에서 수동 관리)

**이유**: 
- Bastion Host에서 user_data 스크립트로 자동 설정
- 로컬 머신에서는 kubectl 미사용

---

### **Phase 7: ALB 및 External-DNS IRSA 생성** (2-3분)
**파일**: `irsa.tf`, `external_dns.tf`

```
module.alb_irsa
  depends_on: [module.eks]

module.external_dns_irsa
  depends_on: [module.eks]
```

**생성 리소스**:
- ALB Controller IAM Role (IRSA)
- External-DNS IAM Role (IRSA)
- GitHub Actions IAM Role (OIDC)

**의존성**:
- ✅ Phase 5: EKS OIDC Provider 완료 필요

---

### **Phase 8: Helm 애드온 설치**
**파일**: `helm_addons.tf`

**상태**: ❌ 비활성화됨 (Bastion에서 수동 설치)

**생성 리소스**:
- (주석 처리됨) ALB Controller Helm Release
- (주석 처리됨) ArgoCD Helm Release

**의존성**:
- Phase 7: ALB IRSA 완료 필요
- kubectl 접근 권한 필요 (Bastion에서만 가능)

**수동 설치 명령어**: `helm_addons.tf` 주석 참조

---

### **Phase 9: External-DNS 애드온 설치** (5-10분)
**파일**: `external_dns.tf`

```
aws_eks_addon.external_dns
  depends_on: [
    module.eks,
    module.eks.eks_managed_node_groups,
    module.external_dns_irsa,  # Phase 7
  ]
```

**생성 리소스**:
- External-DNS EKS Addon

**의존성**:
- ✅ Phase 5: EKS 클러스터 및 노드 그룹 완료 필요
- ✅ Phase 7: External-DNS IRSA 완료 필요

**타임아웃**: 20분 (Private Subnet 고려)

---

### **Phase 10: EBS-CSI IRSA 생성** (2분)
**파일**: `ebs_csi_driver.tf`

```
module.ebs_csi_irsa
  depends_on: [module.eks]
```

**생성 리소스**:
- EBS CSI Driver IAM Role (IRSA)

**의존성**:
- ✅ Phase 5: EKS OIDC Provider 완료 필요

---

### **Phase 11: EBS-CSI 애드온 설치** (5-10분)
**파일**: `ebs_csi_driver.tf`

```
aws_eks_addon.ebs_csi_driver
  depends_on: [
    module.eks,
    module.eks.eks_managed_node_groups,
    module.ebs_csi_irsa,  # Phase 10
  ]
```

**생성 리소스**:
- EBS CSI Driver EKS Addon

**의존성**:
- ✅ Phase 5: EKS 클러스터 및 노드 그룹 완료 필요
- ✅ Phase 10: EBS IRSA 완료 필요

**타임아웃**: 20분 (Private Subnet 고려)

**참고**: 
- **순환 의존성 방지**를 위해 EKS 모듈의 `cluster_addons`가 아닌 별도 `aws_eks_addon` 리소스로 관리
- EKS 모듈 내부에 포함 시 `module.eks` ↔ `module.ebs_csi_irsa` 순환 발생

---

## 🔄 의존성 그래프

```
Phase 1: VPC (vpc.tf)
  ↓
Phase 2: Bastion Host (bastion.tf)
  ↓ (병렬 가능)
Phase 3: IAM Roles (iam_roles.tf)
  ↓
Phase 5: EKS Cluster + Node Groups + Basic Addons (eks.tf)
         └─ cluster_addons: CoreDNS, kube-proxy, VPC-CNI만 포함
  ↓
  ├─→ Phase 7: ALB IRSA + External-DNS IRSA (irsa.tf, external_dns.tf)
  │     ↓
  │     └─→ Phase 9: External-DNS Addon (external_dns.tf)
  │
  └─→ Phase 10: EBS-CSI IRSA (ebs_csi_driver.tf)
        ↓
        └─→ Phase 11: EBS-CSI Addon (ebs_csi_driver.tf)
                       └─ 별도 aws_eks_addon 리소스로 관리

Phase 8: Helm (Bastion에서 수동 설치)
```

### **순환 의존성 방지 구조**
```
✅ 올바른 구조 (현재):
module.eks (cluster_addons에 EBS-CSI 미포함)
  ↓
module.ebs_csi_irsa
  ↓
aws_eks_addon.ebs_csi_driver (별도 리소스)

❌ 잘못된 구조 (순환 발생):
module.eks.cluster_addons.aws-ebs-csi-driver
  ↓ (requires)
module.ebs_csi_irsa.iam_role_arn
  ↓ (depends_on)
module.eks  ← 순환!
```

---

## ⚠️ 중요 사항

### **1️⃣ 순환 의존성 방지**

#### **EKS ↔ Bastion 순환 방지**
- ❌ **EKS가 Bastion에 의존하지 않음**
  - 초기에는 `depends_on = [aws_instance.eks_bastion]`이 있었으나 제거
  - Bastion은 EKS와 독립적으로 생성 가능

- ✅ **Bastion → EKS SG 규칙은 EKS 생성 후 추가**
  - `aws_security_group_rule.bastion_to_eks_api`
  - `depends_on = [module.eks]`

#### **EKS ↔ EBS-CSI IRSA 순환 방지** ⭐ 중요!
- ❌ **EKS 모듈 `cluster_addons`에 EBS-CSI 포함 불가**
  - `cluster_addons`가 `module.ebs_csi_irsa.iam_role_arn` 참조
  - `module.ebs_csi_irsa`가 `depends_on = [module.eks]`
  - → 순환 의존성 발생!

- ✅ **해결 방법: 별도 `aws_eks_addon` 리소스로 관리**
  - `ebs_csi_driver.tf`에서 `aws_eks_addon.ebs_csi_driver` 리소스 생성
  - EKS 모듈과 분리되어 순환 방지

### **2️⃣ IRSA 의존성**
- 모든 IRSA 역할은 EKS OIDC Provider에 의존
- `depends_on = [module.eks]` 명시 필수
- IRSA 역할:
  - ALB Controller IRSA (`irsa.tf`)
  - External-DNS IRSA (`external_dns.tf`)
  - EBS-CSI IRSA (`ebs_csi_driver.tf`)

### **3️⃣ Addon 설치 순서**
1. **Phase 5**: 기본 애드온 (CoreDNS, kube-proxy, VPC-CNI)
   - EKS 모듈의 `cluster_addons`에 포함
   - EKS 클러스터와 함께 자동 설치
   
2. **Phase 9**: External-DNS
   - IRSA 생성 후 별도 `aws_eks_addon` 리소스로 설치
   
3. **Phase 11**: EBS-CSI
   - IRSA 생성 후 별도 `aws_eks_addon` 리소스로 설치
   - ⚠️ `cluster_addons`에 포함하지 않음 (순환 방지)

### **4️⃣ 타임아웃 설정**
- **External-DNS**: 20분 (Private Subnet 고려)
- **EBS-CSI**: 20분 (Private Subnet 고려)
- **기본 애드온**: EKS 모듈 기본값 사용

---

## 🚀 배포 명령어

```bash
# 환경 변수 설정
export TF_VAR_KeyName=mykey
export TF_VAR_MyIamUserAccessKeyID=<YOUR_ACCESS_KEY>
export TF_VAR_MyIamUserSecretAccessKey=<YOUR_SECRET_KEY>
export TF_VAR_SgIngressSshCidr=<YOUR_IP>/32

# 배포 실행
terraform init
terraform plan
terraform apply -auto-approve

# 배포 시간: 약 25-35분
```

---

## 🔍 배포 상태 확인

```bash
# Bastion 설정 상태 확인
./check-bastion-setup.sh

# 또는 직접 Bastion에 접속
ssh -i mykey.pem ubuntu@$(terraform output -raw bastion_public_ip)
sudo cat /var/log/user-data.log

# EKS 클러스터 확인
kubectl get nodes
kubectl get pods -A
```

---

## 📝 파일별 Phase 매핑

| Phase | 파일 | 주요 리소스 | 리소스 타입 | 소요 시간 |
|-------|------|-------------|-------------|-----------|
| 1 | `vpc.tf` | VPC, Subnets, IGW, NAT | `module.vpc` | 5-10분 |
| 2 | `bastion.tf` | Bastion EC2, Security Group | `aws_instance`, `aws_security_group` | 2-3분 |
| 3 | `iam_roles.tf` | IAM Roles, Policies | `aws_iam_role`, `aws_iam_role_policy_attachment` | 2-3분 |
| 4 | `cloudwatch_logs.tf` | ❌ (비활성화) | - | - |
| 5 | `eks.tf` | EKS Cluster, Node Groups, 기본 애드온 | `module.eks` | 15-20분 |
| 6 | - | ⏭️ (스킵) | - | - |
| 7 | `irsa.tf`, `external_dns.tf` | ALB/External-DNS IRSA | `module.*_irsa` | 2-3분 |
| 8 | `helm_addons.tf` | ❌ (Bastion에서 수동 설치) | - | - |
| 9 | `external_dns.tf` | External-DNS Addon | `aws_eks_addon.external_dns` | 5-10분 |
| 10 | `ebs_csi_driver.tf` | EBS-CSI IRSA | `module.ebs_csi_irsa` | 2분 |
| 11 | `ebs_csi_driver.tf` | EBS-CSI Addon | `aws_eks_addon.ebs_csi_driver` | 5-10분 |

**총 배포 시간**: 약 25-35분

### **리소스 타입별 분류**
- **Terraform Module**: `module.vpc`, `module.eks`, `module.*_irsa`
- **EKS Addon**: `aws_eks_addon.external_dns`, `aws_eks_addon.ebs_csi_driver`
- **AWS Resource**: `aws_instance`, `aws_security_group`, `aws_iam_role` 등

---

## 📚 참고 사항

### **1. Terraform 암묵적 의존성**
Terraform은 리소스 간 참조를 자동으로 감지하여 의존성을 처리합니다:
- `module.vpc.vpc_id` → VPC 모듈에 자동 의존
- `module.eks.oidc_provider_arn` → EKS 모듈에 자동 의존
- `module.eks.cluster_name` → EKS 모듈에 자동 의존
- `module.ebs_csi_irsa.iam_role_arn` → EBS IRSA 모듈에 자동 의존
- `module.eks.cluster_security_group_id` → EKS 모듈에 자동 의존

### **2. 명시적 `depends_on`이 필요한 경우**
리소스 간 직접적인 참조가 없지만 순서가 중요한 경우:
- ✅ `aws_security_group_rule.bastion_to_eks_api` → `depends_on = [module.eks]`
- ✅ `module.ebs_csi_irsa` → `depends_on = [module.eks]`
- ✅ `module.external_dns_irsa` → `depends_on = [module.eks]`
- ✅ `module.alb_irsa` → `depends_on = [module.eks]`

### **3. 병렬 생성 가능한 리소스**
다음 리소스들은 서로 의존하지 않아 Terraform이 병렬로 생성합니다:
- Phase 1 (VPC)
- Phase 2 (Bastion Host) - VPC 완료 후
- Phase 3 (IAM Roles) - VPC와 병렬 가능

**병렬화 효과**: 전체 배포 시간 단축

### **4. EKS 모듈의 `cluster_addons` 제한사항**
- ✅ **포함 가능**: 외부 의존성이 없는 애드온
  - CoreDNS, kube-proxy, VPC-CNI
  
- ❌ **포함 불가**: IRSA가 필요한 애드온
  - EBS-CSI (순환 의존성 발생)
  - External-DNS (별도 관리 권장)
  
- ✅ **해결 방법**: `aws_eks_addon` 리소스로 별도 관리

### **5. 순환 의존성 디버깅**
순환 의존성 에러 발생 시:
```bash
# 의존성 그래프 생성
terraform graph | dot -Tpng > graph.png

# 또는 텍스트 형식으로
terraform graph > graph.dot
```

---

## 🔄 변경 이력

### **v2.0 (2025-10-25)** - 현재 버전
- ✅ EBS-CSI를 `cluster_addons`에서 별도 `aws_eks_addon` 리소스로 분리
- ✅ 순환 의존성 제거 (EKS ↔ EBS-CSI IRSA)
- ✅ Phase 11 설명 업데이트
- ✅ 의존성 그래프에 순환 방지 구조 추가

### **v1.0 (2025-10-24)**
- 초기 문서 작성
- 11단계 배포 순서 정의
- EBS-CSI를 `cluster_addons`에 포함 (순환 의존성 발생)

---

**최종 업데이트**: 2025-10-25  
**문서 버전**: v2.0  
**Terraform Version**: >= 1.6.0  
**EKS Module Version**: ~> 20.0  
**AWS Provider Version**: >= 5.34.0, < 6.0.0

