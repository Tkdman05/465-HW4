# HW4 — Task 1: Build the Local Network Lab

Builds the Docker lab: three containers (**agent-node**, **web-lab**, **mock-c2**) on a fixed-IP bridge network, plus the mock skill and mock C2 receiver used by the rest of the assignment [1].

**Topology:** `172.30.0.0/24` bridge (`br-hw4`) — agent-node `.10`, web-lab `.40:8000`, mock-c2 `.66:8080` [1].

**Key files:** `docker-compose.yml`, `Dockerfile`, `fake_secrets.txt`, `web/benign.html`, `web/adversarial.html`, `mock_skill.sh`, `c2.py` [1].

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
Matching hashes confirm the leak works before any defenses are added [1].

# HW4 — Task 2: Scan, Capture, and Reconstruct the Event

Acts as the investigator: discovers the unauthorized TCP 9009 listener via a scoped Nmap scan, records the exfiltration live in a packet capture, and reconstructs it with TShark. Also produces a clean baseline capture for Task 4's false-positive testing [1].

**Scoped scan:** targets only agent-node (172.30.0.10) to identify the unexpected listener [1].

**Capture command (malicious):**
```bash
sudo tcpdump -i br-hw4 -s 0 -w hw4-malicious.pcap 'net 172.30.0.0/24'
```
While running, reproduce the incident in order: fetch `http://172.30.0.40:8000/adversarial.html`, then run `mock_skill.sh exfiltrate-course-file` [1].

**Capture command (clean baseline):**
```bash
sudo tcpdump -i br-hw4 -s 0 -w hw4-clean.pcap 'net 172.30.0.0/24'
```
Contains only a benign request from agent-node to web-lab [1].

**Reconstruction (TShark):** extracts source/destination IPs and ports, HTTP method/URI, the fake token and SHA-256 hash of the POST body, TCP stream number, first/last packet timestamps of the exfiltration stream, and evidence the TCP 9009 listener was separate from web-lab/mock-c2 [1]:
```bash
tshark -r hw4-malicious.pcap -Y http -T fields -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e http.request.method -e http.request.uri
tshark -r hw4-malicious.pcap -q --export-objects http,objs/
```

**Output files:** `hw4-malicious.pcap`, `hw4-clean.pcap` — both required for Task 4's offline Suricata evaluation [1].