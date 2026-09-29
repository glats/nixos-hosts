package browsermcp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
)

func TestBrokerMultiplexesCorrelatedIDs(t *testing.T) {
	t.Setenv("GO_WANT_BROWSER_MCP_HELPER", "1")
	broker := New([]string{os.Args[0], "-test.run=TestBrowserMCPHelper", "--"})
	server := httptest.NewServer(broker.Handler())
	defer server.Close()

	call(t, server.URL, 1, "initialize", nil)
	call(t, server.URL, 2, "tools/list", nil)
	var group sync.WaitGroup
	for i := 0; i < 24; i++ {
		group.Add(1)
		go func(id int) {
			defer group.Done()
			result := call(t, server.URL, id, "tools/call", map[string]int{"index": id})
			index, ok := result["index"].(float64)
			if !ok || int(index) != id {
				t.Errorf("response %v correlated to the wrong request", id)
			}
		}(i)
	}
	group.Wait()
}

func TestRunUsesLoopbackAndRejectsCollision(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	if host, _, _ := net.SplitHostPort(listener.Addr().String()); host != "127.0.0.1" {
		t.Fatalf("listener escaped loopback: %q", host)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	err = Run(ctx, Config{Child: []string{"false"}, Port: port})
	if err == nil {
		t.Fatal("Run accepted an occupied loopback port")
	}
	if !IsPortInUse(err) {
		t.Fatalf("Run did not preserve the occupied-port error: %v", err)
	}
	_ = listener.Close()
}

func TestScrubProxy(t *testing.T) {
	got := scrubProxy([]string{"KEEP=value", "HTTPS_PROXY=http://proxy", "no_proxy=*"})
	if len(got) != 1 || got[0] != "KEEP=value" {
		t.Fatalf("proxy variables leaked into child environment: %v", got)
	}
}

func TestBrowserMCPHelper(t *testing.T) {
	if os.Getenv("GO_WANT_BROWSER_MCP_HELPER") != "1" {
		return
	}
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		var request struct {
			ID     string          `json:"id"`
			Method string          `json:"method"`
			Params json.RawMessage `json:"params"`
		}
		_ = json.Unmarshal(scanner.Bytes(), &request)
		result := json.RawMessage(`{"tools":[{"name":"one"}]}`)
		if request.Method == "initialize" {
			result = json.RawMessage(`{"protocolVersion":"2025-03-26","capabilities":{"tools":{}}}`)
		}
		if request.Method == "tools/call" {
			result = request.Params
		}
		response, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": request.ID, "result": json.RawMessage(result)})
		_, _ = os.Stdout.Write(append(response, '\n'))
	}
	os.Exit(0)
}

func call(t *testing.T, url string, id int, method string, params any) map[string]any {
	t.Helper()
	body, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": id, "method": method, "params": params})
	response, err := http.Post(url+"/mcp", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("%s returned %s", method, response.Status)
	}
	var decoded struct {
		Result map[string]any `json:"result"`
		Error  *rpcError      `json:"error"`
	}
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatal(err)
	}
	if decoded.Error != nil {
		t.Fatalf("%s failed: %s", method, decoded.Error.Message)
	}
	return decoded.Result
}
