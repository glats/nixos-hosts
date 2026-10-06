# opencode-runtime-proxy

## MODIFIED Requirements

### Requirement: macm5 Native Runtime

`macm5` MUST retain native `openai-medium`, PONG/refresh/MCP-clean proof, gateway independence and other hosts' native tiers.

(Previously: smoke invoked V1.)

#### Scenario: Use native runtime after home proof [hosts:macm5]
- GIVEN healthy home transport
- WHEN configuration and isolated `opencode2` PONG run
- THEN native tier succeeds without proxy-provider selection

#### Scenario: Keep native runtime gated on transport [hosts:macm5]
- GIVEN absent transport validation
- WHEN provider selection is evaluated
- THEN native use remains unproven
