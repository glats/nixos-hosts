# macm5-openai-tls-tunnel

## MODIFIED Requirements

### Requirement: Proxy-Environment and MCP Isolation

Only isolated V2 home launchers MUST conditionally export proxy variables; profiles/daemon MUST NOT. MCP environments MUST remain clean; full-mode routing MAY tunnel MCP traffic.

(Previously: launcher targeted V1.)

#### Scenario: Inspect MCP environments [hosts:macm5]
- GIVEN representative MCP children
- WHEN environments are inspected
- THEN HTTP_PROXY/HTTPS_PROXY are absent

#### Scenario: Scoped launcher exports proxy conditionally [hosts:macm5]
- GIVEN listening/non-listening mixed inbound
- WHEN executable V2 home launcher runs
- THEN proxies equal http://127.0.0.1:2080 only when listening; otherwise stderr notice and clean environment; profiles export neither
