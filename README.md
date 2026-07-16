# playground-mcp

Google Cloud Run 上で MCP (Model Context Protocol) サーバを動かすための検証用リポジトリ。
[modelcontextprotocol/go-sdk](https://github.com/modelcontextprotocol/go-sdk) を使った Streamable HTTP トランスポートのサンプル実装です。

## 構成

- `cmd/server` — MCP サーバ本体。`/mcp` で MCP (Streamable HTTP)、`/healthz` でヘルスチェックを提供
- `Dockerfile` — マルチステージビルド(distroless イメージ)

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

ソースから直接デプロイ(Cloud Build が Dockerfile を使ってビルドします):

```sh
gcloud run deploy playground-mcp \
  --source . \
  --region asia-northeast1 \
  --allow-unauthenticated
```

デプロイ後、MCP エンドポイントは `https://<service-url>/mcp` になります。

> **Note**: `--allow-unauthenticated` は検証用です。実運用では IAM 認証(`--no-allow-unauthenticated` + ID トークン)や MCP レイヤでの認可を検討してください。

## MCP クライアントからの接続

Claude Code から接続する例:

```sh
claude mcp add --transport http playground-mcp https://<service-url>/mcp
```
