# AI Use Disclosure

**Student:** Sungjun Jo
**Course:** CSCE 465/765 Homework 4
**Tool/model and date:** OpenAI Codex (GPT-6), November 21, 2026

## Purpose

I used Codex to help implement and verify my group's Task 3 firewall and Task 4 Suricata rules. The simulated `agent-node` in the lab did not use Codex to decide whether to run the mock skill; we manually triggered the skill as the assignment directed.

## AI conversation log files

- `AI_CONVERSATION_LOG_Shungjun.md` contains the relevant prompts and final AI replies from this Codex chat. Intermediate tool traces are omitted and the VM password is redacted.

## What I used

- Codex-assisted `firewall.sh`, `firewall-reset.sh`, and the three signatures in `local.rules`.
- Codex-assisted test commands, captured outputs and counters, in `evidence/task3/` and `evidence/task4/`.

## What I changed

I asked Codex to use the group's existing repository and captures, how to run the tests in the Ubuntu VM and modify the `mock_skill.sh` file also needed its executable bit set so the Task 3 test could run.

## How I tested it

In the course Ubuntu VM, we ran all five Task 3 firewall checks. The approved web fetch returned HTTP 200; the mock-C2 send and unapproved port timed out; the agent listener returned its banner; and unrelated Docker traffic returned HTTP 204. Packet counters and `HW4-C2-DROP` kernel log lines supported the blocked-C2 result. We also verified that `firewall-reset.sh` removed our chain and jump.

We ran Suricata 7.0.3 offline on the malicious and clean PCAPs with `-k none -S local.rules`. Each of the three rules alerted once on the malicious capture and none alerted on the clean capture. The raw `fast.log` files are in `evidence/task4/`.

## One error or limitation

An early version of the TCP SYN rule used a flow setting that did not match the first packet as intended. We changed it to `flow:to_server,stateless; flags:S;` and reran both PCAP tests. The HTTP content rules still depend on readable, unencrypted bodies.
