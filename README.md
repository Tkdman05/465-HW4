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

# Task 2: