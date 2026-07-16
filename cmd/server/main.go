// Command server is a sample MCP server that runs on Google Cloud Run.
//
// It exposes MCP over the streamable HTTP transport at /mcp, plus a
// plain /healthz endpoint for liveness checks.
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
	// Embed timezone data so the "now" tool works in the distroless
	// container image, which ships without tzdata.
	_ "time/tzdata"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

const serverName = "playground-mcp"

// GreetParams defines the parameters for the greet tool.
type GreetParams struct {
	Name string `json:"name" jsonschema:"Name of the person to greet"`
}

func greet(ctx context.Context, req *mcp.CallToolRequest, params *GreetParams) (*mcp.CallToolResult, any, error) {
	name := params.Name
	if name == "" {
		name = "world"
	}
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: fmt.Sprintf("Hello, %s! Greetings from %s on Cloud Run.", name, serverName)},
		},
	}, nil, nil
}

// AddParams defines the parameters for the add tool.
type AddParams struct {
	A float64 `json:"a" jsonschema:"First number"`
	B float64 `json:"b" jsonschema:"Second number"`
}

func add(ctx context.Context, req *mcp.CallToolRequest, params *AddParams) (*mcp.CallToolResult, any, error) {
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: fmt.Sprintf("%g + %g = %g", params.A, params.B, params.A+params.B)},
		},
	}, nil, nil
}

// NowParams defines the parameters for the now tool.
type NowParams struct {
	Timezone string `json:"timezone,omitempty" jsonschema:"IANA timezone name (e.g. Asia/Tokyo). Defaults to UTC"`
}

func now(ctx context.Context, req *mcp.CallToolRequest, params *NowParams) (*mcp.CallToolResult, any, error) {
	loc := time.UTC
	if params.Timezone != "" {
		l, err := time.LoadLocation(params.Timezone)
		if err != nil {
			return nil, nil, fmt.Errorf("unknown timezone %q: %w", params.Timezone, err)
		}
		loc = l
	}
	return &mcp.CallToolResult{
		Content: []mcp.Content{
			&mcp.TextContent{Text: time.Now().In(loc).Format(time.RFC3339)},
		},
	}, nil, nil
}

func newServer() *mcp.Server {
	server := mcp.NewServer(&mcp.Implementation{
		Name:    serverName,
		Version: "0.1.0",
	}, nil)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "greet",
		Description: "Return a friendly greeting",
	}, greet)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "add",
		Description: "Add two numbers",
	}, add)

	mcp.AddTool(server, &mcp.Tool{
		Name:        "now",
		Description: "Get the current time, optionally in a specific timezone",
	}, now)

	return server
}

func main() {
	// Cloud Run injects the port to listen on via the PORT env var.
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	server := newServer()

	handler := mcp.NewStreamableHTTPHandler(func(req *http.Request) *mcp.Server {
		return server
	}, nil)

	mux := http.NewServeMux()
	mux.Handle("/mcp", handler)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})

	addr := ":" + port
	log.Printf("%s listening on %s (MCP endpoint: /mcp)", serverName, addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
