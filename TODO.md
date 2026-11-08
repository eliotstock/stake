# TODO

- [ ] Re-open inbound TCP for the clients. CVE-2026-98432 is fixed in the kernel that's running; only the router and `ufw` changes remain.
    - Background: Linux kernel IPv4 TCP use-after-free (CVSS 9.8), remotely reachable via any listening TCP port. Since 2026-10-30 inbound TCP on 30303 and 9000 has been closed on both the router (port forwards set to UDP only) and `ufw` (TCP allow rules removed). Clients still peer via outbound TCP and UDP discovery.
    - Confirmed 2026-11-08: the node runs `5.15.0-203-generic` (5.15.0-203.213, rebooted 2026-11-07). Its changelog (`zcat /usr/share/doc/linux-modules-5.15.0-203-generic/changelog.Debian.gz`) includes the upstream fix for this CVE, "ipv4: free inet_opt and ireq_opt after an RCU grace period", pulled in with the v5.15.223 stable update. https://ubuntu.com/security/CVE-2026-98432 still says "work in progress in 5.15.0-203.213" because 203.213 shipped through `jammy-updates` and the tracker only flips to Released when a USN goes out; the code is the same either way.
    - To do:
        - Router (EdgeMAX > Port Forwarding): set 30303 and 9000 back to `Both`, Apply.
        - Host: `sudo ufw allow 30303/tcp` and `sudo ufw allow 9000/tcp`, then `sudo ufw status`.
        - After a few minutes, confirm inbound TCP peers are back: `ss -Htn4 state established '( sport = :9000 or sport = :30303 )'`.
- [ ] After the next block proposal, check https://beaconcha.in/validator/490968 for an MEV tag and a non-zero execution reward. If it fell back to a local block again, `journalctl -u mev-boost | grep -iE 'getHeader|bid'` shows which relays answered and how long they took. Background: https://github.com/eliotstock/stake/issues/1 (reviewed 2026-11-08; this is the only item left).
