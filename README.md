# freebsdstrap-archive-sh

A shell script for automated installation of archived FreeBSD versions (pre-8.x) using distribution files in the current directory.

## Overview

`freebsdstrap-archive-sh` automates the installation of archive FreeBSD versions using distribution files that are already present in the same directory as the script. It handles the entire installation process, including:

- Disk partitioning with GPT
- Filesystem creation
- Extracting the FreeBSD base system and kernel archives
- Complete system configuration (rc.conf, fstab, resolv.conf)
- User account setup

## Features

- Automated GPT disk partitioning designed for future expansion
- UFS filesystem creation
- Installation from local base and kernel archives
- Comprehensive system configuration via config file
- User account setup with password hash support
- Swap partition configuration

## Prerequisites

- A FreeBSD-based live environment (such as a FreeBSD installation CD/USB or [mfsBSD](https://mfsbsd.vx.sk/))
- FreeBSD distribution archives (base and kernel) must be in the current directory
  - FreeBSD archive is retrieved using [zinrai/freebsd-archive-combiner](https://github.com/zinrai/freebsd-archive-combiner).
- Properly configured `freebsdstrap-archive-sh.conf` file

## Configuration

All settings are defined in the `freebsdstrap-archive-sh.conf` file.

## Usage

```
# ./freebsdstrap-archive-sh.sh [-c|--config config_file_path] [-h|--help]
```

By default, the script reads `freebsdstrap-archive-sh.conf` in the current directory.

Example:

```
# ./freebsdstrap-archive-sh.sh --config /path/to/my/config.conf
```

## Generating Password Hashes

```
$ openssl passwd -6 -salt saltgoeshere "mypassword"
$6$saltgoeshere$0dg6RXe2XXlYBNB0ejxp2dNiHbEtTjIAHYZbV9ABGmvkP.3eQsWM/wkQMiUP86uC63W7BFBgJRIM6TJloyoP2/
```

## Important Notes

- This script assumes you already have the base and kernel distribution archives in the same directory
- It will completely erase the target disk before installation
- It requires root privileges to run
- For FreeBSD versions 9.x and newer, consider using bsdinstall(8) installation methods

## License

This project is licensed under the MIT License - see the [LICENSE](https://opensource.org/license/mit) for details.
