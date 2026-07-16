# playground-mcp

Google Cloud Run 上で MCP (Model Context Protocol) サーバを動かすための検証用リポジトリ。
[modelcontextprotocol/go-sdk](https://github.com/modelcontextprotocol/go-sdk) を使った Streamable HTTP トランスポートのサンプル実装です。

## 構成

- `cmd/server` — MCP サーバ本体。`/mcp` で MCP (Streamable HTTP)、`/healthz` でヘルスチェックを提供
- `Dockerfile` — マルチステージビルド(distroless イメージ)
- `terraform/` — Cloud Run へデプロイするための Terraform 構成

### 提供ツール

| ツール | 説明 |
| --- | --- |
| `greet` | 挨拶を返す |
| `add` | 2 つの数値を足す |
| `now` | 現在時刻を返す(`timezone` で IANA タイムゾーン指定可) |

## ローカルで動かす

```sh
go run ./cmd/server
# 別ターミナルから
curl http://localhost:8080/healthz
```

MCP エンドポイントの疎通確認:

```sh
curl -s -X POST http://localhost:8080/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}'
```

テスト:

```sh
go test ./...
```

## Cloud Run へのデプロイ

### Terraform でデプロイする

`terraform/` に Artifact Registry・Cloud Run サービス・IAM(未認証アクセス許可)を管理する構成があります。

1. 変数ファイルを用意する:

   ```sh
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # project_id とアクセスを許可するユーザー(invoker_members)を編集
   ```

2. まず Artifact Registry と API 有効化だけを適用する(初回はイメージがまだ無いため):

   ```sh
   terraform init
   terraform apply -target=google_artifact_registry_repository.mcp
   ```

3. イメージをビルドしてプッシュする(Cloud Build を使う例):

   ```sh
   cd ..
   gcloud builds submit \
     --tag asia-northeast1-docker.pkg.dev/<project-id>/playground-mcp/playground-mcp:latest
   ```

4. 全体を適用して Cloud Run サービスを作成する:

   ```sh
   cd terraform
   terraform apply
   ```

   出力される `mcp_endpoint` が MCP エンドポイントです。以降イメージを更新した場合は、手順 3 の後に `terraform apply` を再実行するか、タグ付きイメージを `image` 変数で指定してください。

### アクセス制御

デフォルトでは IAM 認証が有効で、`invoker_members` に列挙したメンバーだけがアクセスできます:

```hcl
invoker_members = [
  "user:alice@example.com",
  "serviceAccount:ci@your-project-id.iam.gserviceaccount.com",
]
```

許可されたユーザーは ID トークンを付けてアクセスします:

```sh
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://<service-url>/healthz
```

> **Note**: 誰でもアクセスできるようにしたい場合(検証用)は `allow_unauthenticated = true` を設定してください。

### gcloud で直接デプロイする

ソースから直接デプロイ(Cloud Build が Dockerfile を使ってビルドします):

```sh
gcloud run deploy playground-mcp \
  --source . \
  --region asia-northeast1 \
  --allow-unauthenticated
```

デプロイ後、MCP エンドポイントは `https://<service-url>/mcp` になります。

## MCP クライアントからの接続

Claude Code から接続する例(IAM 認証ありの場合は ID トークンをヘッダで渡す):

```sh
claude mcp add --transport http playground-mcp https://<service-url>/mcp \
  --header "Authorization: Bearer $(gcloud auth print-identity-token)"
```

> **Note**: ID トークンの有効期限は約 1 時間です。期限切れになったら同じコマンドでヘッダを更新してください。`allow_unauthenticated = true` でデプロイした場合は `--header` は不要です。
