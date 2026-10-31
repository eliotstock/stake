# ARM

Notes from trying a Radxa Rock 5B (ARM) as the staking machine instead of the Intel NUC. I never put it into service. They're additive to the [README.md](README.md), which covers the NUC.

If you want a quiet, fanless machine, ARM is tempting, but beware the issues below.

## Hardware and OS install

1. Grab a Radxa Rock 5B board and parts. Specs for mine:
    1. 16 GB RAM
    1. Small drive (OS) is a 64 GB eMMC
    1. Big drive (data) is a Crucial P3 Plus PCIe 4.0 NVMe M.2 2280. Do NOT get an NVMe drive with a massive heat sink on it, cause it won't fit. Clearance is limited between the bottom of the board and the case.
        1. This drive claims "Up to 4,800MB/s Read - Up to 4,100MB/s Write" on the box.
        1. But hewre's the `fio` output (see the README for the command line used)
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

## Differences from the README

The Radxa image is based on Ubuntu 22.04 (jammy) and ships Radxa's own kernel, not Ubuntu's `linux` package, so Ubuntu kernel security fixes don't reach it. You depend on Radxa for those.

1. Static IP: the Ethernet interface name was `enP4p65s0`.
1. SSH: the `ssh.socket` port override isn't needed on the 22.04-based Radxa image. Setting `Port` in `sshd_config` is enough.
1. Unattended upgrades: `sudo touch /etc/apt/apt.conf.d/50unattended-upgrades` first, because this won't exist.
1. fail2ban: the Radxa image has no `/var/log/auth.log`, so `backend = systemd` (reading from the journal) is required.
1. Lighthouse: use the `aarch64-unknown-linux-gnu` tarball.
1. Deposit CLI: use the `linux-arm64` tarball.
