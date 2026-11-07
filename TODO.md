# TODO

- [ ] Re-open inbound TCP for the clients once CVE-2026-98432 is confirmed fixed.
    - Background: Linux kernel IPv4 TCP use-after-free (CVSS 9.8), remotely reachable via any listening TCP port. Since 2026-10-30 inbound TCP on 30303 and 9000 has been closed on both the router (port forwards set to UDP only) and `ufw` (TCP allow rules removed). Clients still peer via outbound TCP and UDP discovery.
    - The node is already running `5.15.0-203-generic` (rebooted 2026-11-07), which is the version Ubuntu lists for the fix.
    - Waiting for: https://ubuntu.com/security/CVE-2026-98432 to show 22.04 jammy `linux` as **Released (5.15.0-203.213)**, with a USN. As of 2026-11-08 it still says "Vulnerable, work in progress in 5.15.0-203.213". 203.213 is in `jammy-updates` but not yet `jammy-security`.
    - Then:
        - Confirm `uname -r` is `5.15.0-203-generic` or later.
        - Router (EdgeMAX > Port Forwarding): set 30303 and 9000 back to `Both`, Apply.
        - Host: `sudo ufw allow 30303/tcp` and `sudo ufw allow 9000/tcp`, then `sudo ufw status`.
- [ ] Check file perms on the signing keys. Tighten them up if necessary in advance of running Claude Code on the host.
    - [x] `/data/lighthouse/mainnet/validators` tightened to `lighthouse-vc` only, dirs `700`, files `600` (2026-11-08).
    - [x] `/data/validator_keys` deleted from the host after copying to USB as `validator_keys-2024-04` and verifying hashes. The USB also has the 2022 keystores (same pubkeys, old password) in `validator_keys`.
    - [x] `e` is not in the `lighthouse-vc` group.
    - [ ] Confirm `e` has no passwordless sudo: `sudo -k; sudo -n true && echo PASSWORDLESS` should print nothing.
    - [ ] Remove `e` from the `lxd` group (`sudo gpasswd -d e lxd`). `lxd` membership is root-equivalent without a password.
- [ ] Get Claude Code installed.
- [ ] Review https://github.com/eliotstock/stake/issues/1 and see if there's anything left to do there.
