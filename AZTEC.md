# Aztec

Rough notes on setting up a separate machine as an Aztec sequencer node. These assume you've built a machine following the [README.md](README.md) for Ethereum nodes, but without any client software. They're additive to Aztec's own docs [here](https://docs.aztec.network/the_aztec_network/guides/run_nodes/how_to_run_sequencer).

1. Ubuntu 22.04 uses a snap for docker by default. The done thing is to rip it out and use the proper package.
    1. `sudo snap stop docker --disable`
    1. `sudo snap remove docker`
1. Follow the Docker docs at https://docs.docker.com/engine/install/ubuntu/
    1. Use the "Install using the apt repository" option.
    1. You don't need the "postinstall" stuff - the package already created the `docker` group and added you to it. That allows you to run docker without sudo.
1. Now you can resume from Aztec's docs (link above).
