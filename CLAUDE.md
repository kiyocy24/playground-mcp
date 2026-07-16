# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの目的

Google Cloud Run 上で MCP (Model Context Protocol) サーバを立てるための検証用リポジトリ。
MCP サーバの実装には Go と公式 SDK [modelcontextprotocol/go-sdk](https://github.com/modelcontextprotocol/go-sdk) を使う。

## 技術スタック

- Go(モジュール管理は go.mod)
- MCP SDK: `github.com/modelcontextprotocol/go-sdk`
- デプロイ先: Google Cloud Run(コンテナ化して gcloud でデプロイ)

## よく使うコマンド

```sh
go build ./...        # ビルド
go test ./...         # 全テスト実行
go test -run TestName ./path/to/pkg   # 単一テスト実行
go vet ./...          # 静的解析
gofmt -l .            # フォーマットチェック
```

ローカル実行:

```sh
go run ./cmd/server   # サーバ起動(PORT 環境変数でポート指定、デフォルト 8080)
```

## アーキテクチャ上の前提

- Cloud Run で動かすため、MCP のトランスポートは stdio ではなく **Streamable HTTP** を使う(`mcp.NewStreamableHTTPHandler`)。
- Cloud Run はコンテナに `PORT` 環境変数を渡すので、リッスンポートは必ず `PORT` から読む。
- コンテナは Dockerfile でマルチステージビルドし、実行イメージは最小構成にする。
