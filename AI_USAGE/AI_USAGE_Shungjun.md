# AI Use Disclosure

**Student:** Sungjun Jo
**Course:** CSCE 465/765 Homework 4
**Tool/model and dates:** OpenAI Codex (GPT-6), November 21-22, 2026

## Purpose

I used Codex to help build and test the Task 3 firewall and Task 4 Suricata rules in our existing lab. I also used it to collect and crop screenshots, organize the evidence, and draft and revise the Task 3-5 sections of the report. In the lab simulation, we fetched the adversarial page and triggered the mock skill ourselves; Codex was not the simulated agent making that decision.

## AI conversation log files

- `AI_CONVERSATION_LOG_Shungjun.md` contains the relevant prompts and final AI replies from this chat. Intermediate tool traces are omitted, and the VM password is not included.

## What I used

- Codex-assisted `firewall.sh`, `firewall-reset.sh`, and the three rules in `local.rules`.
- Codex-assisted test commands and the results saved in `evidence/task3/` and `evidence/task4/`, including counters, logs, and screenshots.
- Codex-assisted explanations, tables, and layout for Tasks 3-5 in `report.pdf`.

## What I changed

I asked Codex to use our group's repository and packet captures, run the tests in the course Ubuntu VM, crop the screenshots to show the terminal, and revise the report wording. We also made `mock_skill.sh` executable so the Task 3 test could run. I will review the final wording and make any changes needed so it reflects my own understanding.

## How I tested it

We ran all five Task 3 checks in the course Ubuntu VM. The approved web fetch returned HTTP 200. The mock-C2 send and the connection to an unapproved port timed out. The host received the agent listener's banner, and unrelated Docker traffic returned HTTP 204. Packet counters and `HW4-C2-DROP` kernel log lines supported the blocked-C2 result. We also checked that `firewall-reset.sh` removed our chain and jump.

We ran Suricata 7.0.3 offline on the malicious and clean PCAPs with `-k none -S local.rules`. Each rule alerted once on the malicious capture and none alerted on the clean capture. The raw `fast.log` files are in `evidence/task4/`.

## One error or limitation

An early TCP SYN rule did not match the first packet as intended. We changed it to use `flow:to_server,stateless; flags:S;` and reran both PCAP tests. The HTTP content rules still require readable, unencrypted bodies.
