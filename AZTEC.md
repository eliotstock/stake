# Aztec (WiP)

Rough notes on setting up a separate machine as an Aztec sequencer node. These assume you've built a machine following the [README.md](README.md) for Ethereum nodes, but without any client software. They're additive to Aztec's own docs [here](https://docs.aztec.network/the_aztec_network/guides/run_nodes/how_to_run_sequencer).

These docs don't mention that there is no chance in hell of getting your node registered using `aztec add-l1-validator` atm (2025-07). Instead you have to be running over the next snapshot and keep watching Discord for when that snapshot is taken. See the `apprentice | annocunements` channel.

1. Like all L2s, your node needs an L1 RPC endpoint. But unlike other L2s, you'll need the consensus layer client endpoint, not just the execution layer client endpoint. The request volume from the Aztec node to your L1 RPC provider is over the free quota for Quicknode and dRPC. You're best to run a Sepolia L1 node yourself. Set that up first.
    1. Sadly, Nethermind is not yet working well with Aztec. I used `reth` and Lighthouse.
    1. The Lighthouse setup is covered in the L1 [README.md](README.md), but you don't need a validator client, only a beacon node, because there's no staking.
    1. For `reth` I just followed my nose in their docs [here](https://reth.rs/installation/overview). I ended up with this as a run script at `/data/reth/sepolia/run.sh`:
```
reth node \
  --chain sepolia \
  --datadir /data/reth/sepolia \
  --authrpc.jwtsecret /data/jwtsecret \
  --authrpc.addr 127.0.0.1 \
  --authrpc.port 8551 \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --metrics 127.0.0.1:9001
```
1. Ubuntu 22.04 uses a snap for docker by default. The done thing is to rip it out and use the proper package.
    1. `sudo snap stop docker --disable`
    1. `sudo snap remove docker`
1. Follow the Docker docs at https://docs.docker.com/engine/install/ubuntu/
    1. Use the "Install using the apt repository" option.
    1. You don't need the "postinstall" stuff - the package already created the `docker` group and added you to it. That allows you to run docker without sudo.
1. Now you can resume from Aztec's docs (link above).
1. Even on Sepolia and even with snapshots, sync'ing can take a few days. To check the health of both EL and Cl clients for RPC calls:
```
bash <(curl -Ls https://raw.githubusercontent.com/DeepPatel2412/Aztec-Tools/main/RPC%20Health%20Check)
```
(but make sure you have `jq` installed first), or:
```
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"data":"0x289b3c0d","to":"0x4d2cc1d5fb6be65240e0bfc8154243e69c0fb19e"},"latest"],"id":1}' \
  http://localhost:8545
```
or even just:
```
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545
```
1. My endpoints ended up at:
    1. Enter Execution RPC URL: http://192.168.20.52:8545
    1. Enter Beacon RPC URL: http://192.168.20.52:5052
1. I could not get the process inside the docker container to see the network using the docs as provided. Instead I had to use "host networking". This meant not using the `aztec start` command and instead calling `docker run` directly. Here's my `run.sh`:

```
# Running this outside of the user's home dir fails with an error
cd $HOME
source /data/aztec/.env

LOG_FILE="/data/aztec/logs/sequencer_$(date +%Y%m%d).log"

# Use host networking to allow container to access host services
export SKIP_NET=1

while true; do
    echo "Attempting to start node at $(date)..." | tee -a "$LOG_FILE"

    docker run --rm --network host \
      -v $HOME:$HOME \
      -v /data/aztec/data:/home/e/.aztec \
      -v cache:/cache \
      --workdir "$PWD" \
      -e HOME="$HOME" \
      -e ETHEREUM_HOSTS="$ETHEREUM_HOSTS" \
      -e L1_CONSENSUS_HOST_URLS="$L1_CONSENSUS_HOST_URLS" \
      -e VALIDATOR_PRIVATE_KEY="$VALIDATOR_PRIVATE_KEY" \
      -e COINBASE="$COINBASE" \
      -e P2P_IP="$P2P_IP" \
      --entrypoint "" \
      aztecprotocol/aztec:latest \
      node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --node --archiver --sequencer \
        --network alpha-testnet \
        --l1-rpc-urls "$ETHEREUM_HOSTS" \
        --l1-consensus-host-urls "$L1_CONSENSUS_HOST_URLS" \
        --sequencer.validatorPrivateKey "$VALIDATOR_PRIVATE_KEY" \
        --sequencer.coinbase "$COINBASE" \
        --p2p.p2pIp "$P2P_IP"

    echo "Aztec node exited at $(date). Restarting in 5 seconds..." | tee -a "$LOG_FILE"
    sleep 5
done
```
1. Make yourself an `.env` file with all the env vars in it at `/data/aztec/.env`
1. Create the `/data/aztec/logs` directory too.
1. Finally, run all three processes inside `tmux` so it continues to run after you hang up your `ssh` session:
  1. `/data/reth/sepolia/run.sh`
  1. `sudo systemctl start lighthouse-bn.service && journalctl -u lighthouse-bn -f`
  1. `/data/aztec/run.sh`
