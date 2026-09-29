// Package browsermcp exposes one BrowserMCP stdio process over loopback HTTP.
package browsermcp

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"sync"
	"syscall"
)

type Config struct {
	Child []string
	Port  int
}

type request struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type response struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type pendingResult struct {
	result json.RawMessage
	err    *rpcError
}

type child struct {
	cmd     *exec.Cmd
	stdin   io.WriteCloser
	writeMu sync.Mutex
	mu      sync.Mutex
	pending map[string]chan pendingResult
}

// Broker starts only one child and assigns every forwarded request a private ID.
type Broker struct {
	childArgs []string
	mu        sync.Mutex
	child     *child
	init      json.RawMessage
	tools     json.RawMessage
}

func New(childArgs []string) *Broker {
	return &Broker{childArgs: childArgs}
}

func Run(ctx context.Context, config Config) error {
	if len(config.Child) == 0 {
		return errors.New("browsermcp-broker: child command is required")
	}
	listener, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", config.Port))
	if err != nil {
		return fmt.Errorf("browsermcp-broker: bind loopback listener: %w", err)
	}
	defer listener.Close()

	broker := New(config.Child)
	server := &http.Server{Handler: broker.Handler()}
	go func() {
		<-ctx.Done()
		broker.Close()
		_ = server.Shutdown(context.Background())
	}()
	err = server.Serve(listener)
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

// IsPortInUse identifies a bind collision so supervisors can leave its owner untouched.
func IsPortInUse(err error) bool {
	return errors.Is(err, syscall.EADDRINUSE)
}

func (b *Broker) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/mcp", b.handle)
	return mux
}

// Close stops the owned child when its supervisor stops the broker.
func (b *Broker) Close() {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.child != nil && b.child.cmd.Process != nil {
		_ = b.child.cmd.Process.Kill()
		_, _ = b.child.cmd.Process.Wait()
		b.child = nil
	}
}

func (b *Broker) handle(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	defer r.Body.Close()
	var req request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		b.writeError(w, nil, -32700, "invalid JSON-RPC request")
		return
	}
	if req.JSONRPC != "2.0" || req.Method == "" {
		b.writeError(w, req.ID, -32600, "invalid JSON-RPC request")
		return
	}
	if len(req.ID) == 0 {
		w.WriteHeader(http.StatusAccepted)
		return
	}

	result, rpcErr := b.call(r.Context(), req.Method, req.Params)
	if rpcErr != nil {
		b.writeError(w, req.ID, rpcErr.Code, rpcErr.Message)
		return
	}
	if req.Method == "initialize" && r.Header.Get("Mcp-Session-Id") == "" {
		w.Header().Set("Mcp-Session-Id", randomID())
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response{JSONRPC: "2.0", ID: req.ID, Result: result})
}

func (b *Broker) writeError(w http.ResponseWriter, id json.RawMessage, code int, message string) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response{JSONRPC: "2.0", ID: id, Error: &rpcError{Code: code, Message: message}})
}

func (b *Broker) call(ctx context.Context, method string, params json.RawMessage) (json.RawMessage, *rpcError) {
	b.mu.Lock()
	if err := b.ensureChild(ctx); err != nil {
		b.mu.Unlock()
		return nil, &rpcError{Code: -32000, Message: err.Error()}
	}
	switch method {
	case "initialize":
		b.mu.Unlock()
		return b.init, nil
	case "tools/list":
		b.mu.Unlock()
		return b.tools, nil
	default:
		child := b.child
		b.mu.Unlock()
		return child.call(ctx, method, params)
	}
}

func (b *Broker) ensureChild(ctx context.Context) error {
	if b.child != nil {
		return nil
	}
	if len(b.childArgs) == 0 {
		return errors.New("browsermcp-broker: child command is required")
	}
	cmd := exec.Command(b.childArgs[0], b.childArgs[1:]...)
	cmd.Env = scrubProxy(os.Environ())
	cmd.Stderr = os.Stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return err
	}
	c := &child{cmd: cmd, stdin: stdin, pending: make(map[string]chan pendingResult)}
	b.child = c
	go c.read(stdout)

	init, rpcErr := c.call(ctx, "initialize", json.RawMessage(`{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"browsermcp-broker","version":"1"}}`))
	if rpcErr != nil {
		return errors.New(rpcErr.Message)
	}
	tools, rpcErr := c.call(ctx, "tools/list", nil)
	if rpcErr != nil {
		return errors.New(rpcErr.Message)
	}
	b.init, b.tools = init, tools
	return nil
}

func (c *child) call(ctx context.Context, method string, params json.RawMessage) (json.RawMessage, *rpcError) {
	id := randomID()
	result := make(chan pendingResult, 1)
	c.mu.Lock()
	c.pending[id] = result
	c.mu.Unlock()
	body, _ := json.Marshal(request{JSONRPC: "2.0", ID: json.RawMessage(strconvQuote(id)), Method: method, Params: params})
	c.writeMu.Lock()
	_, err := c.stdin.Write(append(body, '\n'))
	c.writeMu.Unlock()
	if err != nil {
		c.removePending(id)
		return nil, &rpcError{Code: -32000, Message: err.Error()}
	}
	select {
	case received := <-result:
		return received.result, received.err
	case <-ctx.Done():
		c.removePending(id)
		return nil, &rpcError{Code: -32000, Message: ctx.Err().Error()}
	}
}

func (c *child) read(stdout io.Reader) {
	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		var message struct {
			ID     string          `json:"id"`
			Result json.RawMessage `json:"result"`
			Error  *rpcError       `json:"error"`
		}
		if json.Unmarshal(scanner.Bytes(), &message) != nil || message.ID == "" {
			continue
		}
		c.mu.Lock()
		pending := c.pending[message.ID]
		delete(c.pending, message.ID)
		c.mu.Unlock()
		if pending != nil {
			pending <- pendingResult{result: message.Result, err: message.Error}
		}
	}
}

func (c *child) removePending(id string) {
	c.mu.Lock()
	delete(c.pending, id)
	c.mu.Unlock()
}

func randomID() string {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		panic(err)
	}
	return hex.EncodeToString(bytes)
}

func strconvQuote(value string) string {
	encoded, _ := json.Marshal(value)
	return string(encoded)
}

func scrubProxy(environment []string) []string {
	result := make([]string, 0, len(environment))
	for _, entry := range environment {
		name := entry
		for i, char := range entry {
			if char == '=' {
				name = entry[:i]
				break
			}
		}
		switch name {
		case "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy":
			continue
		}
		result = append(result, entry)
	}
	return result
}
