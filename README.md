# How to build an Ethereum staking machine

These instructions are up to date wrt the following releases.

* `nethermind` 1.37.1
* `lighthouse` 8.1.3
* `mev-boost` 1.12

You'll need to be comfortable with Linux. The goal here is to gain an understanding of how each node process is configured directly so we're not using any higher level containerisation stuff.

Before you start:

1. (Optional) Update the firmware in your router, factory reset, and reconfigure, out of an abundance of caution.
1. Figure out some stuff up front:
    1. Hostname: replace `node01` below with this.
    1. Username on the host: replace `[username]` below with this.
    1. Static IP address: replace `192.168.20.51` below with this.
    1. SSH port to open up: replace `60001` below with this.

## Hardware and OS install

First decide between Intel and ARM for your hardware. If you want a quiet, fanless machine, choose ARM, but beware the issues I had below with the Radxa Rock 5B.

Only buy the big drive after reading this awesome ["hall of blame"](https://gist.github.com/yorickdowne/f3a3e79a573bf35767cd002cc977b038) Gist.

### Intel

1. Grab an Intel NUC. Specs for mine:
    1. i5-1135G7, 4 cores. Only two slots (one M.2, one 2.5" SATA)
    1. 32 GB RAM (but 16GB is fine)
    1. One 4 TB NVMe M.2 drive holding both the OS and the chain data, as two LVM logical volumes (100 GB for `/`, the rest for `/data`). See "Set up the data volume" below.
    1. Previously this machine had a Samsung 980 250 GB M.2 for the OS plus a Crucial BX500 2 TB 2.5" SATA SSD for data. The SATA drive took about 30 hours to sync and was the bottleneck for everything. Don't do that. The speed of the data drive affects performance and re-sync time more than anything else.
1. Set the machine to restart after a power failure.
    1. `F2` during boot to get into BIOS settings
    1. Power > Secondary power settings
    1. After power failure: Power on
    1. `F10` to save and exit
1. Install Ubuntu Server 24.04 LTS
    1. F10 on boot to boot from USB for Intel NUC
    1. `Ubuntu Server (minimized)`
    1. Check ethernet interface(s) have a connection, use DHCP for now
    1. Use an entire disk, set it up as an LVM group, no need to encrypt. The installer creates a 100 GB root logical volume and leaves the rest of the volume group unallocated. We'll turn that into `/data` below. (If you have a separate data drive, pick the OS drive here.)
    1. Take photo of file system summary screen during installation
    1. Hostname: `node01`. Set a username.
    1. Install OpenSSH server.
    1. Import SSH identity: yes, GitHub, don’t allow password auth over SSH
    1. Use your SSH public key from GitHub
    1. No extra snaps
    1. Finish installation and reboot
1. Disable `cloud-init`
    1. `sudo touch /etc/cloud/cloud-init.disabled`
    1. `sudo reboot`
    1. Make sure you can still log in as your new user.
    1. `sudo dpkg-reconfigure cloud-init` and choose`none of the above`.
    1. `sudo apt-get purge cloud-init`
    1. `sudo rm -rf /etc/cloud/ && sudo rm -rf /var/lib/cloud/`
    1. `sudo reboot`
    1. Again, make sure you can still log in as your new user.

### ARM

1. Grab a Radxa Rock 5B board and parts. Specs for mine:
    1. 16 GB RAM
    1. Small drive (OS) is a 64 GB eMMC
    1. Big drive (data) is a Crucial P3 Plus PCIe 4.0 NVMe M.2 2280. Do NOT get an NVMe drive with a massive heat sink on it, cause it won't fit. Clearance is limited between the bottom of the board and the case.
        1. This drive claims "Up to 4,800MB/s Read - Up to 4,100MB/s Write" on the box.
        1. But hewre's the `fio` output (see below for the command line used)
        ```
        READ: bw=316MiB/s (331MB/s), 316MiB/s-316MiB/s (331MB/s-331MB/s), io=3070MiB (3219MB), run=9722-9722msec
        WRITE: bw=106MiB/s (111MB/s), 106MiB/s-106MiB/s (111MB/s-111MB/s), io=1026MiB (1076MB), run=9722-9722msec

        ```
    1. Get the Radxa case/heatsink. No need for a fan.
    1. Get the eMMC to USB adapter for flashing the eMMC from the host machine.
1. There is no BIOS!
    1. ARM boards are not PCs and do not have a BIOS. Don't bother connecting a keyboard and monitor if you don't plan to use one long term.
    1. The board powers on again if it ever loses power, so, nothing to set up there.
    1. To shut it down and have it stay off, use `sudo poweroff`. If you use `sudo shutdown -r now` it will just reboot.
    1. The RTC is managed from some binaries - see below.
1. Flash the OS to the MMC.
    1. Download the latest Ubuntu image from Radxa's [releases](https://github.com/radxa-build/rock-5b/releases) repo. It'll be something like `rock-5b_ubuntu_jammy_cli_b36.img.xz`.
    1. Note that this is NOT an installer image, it's the actual OS that you're going to run.
    1. Make sure you can uncompress `xz` files: `sudo apt install xz-utils`
    1. `unxz rock-5b_ubuntu_jammy_cli_b36.img.xz`
    1. Plug the USB adapter in and find out what `sd*` device it got with `sudo dmesg | tail -20`. Mine was `sda`.
    1. Write the image with `sudo dd if=./rock-5b_ubuntu_jammy_cli_b36.img of=/dev/sda bs=1M`
    1. `sudo umount /dev/sda`
    1. Remove the USB adapter, take the little eMMC module off it and stick it on the underside of the board.
    1. Connect the ethernet and USB cables and the board should power on. It seems OK to run it without the heatsink briefly. The LED should go green, then blue.
    1. Watch the web interface of your router for the machine joining the LAN. Grab the IP address. Mine was `192.168.20.51`. You might instead be able to use `rock-5b.local` if your router creates it.
    1. SSH in: `ssh rock@192.168.20.51`, password: `rock`
    1. Check the OS version is what you expect: `lsb_release -a`
    1. Create a new user: `sudo adduser [username]`. Set the password.
    1. Add the user to the group that can be root: `sudo adduser [username] sudo`
    1. Disconnect from SSH as `rock` and reconnect as your new user
    1. Remove the existing `rock` user: `sudo deluser rock`
    1. Change the hostname. Mine is `node01`.
        1. `sudo nano /etc/hostname` and change
        1. `sudo nano /etc/hosts` and change
    1. Get network time working
        1. `sudo nano /etc/systemd/timesyncd.conf`
        1. Add `time.google.com`
        1. `sudo timedatectl set-ntp true`
        1. `systemctl restart systemd-timesyncd`
        1. Check time with `timedatectl status` and check for `System clock synchronized: yes`
        1. TODO: Not working. Fix.

## OS setup

1. Switch to SSH-ing in from another machine now, for ease of copy/pasting stuff from this guide.
    1. Grab the IP address from the router.
    1. `ssh [username]@[ip]`
    1. If you restored your GitHub SSH key during installation and you have it on your local machine, you should be straight in.
1. Update packages and get some stuff we're going to need below.
    1. `sudo apt update`
    1. `sudo apt upgrade` (make coffee)
    1. Agree to restarting all the suggested services.
    1. `sudo apt install nano unzip net-tools netplan.io ufw fail2ban parted fio ccze smartmontools speedtest-cli`
1. Configure a static IP address.
    1. Get the interface name for the Ethernet: `ip link`. Mine was `enP4p65s0` on the ARM board, `enp88s0` on the Intel NUC.
    1. Figure out whether you're using `netplan` or `NetworkManager`. If both are installed you might have `/etc/netplan/something.yaml` simply delegating to `NetworkManager` with `renderer: NetworkManager`. The below assumes you want to use `netplan`.
    1. Paste the below block into a new `netplan` config file: `sudo nano /etc/netplan/01-config.yaml`.
    ```
    network:
      version: 2
      renderer: networkd
      ethernets:
          enp88s0:
              dhcp4: no
              addresses:
                  - 192.168.20.51/24
              routes:
                  - to: default
                    via: 192.168.20.1
              nameservers:
                  addresses: [8.8.8.8, 1.1.1.1, 1.0.0.1]
    ```
    1. `.yaml` files use spaces for indentation (either 2 or 4), not tabs.
    1. A subnet mask of `/24` means only the last octet (8 bits) in the address changes for each device on the subnet.
    1. The DNS servers here are Google's and Cloudflare's.
    1. You might also consider using 9.9.9.9 (Quad9, does filtering of known malware sites).
    1. `sudo chmod 600 /etc/netplan/01-config.yaml`
    1. `sudo netplan try` to check your config file.
    1. `sudo netplan apply`. You'll lose your SSH connection at this point.
    1. Try to SSH in on the new IP. Then confirm it's changed with `ip a`.
1. Tighten up ssh
    1. `sudo nano /etc/ssh/sshd_config`
    1. Change the ssh port from the default. Uncomment the `Port` line. Pick a memorable port number, eg. 60001, and make a note of it.
    1. Only allow ssh'ing in using a key from now on. Set `PasswordAuthentication no`.
    1. On Ubuntu 22.10 and later (so 24.04 on the NUC, but not the 22.04-based Radxa image), `sshd_config`'s `Port` is ignored because `systemd` listens on port 22 itself via `ssh.socket` ("socket activation"). Change the socket too:
    1. `sudo mkdir /etc/systemd/system/ssh.socket.d`
    1. `sudo nano /etc/systemd/system/ssh.socket.d/port.conf` and put:
    ```
    [Socket]
    ListenStream=
    ListenStream=60001
    ```
    1. Reboot and reconnect, but this time use the `-p 60001` arg for `ssh`.
1. Configure the firewall
    1. Confirm `ufw` is installed: `which ufw`
    1. Run these:
    ```
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 60001/tcp comment 'ssh'
    sudo ufw allow out from any to any port 123 comment 'ntp'
    sudo ufw allow 30303 comment 'execution client'
    sudo ufw allow 9000 comment 'consensus client'
    sudo ufw allow 8545/tcp comment 'execution client health'
    sudo ufw allow 8551/tcp comment 'execution client health'
    sudo ufw enable
    ```
    1. Note that `http` and `https` are absent above.
    1. Check which ports are accessible with `sudo ufw status`
    1. Also block pings: `sudo nano /etc/ufw/before.rules`, find the line reading `A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT` and change `ACCEPT` to `DROP`
    1. `sudo ufw reload`
1. Make sure that `unattended-updates` works for more than just security updates and includes non-Ubuntu PPAs.
    1. On ARM only, `sudo touch /etc/apt/apt.conf.d/50unattended-upgrades` first because this won't exist.
    1. `sudo nano /etc/apt/apt.conf.d/50unattended-upgrades`
    1. Add this anywhere:
    ```
    // Allow non-Ubuntu PPAs
    Unattended-Upgrade::Origins-Pattern {
        "o=*";
    };
    ```
1. (Optional and only required if you didn't restore SSH keys from GitHub during installation) Set up ssh keys for all client machines from which you'll want to connect.
    1. If re-installing, restore the `~/.ssh/authorized_keys` file you backed up earlier, using `scp`.
        1. Try connecting using `ssh` first
        1. You'll get an error about the host key changing, including a command to run to forget the old host key. Run it.
        1. Now do the `scp` copy: `scp -P 60001 ./authorized_keys [username]@[ip]:/home/[username]/.ssh/authorized_keys`
    1. Otherwise:
        1. You might like to set an alias in `~/.bashrc` such as `alias <random-name>="ssh -p 60001 [username]@[server IP]"`
        1. Similarly for scp: `alias <random-name>="scp -P 60001 $1 [username]@[server IP]:/home/[username]"`
        1. `ssh-keygen -t rsa -b 4096 -C "[client nickname]"`
        1. No passphrase.
        1. Accept the default path. You'll get both `~/.ssh/id_rsa.pub` (public key) and `~/.ssh/id_rsa` (private key).
        1. Copy the public key to the server: `scp -P 60001 ~/.ssh/id_rsa.pub [username]@[server IP]:/home/[username]/.ssh/authorized_keys`
        1. Verify the file is there on the server.
        1. Verify you can ssh in to the server and you're not prompted for a password. Use the alias you created earlier.
1. Ban any IP address that has multiple failed login attempts using `fail2ban`
    1. In order for `fail2ban` to work, the `sshd` service needs to be running, not just the "socket activated" version.
        1. `sudo systemctl enable ssh.service` (Note the `ssh` here, NOT `sshd`)
        1. `sudo systemctl start ssh.service`
    1. Jail settings go in `jail.local`, not `fail2ban.local` (that file configures the daemon itself and ignores jail sections). `sudo nano /etc/fail2ban/jail.local` and add:
    ```
    [sshd]
    enabled = true
    port = 60001
    filter = sshd
    backend = systemd
    maxretry = 3
    bantime = -1
    ```
    1. `backend = systemd` reads from the journal, so this works on the Radxa image too, which has no `/var/log/auth.log`.
    1. `sudo systemctl enable fail2ban.service`
    1. `sudo systemctl start fail2ban.service`
    1. Make a note to come back periodically and check for any banned IPs with `sudo fail2ban-client status sshd`
1. Set up the data volume. Two options depending on your hardware.
    1. **Option A: one big drive, OS and data on the same disk (what I run now).** The installer left most of the volume group free. Carve it into a logical volume for `/data`:
        1. `sudo vgs` and confirm `ubuntu-vg` has most of the disk in `VFree`.
        1. `sudo lvcreate -l 100%FREE -n data ubuntu-vg`
        1. `sudo mkfs -t ext4 /dev/ubuntu-vg/data`
        1. `sudo nano /etc/fstab` and add `/dev/mapper/ubuntu--vg-data /data ext4 defaults 0 2`
            1. The `0` here means the `dump` backup program should skip the volume and the `2` is the order in which `fsck` will check it. Note the double dashes in the mapper name: LVM escapes the `-` in `ubuntu-vg` that way.
        1. `lsblk` should now show `ubuntu--vg-data` under the NVMe partition alongside `ubuntu--vg-ubuntu--lv`.
    1. **Option B: a separate data drive.**
        1. `lsblk` and confirm the drive isn't mounted yet. It might be called `sda` or `nvme1n1`.
        1. `sudo parted --list` and confirm it's not partitioned yet.
        1. Give it a GPT label and one partition using the whole disk. GPT works for any size, so no need for `fdisk`:
            1. `sudo parted /dev/sda`
            1. `mklabel gpt`
            1. `mkpart primary ext4 0% 100%`
            1. `quit`
        1. Format the partition (note the `1`: the partition, not the whole disk): `sudo mkfs -t ext4 /dev/sda1` (or `/dev/nvme1n1p1`)
        1. Get the UUID for the partition from `sudo blkid`
        1. `sudo nano /etc/fstab` and add `UUID=YOUR_PARTITION_UUID /data ext4 defaults 0 2`
    1. Either way, then:
        1. `sudo mkdir /data`, `sudo mount -a` and confirm it's mounted with `ls -lah /data`
        1. Make it writable by your user with `sudo chown -R [username]:[username] /data`
        1. `df -H` and confirm it's there and mostly free space
        1. Reboot and make sure it mounts again
1. Check for firmware updates for the drive
    1. `sudo smartctl -a /dev/nvme0n1` and get the current firmware version.
    1. Do some Googling and figure out if there's an update you need.
1. Test the performance of the data drive
    1. `cd /data`
    1. `sudo fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=150G --readwrite=randrw --rwmixread=75`
    1. Output is explained [here](https://tobert.github.io/post/2014-04-17-fio-output-explained.html)
    1. Here's what I got with a `Crucial P3 Plus NVMe M.2`. The pertinent bit is _137k IOPS for read and 45.2k IOPS for write_
```
test: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=64
fio-3.28
Starting 1 process
test: Laying out IO file (1 file / 153600MiB)
Jobs: 1 (f=1): [m(1)][100.0%][r=535MiB/s,w=177MiB/s][r=137k,w=45.2k IOPS][eta 00m:00s]
test: (groupid=0, jobs=1): err= 0: pid=1538: Wed Apr 24 11:28:31 2024
  read: IOPS=55.5k, BW=217MiB/s (227MB/s)(113GiB/531276msec)
   bw (  KiB/s): min=148360, max=631704, per=99.93%, avg=221899.05, stdev=27043.69, samples=1062
   iops        : min=37090, max=157926, avg=55474.71, stdev=6760.91, samples=1062
  write: IOPS=18.5k, BW=72.3MiB/s (75.8MB/s)(37.5GiB/531276msec); 0 zone resets
   bw (  KiB/s): min=50416, max=207504, per=99.93%, avg=73954.19, stdev=9002.97, samples=1062
   iops        : min=12604, max=51876, avg=18488.48, stdev=2250.73, samples=1062
  cpu          : usr=5.60%, sys=17.07%, ctx=21177496, majf=2, minf=6
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=29492326,9829274,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=217MiB/s (227MB/s), 217MiB/s-217MiB/s (227MB/s-227MB/s), io=113GiB (121GB), run=531276-531276msec
  WRITE: bw=72.3MiB/s (75.8MB/s), 72.3MiB/s-72.3MiB/s (75.8MB/s-75.8MB/s), io=37.5GiB (40.3GB), run=531276-531276msec

Disk stats (read/write):
    dm-1: ios=29446674/9827674, merge=0/0, ticks=32826092/970688, in_queue=33796780, util=99.92%, aggrios=29492341/9842875, aggrmerge=0/259, aggrticks=32827649/1050440, aggrin_queue=33878550, aggrutil=99.91%
  nvme0n1: ios=29492341/9842875, merge=0/259, ticks=32827649/1050440, in_queue=33878550, util=99.91%
```
<!-- 1. (Optional) Configure git user. Cache the personal access token from Github for one week.
    1. `git config --global user.email "foo@example.com"`
    1. `git config --global user.name "Your Name"`
    1. `git config --global credential.helper cache`
    1. `git config --global credential.helper 'cache --timeout=604800'`
    1. Assuming your Github user auth is configured like mine, copy your personal access token to the clipboard and `ssh` into the host
    1. Pull any repos you might need: `git clone [repo's https url] [repo dir]`
    1. From inside each repo working directory: `git config pull.rebase false` -->
1. Forward ports from the router to the host:
    1. Any execution client: 30303 (both TCP and UDP)
    1. Lighthouse (consensus client): 9000 (both TCP and UDP)
    1. Only while travelling, SSH: 60001 TCP

## Clients

### JWT token

1. Generate a JWT token to be used by the clients:
    1. `openssl rand -hex 32 | tr -d "\n" > "/data/jwtsecret"`
    1. This file needs to be readable by both the `nethermind` user and the `lighthouse-bn` user, so leave it as world readable.

### Nethermind (execution layer client)

1. Add the PPA and install the package. See Nethermind's [docs](https://docs.nethermind.io/get-started/installing-nethermind#package-managers).
1. Create a directory for the Rocks DBs and logs: `mkdir /data/nethermind`
1. Create a `nethermind` user but do NOT create a home directory and this user should never log in, so they should not have a shell: `sudo useradd -M -s /bin/false nethermind`
<!-- 1. Make a copy of the default mainnet config file to allow for any changes:
    1. `sudo /usr/share/nethermind/configs/mainnet.cfg /data/nethermind/local.cfg`
    1. `sudo chown nethermind:nethermind /data/nethermind/local.cfg`
    1. Edit the file and add under `JsonRpc`:
    ```
    "EnabledModules": [
        ["Eth", "Subscribe", "Trace", "TxPool", "Web3", "Personal", "Proof", "Net", "Parity", "Health", "Rpc", "Admin"]
    ],
    "EngineEnabledModules": [
        ["Net", "Eth", "Subscribe", "Web3"]
    ]
    ``` -->
1. Create a `systemd` unit file as follows `sudo nano /etc/systemd/system/nethermind.service`:
```
[Unit]
Description=Nethermind Ethereum Client
After=network.target
Wants=network.target

[Service]
User=nethermind
Group=nethermind
Type=simple
Restart=always
RestartSec=5
TimeoutStopSec=180
WorkingDirectory=/data/nethermind
EnvironmentFile=/data/nethermind/.env
ExecStart=nethermind \
    --datadir /data/nethermind \
    --config mainnet

[Install]
WantedBy=default.target
```
1. Create an `.env` file as follows `nano /data/nethermind/.env`:
```
DOTNET_BUNDLE_EXTRACT_BASE_DIR = /data/nethermind
NETHERMIND_JSONRPCCONFIG_ENABLED = true
NETHERMIND_JSONRPCCONFIG_JWTSECRETFILE = /data/jwtsecret
NETHERMIND_JSONRPCCONFIG_HOST = 0.0.0.0
NETHERMIND_JSONRPCCONFIG_PORT = 8545
NETHERMIND_JSONRPCCONFIG_ENGINEHOST = 0.0.0.0
NETHERMIND_JSONRPCCONFIG_ENGINEPORT = 8551
NETHERMIND_JSONRPCCONFIG_ENABLEDMODULES = [Eth, Subscribe, Trace, TxPool, Web3, Personal, Proof, Net, Parity, Health, Rpc, Admin]
NETHERMIND_JSONRPCCONFIG_ENGINEENABLEDMODULES = [Net, Eth, Subscribe, Web3]
NETHERMIND_HEALTHCHECKSCONFIG_ENABLED = true
NETHERMIND_HEALTHCHECKSCONFIG_UIENABLED = true
NETHERMIND_PRUNINGCONFIG_CACHEMB=2048
NETHERMIND_JSONRPCCONFIG_ADDITIONALRPCURLS = [http://127.0.0.1:8555|http|admin]
```
1. Make `nethermind` own the file: `sudo chown nethermind /data/nethermind/.env`
1. Change ownership of all data and logs to the `nethermind` user:
    1. `sudo chown -R nethermind /data/nethermind`
    1. `sudo chown -R nethermind /usr/share/nethermind`
1. Start the service and enable it on boot:
    1. `sudo systemctl daemon-reload`
    1. `sudo systemctl start nethermind.service`
    1. `sudo systemctl status nethermind.service`
    1. `sudo systemctl enable nethermind.service`
1. Follow the logs for a bit to check it's working. At this stage you have no consensus layer client running so the logs should say something about waiting for that to appear.
    1. `journalctl -u nethermind -f`
1. The (commented) config above will prune the database once the remaining space on the drive falls below 300 GB. Othwerwise pruning will be manual and you'll have to watch your disk space.
1. Once up and running, check health with:
    1. `curl http://192.168.20.51:8545/health`
    1. Or if you have a GUI and browser: http://192.168.20.51:8545/healthchecks-ui
1. To test the websockets subscriptions using `wscat`:
    1. `npm install -g wscat`
    1. `wscat -c ws://192.168.20.51:8545`
    1. `{"method":"eth_subscribe","params":["newHeads"],"id":1,"jsonrpc":"2.0"}`
    1. You should get some JSON back every block.

### Lighthouse (consensus layer client)

1. Go to https://github.com/sigp/lighthouse/releases and find the latest release. Pick the tarball for your architecture: `x86_64-unknown-linux-gnu` for the Intel NUC, `aarch64-unknown-linux-gnu` for the Rock 5B. (There's no longer a portable/non-portable split.) Download, extract and delete it on the host.
    1. `wget https://github.com/sigp/lighthouse/releases/download/v8.1.3/lighthouse-v8.1.3-x86_64-unknown-linux-gnu.tar.gz`
    1. `tar -xvf lighthouse-*.tar.gz`
    1. `rm lighthouse-*.tar.gz`
1. Make sure it runs: `./lighthouse --version`
1. Move the binary out of your home dir:
    1. `sudo mv ./lighthouse /usr/bin`
1. Create two users but do NOT create home directories for them and they should never log in, so they should not have a shell:
    1. `sudo useradd -M -s /bin/false lighthouse-bn`
    1. `sudo useradd -M -s /bin/false lighthouse-vc`
1. Create the data directories and set ownership. The beacon node owns everything under `/data/lighthouse` except the `validators` directory, which the validator client owns. Do the `bn` chown first so it doesn't clobber the `vc` one.
    ```
    sudo mkdir -p /data/lighthouse/mainnet/beacon
    sudo mkdir -p /data/lighthouse/mainnet/validators
    sudo mkdir -p /data/validator_keys
    sudo chown -R lighthouse-bn:lighthouse-bn /data/lighthouse
    sudo chown -R lighthouse-vc:lighthouse-vc /data/lighthouse/mainnet/validators
    sudo chown -R lighthouse-vc:lighthouse-vc /data/validator_keys
    ```
1. Create two `systemd` unit files as follows:
    1. `sudo nano /etc/systemd/system/lighthouse-bn.service`:
    ```
    [Unit]
    Description=Lighthouse Beacon Node
    Wants=network-online.target
    After=network-online.target

    [Service]
    Type=simple
    User=lighthouse-bn
    Group=lighthouse-bn
    Restart=always
    RestartSec=5
    ExecStart=/usr/bin/lighthouse bn \
    --network mainnet \
    --datadir /data/lighthouse/mainnet \
    --execution-endpoint http://localhost:8551 \
    --execution-jwt /data/jwtsecret \
    --http \
    --http-address 192.168.20.51 \
    --http-allow-origin "*" \
    --builder http://localhost:18550 \
    --graffiti YOUR_GRAFFITI \
    --checkpoint-sync-url https://mainnet.checkpoint.sigp.io/

    [Install]
    WantedBy=multi-user.target
    ```
    1. `sudo nano /etc/systemd/system/lighthouse-vc.service`:
    ```
    [Unit]
    Description=Lighthouse Validator Client
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=lighthouse-vc
    Group=lighthouse-vc
    Type=simple
    Restart=always
    RestartSec=5
    ExecStart=/usr/bin/lighthouse vc \
    --network mainnet \
    --datadir /data/lighthouse/mainnet \
    --beacon-nodes http://192.168.20.51:5052 \
    --builder-proposals \
    --graffiti YOUR_GRAFFITI

    [Install]
    WantedBy=multi-user.target
    ```
1. The config above assumes you want access to the Beacon Node API locally. You can use the Beacon Node API on  port `5052` but only on the local network. Do not NAT this through to the internet or you'll get DoS'ed. If you don't need this, turn it off:
    1. Omit `--http-address` and `--http-allow-origin` from the `bn` file and `--beacon-nodes http://192.168.20.51:5052` from the `vc` file if you don't need access to the Beacon Node API on your local network.
1. Note that `localhost` is correct on the `bn` file, even though the EL client used `192.168.20.51`.
1. You may wish to add `--debug-level warn` to each file later on to reduce log noise. Start with the default of `info` though.
1. Start the services and enable them on boot:
    ```
    sudo systemctl daemon-reload
    sudo systemctl start lighthouse-bn.service
    sudo systemctl status lighthouse-bn.service
    sudo systemctl enable lighthouse-bn.service
    sudo systemctl start lighthouse-vc.service
    sudo systemctl status lighthouse-vc.service
    sudo systemctl enable lighthouse-vc.service
    ```
1. Follow the logs for a bit to check it's working:
    1. `journalctl -u lighthouse-bn -f`
    1. `journalctl -u lighthouse-vc -f`

### MEV-Boost

1. There are no Ubuntu packages for MEV-Boost. Download the latest binary from https://github.com/flashbots/mev-boost/releases.
1. Extract and delete the tarball: `tar -xvf mev* && rm mev*.tar.gz`
1. Move the binary: `mv mev-boost /data`
1. Pick one or more relays to use.
    1. If you have no strong opinions about this, just use Ultra Sound:
    * `https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money`
    1. If you do, however, pick one or more from the [eth-educators list](https://github.com/eth-educators/ethstaker-guides/blob/main/MEV-relay-list.md). You also might like to check https://www.relayscan.io/.
1. Create an `mev-boost` user but do NOT create a home directory and this user should never log in, so they should not have a shell: `sudo useradd -M -s /bin/false mev-boost`
1. Create a `systemd` unit file. `sudo nano /etc/systemd/system/mev-boost.service`, then paste in the one from the repo [`README`](https://github.com/flashbots/mev-boost#systemd-configuration), except:
    1. Change the working directory to `WorkingDirectory=/data`
    1. Change the path to the binary to `ExecStart=/data/mev-boost \`
    1. Put your relay in.
1. Change ownership of the binary. This isn't strictly necessary but keeps things tidy.
    1. `sudo chown mev-boost /data/mev-boost`
    1. `sudo chgrp mev-boost /data/mev-boost`
1. Start the service and enable it on boot:
    1. `sudo systemctl daemon-reload`
    1. `sudo systemctl start mev-boost.service`
    1. `sudo systemctl status mev-boost.service`
    1. `sudo systemctl enable mev-boost.service`
1. Follow the logs for a bit to check it's working:
    1. `journalctl -u mev-boost -f`

### Initial sync

1. The first time you sync only, or if you've fallen far behind, use a checkpoint sync endpoint for the beacon node:
    1. `lighthouse --network mainnet --datadir /data/lighthouse/mainnet bn --execution-endpoint http://localhost:8551 --execution-jwt /data/jwtsecret --checkpoint-sync-url https://beaconstate.ethstaker.cc`
        1. Get the checkpoint sync URL from https://eth-clients.github.io/checkpoint-sync-endpoints/
        1. See this thread in the Lighthouse Discord for more details o checks: https://discord.com/channels/605577013327167508/605577013331361793/1019755522985050142
1. Do the key management stuff for Lighthouse: https://lighthouse-book.sigmaprime.io/key-management.html
    1. Create a password file for this network: `nano stake.pass` and `chmod 600 ./stake.pass`
    1. `lighthouse --network mainnet account wallet create --name stake --password-file stake.pass`
    1. Write down mnemonic -> sock drawer (not really obvs)
    1. `lighthouse --network mainnet account validator create --wallet-name stake --wallet-password stake.pass --count 1`
1. Take a note of how long the initial sync takes. The bottleneck for me is SSD speed. If you ever need to re-sync, you'll feel the pain of potentially missing a block proposal the longer this takes. I had to re-sync when I forgot to set any pruning command line args for NM and filled up my disk. As of NM v1.19, a re-sync took two to three days for me with the old SATA drive.
1. To dig deeper on I/O performance. `sar` and `iostat` come from `sysstat`, which isn't installed by default.
    1. `sudo apt install sysstat iotop`
    1. Find the device names: `df /data` and `lsblk`. With the single-drive LVM layout the physical disk is `nvme0n1` and the `/data` volume is `dm-1` (check: `ls -l /dev/mapper/ubuntu--vg-data`).
    1. Live view, during normal operation (not while running `fio`):
        1. `iostat -x 1 nvme0n1 dm-1`. Watch `r_await`/`w_await` (ms per request, should be under 1 ms on NVMe) and `aqu-sz` (queue depth). `%util` is less meaningful on NVMe because the drive services many requests in parallel.
        1. `vmstat 1`. The `wa` column is CPU time waiting on I/O. Sustained above ~10% is bad.
        1. `cat /proc/pressure/io`. `some avg10` is the share of the last 10 s that some task was stalled on I/O. Above 10-20 in steady state points at the disk.
    1. Who is doing the I/O. The OS shares the drive, so this matters:
        1. `sudo iotop -o -d 2`. Expect Nethermind and Lighthouse. If journald, `unattended-upgrades` or anything else shows up regularly, it's competing.
        1. `pidstat -d 2 -p $(pgrep -x nethermind)` for Nethermind alone.
    1. Catch a block being processed: `iostat -x 1 nvme0n1 | grep --line-buffered -E '^nvme0n1'` in one `tmux` pane and `journalctl -u nethermind -f` in another, and line the spikes up with the `Processed` lines.
    1. Historical data via `sar`:
        1. `sudo nano /etc/default/sysstat` and change `ENABLED="false"` to `"true"`
        1. `sudo systemctl enable --now sysstat`. It samples every 10 minutes.
        1. `sar -u` and check the `%iowait` column. `sar -d -p` for per-disk util and await.
        1. `sar -u -s 12:40:00 -e 13:00:00 -f /var/log/sysstat/sa24` for a window on a specific day of the month (here the 24th).
    1. Drive health: `sudo smartctl -a /dev/nvme0n1` for model, firmware, percentage used and temperature. Sustained temperatures in the 70s mean the drive is throttling.
1. Check swap before blaming the disk. On my machine the disk was fine and the real problem was 4.4 GB of Nethermind and Lighthouse memory sitting in swap, which makes block production page-fault its way through the tx pool and state.
    1. `free -h`. If `Swap` used is non-zero while `available` is large, process memory got swapped out during some earlier pressure (startup, a full prune, a resync) and the kernel never pulls it back on its own.
    1. See who owns it, in MB per process:
    ```
    for p in /proc/[0-9]*; do awk -v pid="${p#/proc/}" '/VmSwap/ && $2 > 0 {print $2, pid}' "$p/status"; done 2>/dev/null | sort -n | tail -5 | while read kb pid; do printf "%6d MB  %s\n" $((kb/1024)) "$(cat /proc/$pid/comm)"; done
    ```
    1. Pull it all back into RAM. Needs `available` to exceed swap used. Takes a minute or two and spikes reads, so do it in `tmux` and not near a proposal or sync committee duty:
    ```
    sudo swapoff -a && sudo swapon -a
    free -h
    ```
    1. Stop it drifting back by telling the kernel to drop page cache before process memory:
    ```
    sudo sysctl vm.swappiness=10
    echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
    ```
    1. Expect it to recur after a full prune, which is the memory-hungriest thing Nethermind does. Same fix.

## Staking

1. Get yourself a new address to use as the fee recipient address and the withdrawal address. Should be on a hardware wallet, seed phrase secure etc. You set the withdrawal address at key generation time below, so have it ready. Decide too between a regular (type 1, 32 ETH max effective balance) and a compounding (type 2, up to 2048 ETH) validator.
1. On the staking machine:
    1. Download, extract and tidy up the deposit CLI. The original `ethereum/staking-deposit-cli` is archived and deprecated; use the EthStaker one.
        1. Go to https://github.com/eth-educators/ethstaker-deposit-cli/releases/ and copy the URL of the latest `linux-amd64` (Intel NUC) or `linux-arm64` (Rock 5B) tarball.
        1. `cd /data`
        1. `wget <paste URL here>`
        1. `tar -xvf ethstaker*`
        1. `rm ethstaker*.tar.gz`
        1. `mv ethstaker*/deposit .`
        1. `rmdir ethstaker*`
    1. Go offline before generating the mnemonic. In a perfect world you do this on an air-gapped machine with a fresh OS installation that's never been online. But having the validator keys on the staking machine itself at the end is convenient, so simply doing it on the staking machine while offline is acceptable, imo. Reboot before and after generating the mnemonic.
    1. Run it and record the mnemonic. We'll generate two keys but use only one for now.
        1. `./deposit new-mnemonic --num_validators 2 --chain mainnet --withdrawal_address 0xYOUR_WITHDRAWAL_ADDRESS` and add `--compounding` or `--regular_withdrawal` to pick the validator type.
        1. The _password that secures your validator keystore(s)_ doesn't need to be super secure. Someone with these keys can sabotage your validator performance but can't withdraw your stake. It will be written in plain text to the filesystem when Lighthouse imports the keys anyway.
    1. This will generate:
        1. `./validator_keys/deposit_data-*.json`
        1. `./validator_keys/keystore-m_12381_3600_0_0_0-1663727039.json`
    1. Remember this mnemonic can be used to regenerate the signing keys later, although you'll get a slightly different keystore file if you do, even if you use the same password. The withdrawal address is baked into the deposit's withdrawal credentials, so there's no separate withdrawal key to look after.
    1. Import only the first of the two keystores into the validator:
        1. `lighthouse --network mainnet --datadir /data/lighthouse/mainnet account validator import --keystore /data/validator_keys/keystore-m_12381_3600_0_0_0-*.json` and enter the password for the keystore.
    1. Back the keystore up onto a USB drive
        1. First format the drive:
            1. `lsblk`, plug the drive in, 'lsblk' again to spot the name of the device. Might be `/dev/sda`.
            1. Unmount any paritions if they're mounted: `sudo umount /dev/sda1`, `sudo umount /dev/sda2`.
            1. Make a new partition table: `sudo fdisk /dev/sda`, `o`, `n`, `p`, `1`, default, default, `w`
            1. Format the new partition: `sudo mkfs.vfat -F 32 -n 'keys' /dev/sda1`
            1. Eject: `sudo eject /dev/sda`
            1. Reinsert the drive
            1. `sudo mkdir /media/usb`
            1. `sudo mount -t vfat /dev/sda1 /media/usb`
        1. `sudo cp -r /data/validator_keys /media/usb`
        1. `sudo eject /media/usb`
1. On the machine where you have MetaMask and your hardware wallet connected:
    1. Run through the checklist at https://launchpad.ethereum.org/en/checklist and make sure everything is tickety-boo.
    1. Get to https://launchpad.ethereum.org/en/upload-deposit-data where you upload your deposit data.
    1. Plug in the USB drive and mount it.
    1. Get as far as https://launchpad.ethereum.org/en/generate-keys in the Launchpad flow. This is where you upload your deposit data JSON file, connect using the account you have on your hardware wallet, and pay the 32 ETH.
    1. If you generated more keys than you needed:
        1. Edit the deposit data JSON file down to just the ones you're funding, and
        1. Edit the `/data/lighthouse/mainnet/validators/validator_definitions.yml` file to disable the other validators.
    1. This transaction cost 50,634 gas, which was 0.00065 ETH at the time when I last did it. Having 0.001 ETH in your accouint to cover gas should be more than enough.
1. Copy the public keys of the validator(s) you're funding from `/data/lighthouse/mainnet/validators/validator_definitions.yml` so you can paste them into beaconcha.in later (see Monitoring below)
1. Add the Ethereum address to which you want rewards paid to the validators definition file:
    1. `sudo nano /data/lighthouse/mainnet/validators/validator_definitions.yml`
    1. Add a `suggested_fee_recipient` value for each validator. The value has no quotes.

## Monitoring

### Mobile push alerts

1. Create a user on https://beaconcha.in/.
1. Got to https://beaconcha.in/user/notifications and add your validator.
1. Get the mobile app.
1. Sign in on the mobile app.
1. Consider turning off the missed attestation notification after a week or so of smooth running. They're quite noisy and if you get too many notifications, you risk missing a more important one such as being offline.

### Tailing the logs

1. Run `tmux` first, to get output from multiple services on the screen at once. `tmux` refresher:
    1. Create four panes by pressing `C-b "` three times (each press splits the current pane)
    1. Enter command prompt mode with `C-b :`, then:
        1. Make the panes evenly sized: `select-layout even-vertical`
        1. Give the panes titles of their index and the command running in them: `set -g pane-border-format "#{pane_index} #{pane_current_command}"`
    1. Move around the panes with `C-b [arrow keys]`
    1. Kill a pane with `C-b x`
    1. Dettach from the session with `C-b d`
1. Tail the logs for each running `systemd` service, one per pane (`ccze` is a logs colouriser):
    1. `journalctl -u nethermind -f | ccze`
    1. `journalctl -u mev-boost -f | ccze`
    1. `journalctl -u lighthouse-bn -f | ccze`
    1. `journalctl -u lighthouse-vc -f | ccze`

## Troubleshooting issues

1. Once you know your validator node index, you can get the current balance of your validator with `curl http://192.168.20.51:5052/eth/v1/beacon/states/head/validators/{index}` (the BN is bound to the LAN address, not `localhost`, in the unit file above).
1. Check disks have space: `df -h`
    1. To prune Nethermind, call the `admin_prune` RPC endpoint, like [this](https://docs.nethermind.io/interacting/json-rpc-ns/admin#admin_prune).
    1. Expect this to take a day or two. Definitely don't do this if you're about to be in the sync committee.
1. Check CPU load average: `htop`. Should be 0.70 max, times the number of cores. So on an 8-core machine, a load average of 5.6 is the threshold at which the machine is getting overloaded.
1. Check RAM available: `htop`, see `Mem`.
1. Check internet connectivity and speed:
    1. `sudo apt install speedtest-cli`
    1. `speedtest --secure`
    1. My results: ~250 Mbit/s down, ~90 Mbit/s up.
    1. Minumum according to some Googling: 10 Mbit/s either way.
    1. If your router is a bit rubbish, like mine, you might want to preemptively reboot it once a month rather than have it go down in the middle of the night.
1. Check logs:
    1. Execution client: `grep -e WARN -e ERROR /data/nethermind/logs/mainnet.logs.txt`, or `journalctl -u nethermind | grep -e WARN -e ERROR`
    1. Beacon Node: `grep -e WARN -e ERRO -e CRIT /data/lighthouse/mainnet/beacon/logs/beacon.log`
    1. Validator: `grep -e WARN -e ERRO -e CRIT /data/lighthouse/mainnet/validators/logs/validator.log`
    1. Google any errors.
    1. Upgrade to latest stable versions if necessary.
    1. Ask in the Discord server for the client about any errors if they persist after upgrade.
1. Check the ports you're listening on:
    1. `sudo lsof -nP -iTCP -sTCP:LISTEN +c0 | grep IPv4`
    1. Ignoring the OS services such as `sshd`, you should have:

|Port   |Process                                   |
|-------|------------------------------------------|
|`30303`|EL client, p2p with other execution nodes|
|`8545` |EL client, JSON RPC for general use|
|`8551` |EL client, Engine API for the CL client only|
|`8555` |EL client, the extra `admin` RPC from the `.env` file|
|`9000` |CL client, p2p with other beacon nodes|
|`5052` |CL client, Beacon Node API for general use|
|`18550`|MEV Boost|

## Client upgrades

1. Subscribe to the repos to get an email on a new release. For each of these, drop down 'Watch', go to 'Custom' and check 'Releases'.
    1. https://github.com/nethermindeth/nethermind/releases
    1. https://github.com/sigp/lighthouse/releases
    1. https://github.com/flashbots/mev-boost/releases
1. If using a PPA, the update to the binary will happen automatically on new releases, but there's no automated restart of the process after that AFACT. It might also take some time to install. If you're in a rush to upgrade:
    1. `sudo apt update`
    1. `apt list --upgradable` and expect to see `nerthermind` in there.
    1. If it's very soon after the release the binary may still be being built. Check https://launchpad.net/~nethermindeth/+archive/ubuntu/nethermind/+packages.
    1. `sudo apt upgrade`
1. If you followed the above instructions, here's what you're using:
    1. `nethermind`: PPA
    1. `lighthouse`: binary
    1. `mev-boost`: binary
1. To check which version you're currently running, run these. But be aware that in the case of a PPA, the running process may in fact still be the older version. You'll need to restart to get the new version to start executing.
    1. `nethermind --version`
    1. `lighthouse --version`
    1. `/data/mev-boost --version`
1. On each new release:
    1. Follow the instructions above again to get a new binary.
    1. Overwrite the existing binary as root.
    1. If it's executable as anyone, there's no need to `chown` and `chgrp` it back to the process owner as root.
    1. Restart the process with `sudo systemctl restart [service]`
    1. Check the logs in the tmux session for a successful restart.

## Unstaking

To stop staking, which is different to withdrawal:

* `lighthouse account validator exit`

## What do do if...

### You travel

* Open up your chosen SSH port (eg. 60001) on your NATs before you go.
* Make sure the laptop you take has the SSH keys for the staking machine - test connecting from outside, using a mobile internet connection.
* Disable the SSH port NAT when you get back.

### Your staking machine gets stolen

* Don't panic about losing your stake. The withdrawal private key is not on the machine and can be generated from the mnemonic only. We haven't even generated that private key yet, anywhere.
* Don't go and build a new staking machine, regenerate the same keys and start running again. You'll risk slashing by double signing if:
    * You didn't turn on Lighthouse's [doppelganger protection](https://lighthouse-book.sigmaprime.io/validator-doppelganger.html) AND
    * The thief powers on the machine AND
    * The machine manages to find the router on the thief's network because the subnet is the same or the thief cared enough to detect the expected subnet AND
    * The processes are all set up to start on boot using `systemd` OR
    * The thief got the user password and started all the services
* So is it worth turning on doppelganger protection?
    * Probably not. If the machine password is secure and you didn't set up `systemd` services, the chances of the machine ever validating again are low and the cost of DP is two or three epochs of rewards on an upgrade or restart.
* Instead, wait a month or two and monitor your validator index.
    * If it never starts running again, it's low enough risk to build a new machine and start validating again with regenerated keys.
    * There's little point in the thief extracting the validator key from the machine, because it can't be used without the password anyway.
    * See also this [discussion](https://www.reddit.com/r/ethstaker/comments/p9ylco/what_to_do_if_your_staking_machine_is_physically/)

### You need to migrate to a new machine

* Follow everything above again on the new machine but only up to the point of creating the validator keys. The goal is to avoid slashing for double signing, so you only want one machine running at a time with the keys on it.
* You can get the new machine sync'ed to the point of one of the earlier phases in snap sync and be ready for the validator to work. You don't need to wait for the later phases (old headers, old bodies, old receipts).
* You'll sleep better at night knowing you've tested restoring from only the seed phrase so we'll use that approach here but other options are available:
    * You can physically move the `/data/lighthouse/mainnet/validators` directory to the new machine, assuming the old one is still around.
    * Lighthouse has a `move` command.
* Stop all the services on the new machine:
```
sudo systemctl stop lighthouse-vc
sudo systemctl stop lighthouse-bn
sudo systemctl stop mev-boost
sudo systemctl stop nethermind
```
* Unplug the Ethernet cable. You'll need to be on the machine itself from here on, obvs, not SSH-ing in.
* `curl google.com` to check you're really offline (maybe you have WiFi?). You probably don't have `ping` installed.
* Recreate the validator keys from the mnemonic, making sure you can write to the `/data/validator_keys` directory first:
```
cd /data
sudo chown [username]:[username] validator_keys
/data/deposit --language en existing-mnemonic
```
* At the `Create a password` step, you are NOT entering the old password from the old keystore. You're creating new keystores with the same keys in them, with a new password.
* Compare the `keystore*` files contents to the ones on the old machine, if you still have access to it. Only the `pubkey` value needs to match though.
* Compare the `deposit_data-*.json` files. At least the `pubkey`, `withdrawal_credentials` and `signature` values should match.
* If everything looks good, decomission the old machine:
    * Stop all services (see above)
    * `cd /data/lighthouse/mainnet`
    * `sudo mv validators validators.do_not_use`
    * Start all services
    * `tmux attach` and expect to see the validator NOT running. The VC process should be logging `No validators present`.
    * Unplug the Ethernet cable on the old machine to be safe.
    * Wait two epochs to be safe.
* Recreate the validator on the new machine:
```
lighthouse --network mainnet account validator import --directory /data/validator_keys --datadir /data/lighthouse/mainnet
sudo chown -R lighthouse-vc:lighthouse-vc /data/lighthouse/mainnet/validators
```
* If you're not running all of the validators you created keys for, edit `/data/lighthouse/mainnet/validators/validator_definitions.yml` and set `false` on the ones you don't want.
* Start all the services and tail the logs
```
sudo systemctl start nethermind
sudo systemctl start mev-boost
sudo systemctl start lighthouse-bn
sudo systemctl start lighthouse-vc
tmux attach
```
* Once the only issue in the logs is that you're offline, plug in the Ethernet cable.
* Delete the NATs to the old machine and create new ones to the new machine. See above.
* Lighthouse BN logs should start to say `INFO Syncing`.
* Check https://beaconcha.in/. In time, you should be so back.

### You move house

* See "Unstaking" above.

### You need the RPC endpoint on your local network

* `sudo ufw allow 8545/tcp comment 'rpc'`
* `sudo ufw reload`

### You need the Beacon Node API on your local network

* `sudo ufw allow 5052/tcp comment 'beacon node api'`
* `sudo ufw reload`
* Get the local IP of your host with `ip a` (eg. `http://192.168.20.51:5052/`)
* You won't be able to use the Swagger UI version hosted by the Ethereum Foundation repo at https://ethereum.github.io/beacon-APIs, because it uses `https`. When the browser makes requests to your beacon node, they'll be over straight `http` and you'll get a `Mixed content` error on the browser console. You could serve the API over `https` but it's easier not to.
* Instead just run Swagger UI locally.
    * `git clone git@github.com:ethereum/beacon-APIs.git`
    * `cd beacon-APIs`
    * `python3 -m http.server 8080`
    * Open http://localhost:8080 and set the version to `dev` (release number version will fail because we haven't built the `releases` directory).
    * Set the `server_url` to `http://192.168.20.51:5052/`
    * Test some API endpoints.
