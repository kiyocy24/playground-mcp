package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

// startTestServer runs the MCP server behind an httptest server and
// returns a connected client session.
func startTestServer(t *testing.T) *mcp.ClientSession {
	t.Helper()

	server := newServer()
	handler := mcp.NewStreamableHTTPHandler(func(req *http.Request) *mcp.Server {
		return server
	}, nil)

	ts := httptest.NewServer(handler)
	t.Cleanup(ts.Close)

	client := mcp.NewClient(&mcp.Implementation{Name: "test-client", Version: "0.0.1"}, nil)
	session, err := client.Connect(t.Context(), &mcp.StreamableClientTransport{Endpoint: ts.URL}, nil)
	if err != nil {
		t.Fatalf("failed to connect: %v", err)
	}
	t.Cleanup(func() { session.Close() })

	return session
}

func callTool(t *testing.T, session *mcp.ClientSession, name string, args map[string]any) string {
	t.Helper()

	result, err := session.CallTool(t.Context(), &mcp.CallToolParams{
		Name:      name,
		Arguments: args,
	})
	if err != nil {
		t.Fatalf("CallTool(%s) failed: %v", name, err)
	}
	if result.IsError {
		t.Fatalf("CallTool(%s) returned tool error: %+v", name, result.Content)
	}
	text, ok := result.Content[0].(*mcp.TextContent)
	if !ok {
		t.Fatalf("CallTool(%s): expected TextContent, got %T", name, result.Content[0])
	}
	return text.Text
}

func TestListTools(t *testing.T) {
	session := startTestServer(t)

	result, err := session.ListTools(t.Context(), nil)
	if err != nil {
		t.Fatalf("ListTools failed: %v", err)
	}

	want := map[string]bool{"greet": false, "add": false, "now": false}
	for _, tool := range result.Tools {
		if _, ok := want[tool.Name]; ok {
			want[tool.Name] = true
		}
	}
	for name, found := range want {
		if !found {
			t.Errorf("tool %q not found", name)
		}
	}
}

func TestGreet(t *testing.T) {
	session := startTestServer(t)

	got := callTool(t, session, "greet", map[string]any{"name": "Cloud Run"})
	if !strings.Contains(got, "Hello, Cloud Run!") {
		t.Errorf("unexpected greeting: %q", got)
	}
}

func TestAdd(t *testing.T) {
	session := startTestServer(t)

	got := callTool(t, session, "add", map[string]any{"a": 2, "b": 3})
	if !strings.Contains(got, "= 5") {
		t.Errorf("unexpected sum: %q", got)
	}
}

func TestNow(t *testing.T) {
	session := startTestServer(t)

	got := callTool(t, session, "now", map[string]any{"timezone": "Asia/Tokyo"})
	if !strings.Contains(got, "+09:00") {
		t.Errorf("expected JST offset in %q", got)
	}
}
