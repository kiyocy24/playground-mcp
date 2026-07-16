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

variable "invoker_members" {
  description = "サービスの呼び出しを許可する IAM メンバー(例: [\"user:alice@example.com\", \"serviceAccount:ci@project.iam.gserviceaccount.com\"])"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.invoker_members : can(regex("^(user|group|serviceAccount|domain):", m))])
    error_message = "invoker_members の各要素は user: / group: / serviceAccount: / domain: のいずれかで始まる必要があります。"
  }
}

variable "allow_unauthenticated" {
  description = "未認証アクセス(allUsers)を許可するか。特定ユーザーのみに限定する場合は false のまま invoker_members を使う"
  type        = bool
  default     = false
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
