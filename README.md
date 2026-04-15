# CloudLasso

[![GitHub License](https://img.shields.io/github/license/AluciTech/CloudLasso)](LICENSE)

> [!WARNING]
> This project is in early development and is not yet ready for production use.

Throw a rope around your cloud! CloudLasso automates mounting for Google Drive, OneDrive, and more.

## Overview

CloudLasso is a Bash utility that uses [rclone](https://rclone.org/) to mount cloud storage remotes as local directories. It provides an interactive menu to configure, mount, unmount, and manage remotes, with optional startup-on-login via systemd.

## Setup

### Requirements

- Linux (Debian/Ubuntu, Fedora, Arch, or openSUSE)

Everything else is automatically installed.

### Installation

Download the latest release and run the installer:

```bash
wget https://github.com/AluciTech/CloudLasso/releases/latest/download/CloudLasso.tar.gz
tar -xzf CloudLasso.tar.gz
cd CloudLasso
bash install.sh
```

This installs CloudLasso to `/opt/cloudlasso` and creates a `cloudlasso` symlink in `/usr/local/bin`.

## Usage

```bash
cloudlasso
```

From the interactive menu you can:

1. **Setup a new remote**: pick from your rclone remotes or create one on the spot
2. **Modify existing remote**: rename, change mount point, mount/unmount, or remove
3. **Mount all remotes**: mount every configured remote in one go
4. **Startup on login**: enable/disable a systemd user service to auto-mount on login

Configuration is stored in `~/.config/CloudLasso/cloudlasso.conf`.

## Maintainers

### Testing with Docker

Build the test image and run the installer inside it:

```bash
docker build -t cloudlasso .
docker run -it cloudlasso bash install.sh
```

To get a shell and poke around manually:

```bash
docker run -it cloudlasso
```

### Releasing a new version

1. Make sure all changes are committed and pushed to `main`.
2. Tag the commit and push the tag:

   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

3. The `release` workflow will automatically create a GitHub Release with `install.sh` attached as a downloadable asset.

## License

This project is licensed under the Apache License (Version 2.0).

See the [LICENSE](LICENSE) file for details.

## AI Usage Transparency

This project uses AI tools to assist with development.
For more details, see the [AI Usage Disclosure](AI_USAGE.md) file.
