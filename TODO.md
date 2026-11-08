# TODO

- [ ] After the next block proposal, check https://beaconcha.in/validator/490968 for an MEV tag and a non-zero execution reward. If it fell back to a local block again, `journalctl -u mev-boost | grep -iE 'getHeader|bid'` shows which relays answered and how long they took. Background: https://github.com/eliotstock/stake/issues/1 (reviewed 2026-11-08; this is the only item left).
