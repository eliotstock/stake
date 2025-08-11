# Starknet

Rough notes on setting up a separate machine as a Starknet validator. These assume you've built a machine following the [README.md](README.md) for Ethereum nodes, but without any client software.

1. `sudo apt install git gcc make tmux lsof`
1. You'll need a Rust toolchain. See https://www.rust-lang.org/tools/install.
1. Follow the Pathfinder docs, using the [Building From Source](https://eqlabs.github.io/pathfinder/getting-started/running-pathfinder#building-from-source) approach.
    1. Put the working directory in `/data/starknet/pathfinder/r/pathfinder`
    1. `nano /data/starknet/pathfinder/r/pathfinder/.env`:
    ```
    PATHFINDER_NETWORK=mainnet
    PATHFINDER_DATA_DIRECTORY=/data/starknet/pathfinder/data
    PATHFINDER_ETHEREUM_API_URL=ws://192.168.20.51:8545
    PATHFINDER_RPC_ROOT_VERSION=v08
    ```
    1. `nano /data/starknet/pathfinder/r/pathfinder/run.sh`:
    ```
    export $(grep -v '^#' .env | xargs) && cargo run --release --bin pathfinder
    ```
1. Do the same for the validator attestation process, [here](https://github.com/eqlabs/starknet-validator-attestation).
    1. Put the working directory in `/data/starknet/pathfinder/r/starknet-validator-attestation`
    1. `nano /data/starknet/pathfinder/r/starknet-validator-attestation/.env`:
    ```
    VALIDATOR_ATTESTATION_STARKNET_NODE_URL=http://127.0.0.1:9545/rpc/v0_8
    VALIDATOR_ATTESTATION_STAKER_OPERATIONAL_ADDRESS=[YOUR ADDR]
    VALIDATOR_ATTESTATION_OPERATIONAL_PRIVATE_KEY=[YOUR PRIVATE KEY]
    RUST_LOG=info
    ```
    1. `nano /data/starknet/pathfinder/r/starknet-validator-attestation/run.sh`:
    ```
    export $(grep -v '^#' .env | xargs) && cargo run --release --bin starknet-validator-attestation -- --local-signer
    ```

## Upgrades

1. Pathfinder
    1. Go to the repo (https://github.com/eqlabs/pathfinder) and find the tag for the latest release.
    1. cd `/data/starknet/pathfinder/r/pathfinder`
    1. `git fetch origin`
    1. `git checkout [tag]`
    1. `ps -a` and spot the process for `pathfinder`, then `kill [PID]`
    1. In a `tmux` session, run `/data/starknet/pathfinder/r/pathfinder/run.sh`
1. Do the same for the validator attestation process repo (https://github.com/eqlabs/starknet-validator-attestation).

## Obsolete notes for Juno

1. Don't use the Ubuntu APK for `golang` - it's not recent enough.
    1. `sudo apt remove golang-1.18 golang-1.18-doc golang-1.18-go golang-1.18-src golang-doc golang-go golang-src`
    1. Grab the tarball URL from https://go.dev/dl/
    1. `wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz` (for example)
    1. Follow instructions at https://go.dev/doc/install
1. `cd && git clone https://github.com/NethermindEth/juno.git && cd juno`
1. `make juno`
1. Grab the latest snapshot URL from https://github.com/NethermindEth/juno, `wget` it onto the node and extract it to `/data/juno/mainnet`.
1. Get your local Ethereum node running, sync'ed and with the RPC interface up. Take a note of the IP and port for RPC, eg. `ws://192.168.20.41:8545`.
1. Open a `tmux` session so you can continue execution after you disconnect ssh.
1. Run Juno with:
    ```
    ./build/juno \
    --db-path /data/juno/mainnet \
    --http-port 6060 \
    --eth-node ws://192.168.20.51:8545 \
    --log-level DEBUG
    ```
1. To run with p2p sync (as of 2024-09), get a Sepolia snapshot and add:
    ```
    --network=sepolia \
    --p2p \
    --p2p-peers=/ip4/35.231.95.227/tcp/7777/p2p/12D3KooWNKz9BJmyWVFUnod6SQYLG4dYZNhs3GrMpiot63Y1DLYS
    ```
1. If you can't build juno, you can fall back on running it as a container:
    ```
    docker run -d \
    --name juno \
    -p 6060:6060 \
    -v /data/juno/mainnet:/var/lib/juno \
    nethermind/juno \
    --http \
    --http-port 6060 \
    --http-host 0.0.0.0 \
    --db-path /var/lib/juno \
    --eth-node ws://192.168.20.51:8545
    ```
1. Your RPC node is now available (even without waiting for sync to complete) on, eg. `http://192.168.20.53:6060`. You can test this with:
    ```
    curl --location 'http://192.168.20.53:6060' \
    --data '{
        "jsonrpc":"2.0",
        "method":"starknet_blockNumber",
        "id":1
    }'
    ```
1. Note that there are no log files yet. All logging simply goes to the console.
1. Configure the firewall
    1. Confirm `ufw` is installed: `which ufw`
    1. Run these:
    ```
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp comment 'ssh'
    sudo ufw allow out from any to any port 123 comment 'ntp'
    sudo ufw allow 6060 comment 'juno http'
    sudo ufw allow 6061 comment 'juno ws'
    sudo ufw enable
    ```
    1. Note that `http` and `https` are absent above.
    1. Check which ports are accessible with `sudo ufw status`
    1. `sudo ufw reload`
1. Upgrades
    1. Pathfinder
        1. Go to the repo (https://github.com/eqlabs/pathfinder) and find the tag for the latest release.
        1. cd `/data/starknet/pathfinder/r/pathfinder`
        1. `git fetch origin`
        1. `git checkout [tag]`

    1. `cd ~/juno`
    1. `git pull origin main` (or a release tag)
    1. `rustup update`
    1. Check https://go.dev/dl/ for the latest golang version.
    1. `wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz` (for example)
    1. Follow instructions at https://go.dev/doc/install
    1. `make juno`
    1. `tmux attach`
    1. `Ctrl-C` to kill the process
    1. Run the same command line as before the upgrade.
