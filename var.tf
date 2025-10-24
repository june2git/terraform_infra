variable "KeyName" {
  description = "Name of an existing EC2 KeyPair to enable SSH access to the instances."
  type        = string
}

variable "MyIamUserAccessKeyID" {
  description = "IAM User - AWS Access Key ID."
  type        = string
  sensitive   = true
}

variable "MyIamUserSecretAccessKey" {
  description = "IAM User - AWS Secret Access Key."
  type        = string
  sensitive   = true
}

variable "SgIngressSshCidr" {
  description = "The IP address range that can be used to SSH to the EC2 instances."
  type        = string
  validation {
    condition     = can(regex("^(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})$", var.SgIngressSshCidr))
    error_message = "The SgIngressSshCidr value must be a valid IP CIDR range of the form x.x.x.x/x."
  }
}

variable "MyInstanceType" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small", "t3.medium"], var.MyInstanceType)
    error_message = "Invalid instance type. Valid options are t2.micro, t2.small, t2.medium, t3.micro, t3.small, t3.medium."
  }
}

variable "ClusterBaseName" {
  description = "Base name of the cluster."
  type        = string
  default     = "myeks"
}

variable "KubernetesVersion" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.33"
}

variable "WorkerNodeInstanceType" {
  description = "EC2 instance type for the worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "WorkerNodeCount" {
  description = "Number of worker nodes."
  type        = number
  default     = 3
}

variable "WorkerNodeVolumesize" {
  description = "Volume size for worker nodes (in GiB)."
  type        = number
  default     = 30
}

variable "TargetRegion" {
  description = "AWS region where the resources will be created."
  type        = string
  default     = "ap-northeast-2"
}

variable "availability_zones" {
  description = "List of availability zones."
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "VpcBlock" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_blocks" {
  description = "List of CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_blocks" {
  description = "List of CIDR blocks for the private subnets."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "ecr_repo" { 
  description = "ECR 저장소 이름 (Docker 이미지 저장용)"
  type        = string
  default     = "demo-app" 
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "june2git"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "eks-app"
}

variable "api_log_retention_days" {
  description = "API 로그 보존 기간 (일)"
  type        = number
  default     = 30
  validation {
    condition     = var.api_log_retention_days >= 1 && var.api_log_retention_days <= 3653
    error_message = "API 로그 보존 기간은 1일에서 3653일 사이여야 합니다."
  }
}

variable "scheduler_log_retention_days" {
  description = "스케줄러 로그 보존 기간 (일)"
  type        = number
  default     = 7
  validation {
    condition     = var.scheduler_log_retention_days >= 1 && var.scheduler_log_retention_days <= 3653
    error_message = "스케줄러 로그 보존 기간은 1일에서 3653일 사이여야 합니다."
  }
}
