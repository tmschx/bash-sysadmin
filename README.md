# Linux scripts for system administration

Some scripts for Linux system administration tasks

This repository contains a number of scripts used on Ubuntu to easy some system administrations tasks. Most scripts are for the [bash](https://en.wikipedia.org/wiki/Bash_%28Unix_shell%29) shell. Please feel to use the scripts, use them as an example or copy the tricks you need from them. All scripts contain in-code explanation and comments (some more than others).

## Repository structure

This repository is organised in the following three directories:

* `home/` contains bash login scripts found in a user's home directory
* `motd/` contains message-of-the-day scripts, usually found in `/etc/update-motd.d`
* `scripts/` contains shell scripts

## Shell script

Overview of shell scripts in `scripts/`:

| Script         | Description |
| -------------- | ----------- |
| `slapt.sh`     | Check and update software packages |
| `slbackup.sh`  | Backup files and encrypt to an external device |
| `slblockip.sh` | Add or remove ip-ranges to block by ufw |
| `slcert.sh`    | Create a new signed certificate using OpenSSL |
| `slcheck.sh`   | Perform various system checks | 
| `slcreatevm.sh`| Create a kernel-based Virtual Machine |
| `slhab.sh`     | OpenHAB CLI script using the openHAB rest interface |
| `slimgc.sh`    | Image conversion script to create svg-logos from png-images using Imagick and Potrace |
| `slpem.sh`     | Quick 'n dirty script to create a pound pem-file |
| `slrplog.sh`   | Filter unknown ip addresses from reverse proxy log |
