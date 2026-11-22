#!/usr/bin/env bash
set -euo pipefail

CHAIN=HW4_AGENT_EGRESS
BRIDGE=br-hw4
AGENT=172.30.0.10

if iptables -w -C DOCKER-USER -i "$BRIDGE" -s "$AGENT" -j "$CHAIN" 2>/dev/null; then
  iptables -w -D DOCKER-USER -i "$BRIDGE" -s "$AGENT" -j "$CHAIN"
fi
if iptables -w -L "$CHAIN" >/dev/null 2>&1; then
  iptables -w -F "$CHAIN"
  iptables -w -X "$CHAIN"
fi
