#!/usr/bin/env bash
set -euo pipefail

# Run on the Ubuntu course VM after the Compose lab is running.
modprobe br_netfilter
sysctl -w net.bridge.bridge-nf-call-iptables=1

CHAIN=HW4_AGENT_EGRESS
BRIDGE=br-hw4
AGENT=172.30.0.10
WEB=172.30.0.40
C2=172.30.0.66

iptables -w -N "$CHAIN" 2>/dev/null || true
iptables -w -F "$CHAIN"
iptables -w -C DOCKER-USER -i "$BRIDGE" -s "$AGENT" -j "$CHAIN" 2>/dev/null || \
  iptables -w -I DOCKER-USER 1 -i "$BRIDGE" -s "$AGENT" -j "$CHAIN"

# Replies to connections opened by other hosts, including the port-9009 test.
iptables -w -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# The sole permitted new connection opened by agent-node.
iptables -w -A "$CHAIN" -d "$WEB" -p tcp --dport 8000 \
  -m conntrack --ctstate NEW -j ACCEPT
# Log then drop attempted exfiltration to the local mock C2.
iptables -w -A "$CHAIN" -d "$C2" -p tcp --dport 8080 \
  -m conntrack --ctstate NEW -j LOG --log-prefix 'HW4-C2-DROP: '
iptables -w -A "$CHAIN" -d "$C2" -p tcp --dport 8080 \
  -m conntrack --ctstate NEW -j DROP
# Deny every other packet forwarded from agent-node.
iptables -w -A "$CHAIN" -j DROP

iptables -w -L "$CHAIN" -n -v --line-numbers
