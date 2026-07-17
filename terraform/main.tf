locals {
  # var.image が空なら Artifact Registry 上の latest イメージを使う
  image = var.image != "" ? var.image : "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.mcp.repository_id}/${var.service_name}:latest"
}

# 必要な API を有効化
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_build" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# コンテナイメージの置き場
resource "google_artifact_registry_repository" "mcp" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Container images for the playground MCP server"
  format        = "DOCKER"

  depends_on = [google_project_service.artifact_registry]
}

# Cloud Run 実行用のサービスアカウント(最小権限: 追加ロールは付与しない)
resource "google_service_account" "mcp_runner" {
  account_id   = "${var.service_name}-runner"
  display_name = "Service account for the ${var.service_name} Cloud Run service"
}

# MCP サーバ本体
resource "google_cloud_run_v2_service" "mcp" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.mcp_runner.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = local.image

      # Cloud Run が PORT 環境変数を注入するポート
      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # Streamable HTTP は SSE の長時間接続を使うため CPU を常時割り当てる
        cpu_idle = false
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 0
        period_seconds        = 3
        failure_threshold     = 5
      }

      liveness_probe {
        http_get {
          path = "/healthz"
        }
        period_seconds = 30
      }
    }
  }

  # イメージの更新は GitHub Actions(コミット SHA タグ)が行うため、
  # terraform apply で :latest に巻き戻さない。トラフィック配分も
  # デプロイ側の操作を上書きしないよう無視する
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      traffic,
      client,
      client_version,
    ]
  }

  depends_on = [google_project_service.run]
}

# 指定したメンバーにのみ呼び出しを許可(IAM 認証)
resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = toset(var.invoker_members)

  project  = var.project_id
  location = google_cloud_run_v2_service.mcp.location
  name     = google_cloud_run_v2_service.mcp.name
  role     = "roles/run.invoker"
  member   = each.value
}

# 検証用: 未認証アクセスを許可する場合のみ
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.mcp.location
  name     = google_cloud_run_v2_service.mcp.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
