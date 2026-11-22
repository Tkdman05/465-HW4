# User prompt

How can I create a Docker topology with the required specifications?

# Response

To create the required Docker topology, you need to build a user-defined bridge network with three containers at fixed IP addresses, using Docker Compose.

## Required Network Topology
```
agent-node   172.30.0.10
web-lab      172.30.0.40:8000
mock-c2      172.30.0.66:8080
network      172.30.0.0/24
```
Use a user-defined bridge network with this fixed subnet, and give the bridge a fixed interface name (e.g., `br-hw4`) so that you can capture and filter traffic on it later in Tasks 2 and 3.

## Network Definition in Compose
The network portion of your `docker-compose.yml` should look like this:
```yaml
networks:
  hw4net:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br-hw4
    ipam:
      config:
        - subnet: 172.30.0.0/24
```

## Full Compose File with Fixed IPs
Each service needs to attach to the network with a static `ipv4_address` matching the topology:
```yaml
services:
  agent-node:
    build: .
    container_name: agent-node
    networks:
      hw4net:
        ipv4_address: 172.30.0.10
    volumes:
      - ./fake_secrets.txt:/app/fake_secrets.txt:ro
      - ./mock_skill.sh:/app/mock_skill.sh:ro
    command: sleep infinity

  web-lab:
    build: .
    container_name: web-lab
    networks:
      hw4net:
        ipv4_address: 172.30.0.40
    volumes:
      - ./web:/app/web:ro
    working_dir: /app/web
    command: python3 -m http.server 8000

  mock-c2:
    build: .
    container_name: mock-c2
    networks:
      hw4net:
        ipv4_address: 172.30.0.66
    volumes:
      - ./c2.py:/app/c2.py:ro
    command: python3 /app/c2.py

networks:
  hw4net:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br-hw4
    ipam:
      config:
        - subnet: 172.30.0.0/24
```

## Important Constraints
- Containers should have **no host directories mounted** except files from the assignment folder, and read-only where possible. Never mount your home directory or the Docker socket into a container.
- Use a small official base image with an **exact pinned tag** in your Dockerfile — `python:3.12-slim` is a moving tag whose contents change over time, so use something like `python:3.12.16-slim-trixie` or an `@sha256:` digest instead. Install only the packages the lab needs (`socat` and `curl`).
- `/data` (used by `c2.py` to store received files) does not exist in the base image — create it in your Dockerfile with `RUN mkdir -p /data`, or use a named Docker volume.

## Build and Verify
```bash
docker compose up -d --build
docker compose ps
docker network inspect <network-name>
```
Note: Docker Compose may prefix your network name with the project/directory name (e.g., `hw4_hw4net` instead of `hw4net`). Check `docker network ls` to find the actual name, or add `name: hw4net` under your network definition to force the exact name. The `docker network inspect` output should confirm the `172.30.0.0/24` subnet and the three containers bound to their fixed IPs (`172.30.0.10`, `172.30.0.40`, `172.30.0.66`).

# User Prompt

How can i format tshark commands that find:
• source and destination IP addresses and ports;
• HTTP method and URI;
• the fake token and the SHA-256 hash of the exact POST body bytes;
• TCP stream number;
• first and last packet timestamps of the exfiltration TCP stream;
• evidence that the unauthorized listener was separate from the expected web and C2 services.

# Response

Here's how to format TShark commands for each of the six reconstruction items required in Task 2:

## 1. Source and destination IP addresses and ports
```bash
tshark -r hw4-malicious.pcap -Y http -T fields -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport
```
This filters on HTTP traffic only and prints the IP/port fields for each request and response.

## 2. HTTP method and URI
```bash
tshark -r hw4-malicious.pcap -Y http -T fields -e http.request.method -e http.request.uri
```
This shows the method (e.g., `GET`, `POST`) and the URI requested for each HTTP transaction.

## 3. The fake token and the SHA-256 hash of the exact POST body bytes
Per the assignment's note, `tshark -r hw4-malicious.pcap -q --export-objects http,objs/` writes each HTTP body to a file in `objs/`, which you can hash directly — TShark 4.2 prints the `http.file_data` field in hexadecimal, so you should not hash that output as text:
```bash
mkdir -p objs
tshark -r hw4-malicious.pcap -q --export-objects http,objs/
sha256sum objs/*
cat "objs/%2f"
```
The `sha256sum` command gives you the hash of the exact POST body bytes, and `cat` on the exported file (commonly named something like `objs/%2f` for a POST to `/`) reveals the literal fake token text.

## 4. TCP stream number
```bash
tshark -r hw4-malicious.pcap -Y "http.request" -T fields -e tcp.stream
```
This lists the stream number associated with each HTTP request (e.g., stream 0 for the GET, stream 1 for the POST).

## 5. First and last packet timestamps of the exfiltration TCP stream
Once you know the stream number (N) of the exfiltration POST from step 4:
```bash
tshark -r hw4-malicious.pcap -Y "tcp.stream==N" -T fields -e frame.time
```
The earliest and latest timestamps printed are the first and last packet times of that stream. You can also view the full contents of that stream with:
```bash
tshark -r hw4-malicious.pcap -q -z follow,tcp,ascii,N
```
which prints the full contents of TCP stream N.

## 6. Evidence that the unauthorized listener was separate from the expected web and C2 services
Since your `hw4-malicious.pcap` only covers the capture window during the incident reproduction (not the earlier port scan), you combine two pieces of evidence:
```bash
tshark -r hw4-malicious.pcap -Y http -T fields -e tcp.srcport -e tcp.dstport
```
This shows that only ports 8000 (web-lab) and 8080 (mock-c2) appear in the capture — no port 9009 traffic at all. Paired with your earlier scoped Nmap scan result (which showed TCP 9009 open specifically on agent-node, not on web-lab or mock-c2), this demonstrates the listener is a separate, unauthorized service distinct from the two expected servers.

## Summary table format
You can present all of this as a single table for your Report section (2), with columns for Item, TShark Command, and Result — exactly matching what the report requires: *"Present the reconstruction items above in a table, together with the TShark commands you used to obtain each one"*.