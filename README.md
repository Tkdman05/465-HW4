# Task 1: Build the Local Network Lab

Builds the Docker lab: three containers (**agent-node**, **web-lab**, **mock-c2**) on a fixed-IP bridge network, plus the mock skill and mock C2 receiver used by the rest of the assignment.

**Topology:** `172.30.0.0/24` bridge (`br-hw4`) — agent-node `.10`, web-lab `.40:8000`, mock-c2 `.66:8080`.

**Key files:** `docker-compose.yml`, `Dockerfile`, `fake_secrets.txt`, `web/benign.html`, `web/adversarial.html`, `mock_skill.sh`, `c2.py`.

**Run:**
```bash
docker compose up -d --build
docker compose ps
docker network inspect hw4_hw4net
```

**Verify exfiltration path:**
```bash
docker compose exec agent-node ./mock_skill.sh exfiltrate-course-file
docker compose exec mock-c2 sha256sum /data/received.bin
docker compose exec agent-node sha256sum /app/fake_secrets.txt
```
Matching hashes confirm the leak works before any defenses are added.

# Task 2: Scan, Capture, and Reconstruct the Event

Acts as the investigator: discovers the unauthorized TCP 9009 listener via a scoped Nmap scan, records the exfiltration live in a packet capture, and reconstructs it with TShark. Also produces a clean baseline capture for Task 4's false-positive testing.

**Scoped scan:** targets only agent-node (172.30.0.10) to identify the unexpected listener.

**Capture command (malicious):**
```bash
sudo tcpdump -i br-hw4 -s 0 -w hw4-malicious.pcap 'net 172.30.0.0/24'
```
While running, reproduce the incident in order: fetch `http://172.30.0.40:8000/adversarial.html`, then run `mock_skill.sh exfiltrate-course-file`.

**Capture command (clean baseline):**
```bash
sudo tcpdump -i br-hw4 -s 0 -w hw4-clean.pcap 'net 172.30.0.0/24'
```
Contains only a benign request from agent-node to web-lab.

**Reconstruction (TShark):** extracts source/destination IPs and ports, HTTP method/URI, the fake token and SHA-256 hash of the POST body, TCP stream number, first/last packet timestamps of the exfiltration stream, and evidence the TCP 9009 listener was separate from web-lab/mock-c2:
```bash
tshark -r hw4-malicious.pcap -Y http -T fields -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e http.request.method -e http.request.uri
tshark -r hw4-malicious.pcap -q --export-objects http,objs/
```

**Output files:** `hw4-malicious.pcap`, `hw4-clean.pcap` — both required for Task 4's offline Suricata evaluation.

# Task 3: Default-Deny Egress for the Agent Container

Contains the incident with a stateful packet-filter firewall: agent-node may open connections only to web-lab, while every other outbound connection — especially to mock-c2 — is dropped and logged.

**Bridge prerequisite:** since the three containers share one Linux bridge, bridged traffic only reaches `iptables` when `br_netfilter` is loaded:
```bash
modprobe br_netfilter
sysctl -w net.bridge.bridge-nf-call-iptables=1
```

**Policy (in `firewall.sh`, via a custom chain jumped to from `DOCKER-USER`):** allow established/related traffic; allow agent-node → web-lab:8000; log and drop agent-node → mock-c2:8080; drop all other new connections from agent-node; leave unrelated Docker traffic unchanged.

**Scripts:** `firewall.sh` (run with `sudo`) applies the policy; `firewall-reset.sh` removes only the course-added chain and jump.

**Verify:**
```bash
docker compose exec agent-node curl http://172.30.0.40:8000/benign.html   # Allowed
docker compose exec agent-node ./mock_skill.sh exfiltrate-course-file     # Blocked (times out)
sudo iptables -L HW4_AGENT_EGRESS -v -n                                   # Check counters
```
Five required tests confirm the policy: benign fetch allowed, exfiltration blocked, another unapproved port blocked, existing/reply traffic allowed, and unrelated Docker traffic unaffected.

# Task 4: Three Suricata Rules

Adds detection: three signature-based rules in `local.rules`, one per stage of the incident, run offline against both PCAPs to classify results as true/false positives/negatives.

**Rules:** (1) fake-secret token in an outbound HTTP request body; (2) `CSCE465-COURSE-MARKER` in the HTTP response body from web-lab; (3) a TCP connection from agent-node to mock-c2:8080. Each rule has a unique SID plus `msg`, `sid`, `rev`, direction, and `flow`/HTTP/`flags` keywords.

**Run offline:**
```bash
mkdir -p suricata-malicious suricata-clean
suricata -k none -r hw4-malicious.pcap -S local.rules -l suricata-malicious
suricata -k none -r hw4-clean.pcap -S local.rules -l suricata-clean
```
`-k none` disables TCP checksum validation, since bridge-captured packets carry unfinished checksums that would otherwise be discarded. Alerts appear in each output directory's `fast.log`.

**Expected result:** all three rules alert once on `hw4-malicious.pcap` (true positives) and produce no alerts on `hw4-clean.pcap` (true negatives).