# GitHub Actions から OIDC (Workload Identity Federation) で
# キーレスにデプロイするための構成。
#
# 注意: Workload Identity Pool / Provider は削除しても 30 日間はソフトデリート状態で
# 残り、同じ ID を再作成できない。destroy 後に作り直す場合は別 ID にすること。

resource "google_project_service" "iam_credentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "GitHub Actions の OIDC トークンを受け入れる Workload Identity Pool"

  depends_on = [google_project_service.iam_credentials]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # 対象リポジトリ以外の GitHub Actions からのトークンを拒否する
  attribute_condition = "assertion.repository == \"${var.github_repository}\""
}

# GitHub Actions が借用するデプロイ用サービスアカウント
resource "google_service_account" "github_deployer" {
  account_id   = "github-deployer"
  display_name = "GitHub Actions deployer for ${var.service_name}"
}

# 対象リポジトリの GitHub Actions にのみ SA の借用を許可
resource "google_service_account_iam_member" "github_deployer_wif" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# Artifact Registry へのイメージ push(リポジトリ単位で付与)
resource "google_artifact_registry_repository_iam_member" "github_deployer_writer" {
  location   = google_artifact_registry_repository.mcp.location
  repository = google_artifact_registry_repository.mcp.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_deployer.email}"
}

# Cloud Run サービスの更新(デプロイ)。対象サービスに限定して付与する
resource "google_cloud_run_v2_service_iam_member" "github_deployer_developer" {
  project  = var.project_id
  location = google_cloud_run_v2_service.mcp.location
  name     = google_cloud_run_v2_service.mcp.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.github_deployer.email}"
}

# 実行用 SA(mcp_runner)を指定してデプロイするために必要
resource "google_service_account_iam_member" "github_deployer_act_as_runner" {
  service_account_id = google_service_account.mcp_runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}
