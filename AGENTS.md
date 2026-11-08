# AGENTS.md

Notes for AI coding agents (Claude Code etc.) working in this repo or on the staking host.

## What this repo is

A personal, hand-maintained guide to building and running an Ethereum staking machine without containers.

* `README.md`: the build and operations guide for the live node. Keep it accurate to what's actually running.
* `ARM.md`: notes from a Radxa Rock 5B that was never put into service. Historical only; don't use it to reason about the live node.
* `AZTEC.md`, `STARKNET.md`: notes for other nodes.
* `TODO.md`: open tasks, including anything temporarily changed on the host or router that needs undoing later. Check it before advising on node config.

Doc files use uppercase names (`FOO.md`).

## Git workflow

Commit and push to `main` directly without asking first, unless told otherwise.

## The live node

* Intel NUC, hostname `node01`, LAN IP `192.168.20.51`, Ubuntu 22.04 (jammy), not 24.04.
* Nethermind (EL), Lighthouse beacon node and validator client (CL), mev-boost, each as its own `systemd` service and user: `nethermind`, `lighthouse-bn`, `lighthouse-vc`, `mev-boost`.
* One validator, index 490968, with `0x02` (compounding) withdrawal credentials. The withdrawal address can never be changed.
* Router is an EdgeRouter Pro (EdgeMAX web UI), forwarding 30303 and 9000 to the node.
* `unattended-upgrades` installs from all origins and reboots automatically at 04:00 UTC when `/var/run/reboot-required` exists. Check `uname -r` against the latest installed kernel if in doubt.

## Safety rules on the host

* Never copy, export, move or print validator keystores, keystore passwords or the slashing protection DB. They live in `/data/lighthouse/mainnet/validators` and `/data/validator_keys` (the latter should be removed from the host or owned by root; see TODO.md).
* Never start a second validator client or import the keys anywhere else. Running the same keys twice gets the validator slashed.
* Restarting `lighthouse-vc` or rebooting costs attestations. Do it right after a `Successfully published attestations` log line, and only when needed.
* Don't expose 5052 (beacon API), 8545 (JSON-RPC) or 8551 (engine API) to the internet.
* Don't run `apt upgrade`, change `ufw` or change `systemd` units without being asked.
* You can't use `sudo` on the host: it always asks for a password and `Bash(sudo *)` is denied. When something needs root, give the user the exact command to run.

## Handy checks

```
uname -r
systemctl status nethermind lighthouse-bn lighthouse-vc mev-boost
journalctl -u nethermind -u lighthouse-bn -f -o cat | grep --line-buffered -iE 'peers'
journalctl -u lighthouse-vc -f -o cat | grep --line-buffered -iE 'attestation|error|warn'
sudo ufw status
```

Inbound TCP connections to the P2P ports (Lighthouse also dials out from port 9000, so remote ports like `:9000` are usually outbound):

```
ss -Htn4 state established '( sport = :9000 or sport = :30303 )'
```
