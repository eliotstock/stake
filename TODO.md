# TODO

- [ ] Re-open inbound TCP for the clients once CVE-2026-98432 is confirmed fixed.
    - Background: Linux kernel IPv4 TCP use-after-free (CVSS 9.8), remotely reachable via any listening TCP port. Since 2026-10-30 inbound TCP on 30303 and 9000 has been closed on both the router (port forwards set to UDP only) and `ufw` (TCP allow rules removed). Clients still peer via outbound TCP and UDP discovery.
    - The node is already running `5.15.0-203-generic` (rebooted 2026-11-07), which is the version Ubuntu lists for the fix.
    - Waiting for: https://ubuntu.com/security/CVE-2026-98432 to show 22.04 jammy `linux` as **Released (5.15.0-203.213)**, with a USN. As of 2026-11-08 it still says "Vulnerable, work in progress in 5.15.0-203.213". 203.213 is in `jammy-updates` but not yet `jammy-security`.
    - Then:
        - Confirm `uname -r` is `5.15.0-203-generic` or later.
        - Router (EdgeMAX > Port Forwarding): set 30303 and 9000 back to `Both`, Apply.
        - Host: `sudo ufw allow 30303/tcp` and `sudo ufw allow 9000/tcp`, then `sudo ufw status`.
- [ ] After the next block proposal, check https://beaconcha.in/validator/490968 for an MEV tag and a non-zero execution reward. If it fell back to a local block again, `journalctl -u mev-boost | grep -iE 'getHeader|bid'` shows which relays answered and how long they took. Background: https://github.com/eliotstock/stake/issues/1 (reviewed 2026-11-08; this is the only item left).
