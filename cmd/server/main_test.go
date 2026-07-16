package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/modelcontextprotocol/go-sdk/mcp"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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
	require.NoError(t, err, "failed to connect")
	t.Cleanup(func() { session.Close() })

	return session
}

func callTool(t *testing.T, session *mcp.ClientSession, name string, args map[string]any) string {
	t.Helper()

	result, err := session.CallTool(t.Context(), &mcp.CallToolParams{
		Name:      name,
		Arguments: args,
	})
	require.NoError(t, err, "CallTool(%s) failed", name)
	require.False(t, result.IsError, "CallTool(%s) returned tool error: %+v", name, result.Content)
	require.NotEmpty(t, result.Content)

	text, ok := result.Content[0].(*mcp.TextContent)
	require.True(t, ok, "CallTool(%s): expected TextContent, got %T", name, result.Content[0])
	return text.Text
}

func TestListTools(t *testing.T) {
	session := startTestServer(t)

	result, err := session.ListTools(t.Context(), nil)
	require.NoError(t, err)

	var names []string
	for _, tool := range result.Tools {
		names = append(names, tool.Name)
	}
	assert.ElementsMatch(t, []string{"greet", "add", "now"}, names)
}

func TestGreet(t *testing.T) {
	session := startTestServer(t)

	got := callTool(t, session, "greet", map[string]any{"name": "Cloud Run"})
	assert.Contains(t, got, "Hello, Cloud Run!")
}

func TestAdd(t *testing.T) {
	session := startTestServer(t)

	got := callTool(t, session, "add", map[string]any{"a": 2, "b": 3})
	assert.Contains(t, got, "= 5")
}

func TestNow(t *testing.T) {
	session := startTestServer(t)

	got := callTool(t, session, "now", map[string]any{"timezone": "Asia/Tokyo"})
	assert.Contains(t, got, "+09:00", "expected JST offset")
}
