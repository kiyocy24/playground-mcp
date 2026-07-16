variable "project_id" {
  description = "デプロイ先の Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Cloud Run と Artifact Registry のリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "service_name" {
  description = "Cloud Run サービス名"
  type        = string
  default     = "playground-mcp"
}

variable "repository_id" {
  description = "Artifact Registry のリポジトリ ID"
  type        = string
  default     = "playground-mcp"
}

variable "image" {
  description = "デプロイするコンテナイメージ。空の場合は Artifact Registry 上の <service_name>:latest を使う"
  type        = string
  default     = ""
}

variable "allow_unauthenticated" {
  description = "未認証アクセスを許可するか(検証用。実運用では false にして IAM 認証を使う)"
  type        = bool
  default     = true
}

variable "min_instances" {
  description = "最小インスタンス数"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "最大インスタンス数"
  type        = number
  default     = 3
}
