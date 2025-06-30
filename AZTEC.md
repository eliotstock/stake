# Aztec (WiP)

Rough notes on setting up a separate machine as an Aztec sequencer node. These assume you've built a machine following the [README.md](README.md) for Ethereum nodes, but without any client software. They're additive to Aztec's own docs [here](https://docs.aztec.network/the_aztec_network/guides/run_nodes/how_to_run_sequencer).

1. Like all L2s, your node needs an L1 RPC endpoint. But unlike other L2s, you'll need the consensus layer client endpoint, not just the execution layer client endpoint. The request volume from the Aztec node to your L1 RPC provider is over the free quota for Quicknode and dRPC. You're best to run a Sepolia L1 node yourself. Set that up first.
    1. Sadly, Nethermind is not yet working well with Aztec. I used `geth` and Lighthouse.
    1. The Lighthouse setup is covered in the L1 [README.md](README.md), but you don't need a validator client, only a beacon node, because there's no staking.
    1. For `reth` I just followed my nose in their docs [here](https://reth.rs/installation/overview).
1. Ubuntu 22.04 uses a snap for docker by default. The done thing is to rip it out and use the proper package.
    1. `sudo snap stop docker --disable`
    1. `sudo snap remove docker`
1. Follow the Docker docs at https://docs.docker.com/engine/install/ubuntu/
    1. Use the "Install using the apt repository" option.
    1. You don't need the "postinstall" stuff - the package already created the `docker` group and added you to it. That allows you to run docker without sudo.
1. Now you can resume from Aztec's docs (link above).
1. Even on Sepolia and even with snapshots, sync'ing can take > 12 hours. To check the health of both EL and Cl clients for RPC calls:
```
bash <(curl -Ls https://raw.githubusercontent.com/DeepPatel2412/Aztec-Tools/main/RPC%20Health%20Check)
```
or:
```
curl -X POST -H "Content-Type: application/json" -d '{"method":"eth_call","params":[{"data":"0x289b3c0d","to":"0x4d2cc1d5fb6be65240e0bfc8154243e69c0fb19e"},"latest"]}' http://localhost:8545
```
1. To be cont.
