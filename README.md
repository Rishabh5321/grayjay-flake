# grayjay Flake

[![NixOS](https://img.shields.io/badge/NixOS-supported-blue.svg)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![flake_check](https://github.com/Rishabh5321/grayjay-flake/actions/workflows/flake_check.yml/badge.svg)](https://github.com/Rishabh5321/grayjay-flake/actions/workflows/flake_check.yml)

This repository provides a Nix flake for [grayjay](https://github.com/5rahim/grayjay), an open-source media server with a web interface and desktop app for anime and manga. The flake includes the grayjay server and a NixOS module for easy integration into Home Manager configuration.

## Table of Contents
1. [Features](#features)
2. [Installation](#installation)
   - [Using the Flake Directly](#using-the-flake-directly)
   - [Integrating with Home Manager](#integrating-with-home-manager)
3. [Configuration](#configuration)
4. [Troubleshooting](#troubleshooting)
5. [Contributing](#contributing)
6. [License](#license)

---

## Features
- **Pre-built grayjay Package**: The flake provides a pre-built grayjay package for `x86_64-linux`.
- **NixOS Module**: Easily enable grayjay as a systemd user service with the included NixOS module.
- **Dependency Management**: Automatically handles dependencies like `mpv` for video playback.

---

## Installation

### Using the Flake Directly
You can run grayjay directly using the flake without integrating it into your NixOS configuration:

```bash
nix run github:rishabh5321/grayjay-flake
```
### Using the Flake Profiles

You can install grayjay directly using the flake without integrating it into your NixOS configuration:
```bash
nix profile install github:rishabh5321/grayjay-flake#grayjay
```
Then to start the app use `grayjay` or run grayjay in terminal

### Integrating with Home Manager 

Currently home-manager is necessary for having for building the server as this flake creates a service for user not system.

1. Add the grayjay flake to your flake.nix inputs.
```nix
grayjay.url = "github:rishabh5321/grayjay-flake";
```
2. Import the grayjay module in your NixOS configuration in home.nix:
```nix
{ inputs, ... }: {
   imports = [
      inputs.grayjay.nixosModules.grayjay # import this in home.nix
   ];
}
```
3. Enable grayjay module in home.nix
```nix
modules.home.services.grayjay.enable = true;
```
4. Rebuild your system:
```bash
sudo nixos-rebuild switch --flake .#<your-hostname>
```
OR
```bash
nh os boot --hostname <your-hostname> <your-flake-dir>
```
5. Start the grayjay service:
```bash
systemctl --user start grayjay
```

### Configuration

The grayjay flake provides the following options:

NixOS Module Options:

`modules.home.services.grayjay.enable:` Enable or disable the grayjay service.

### Example Configuration

Here’s an example of how to configure grayjay in your NixOS configuration: (In home.nix)

```nix
{ config, pkgs, inputs, ... }: # this is for home.nix

{
  imports = [
    inputs.grayjay.nixosModules.grayjay
  ];

  modules.home.services.grayjay.enable = true;
}
```

### Troubleshooting

`mpv` Not Found

If grayjay fails to play videos with the error `exec: "mpv": executable file not found in $PATH`, ensure that `mpv` is installed and available in the `$PATH`. You can add `mpv` to your system or user packages:

#### System-Wide Installation:

Add `mpv` to `environment.systemPackages` in your NixOS configuration:
```nix
environment.systemPackages = with pkgs; [
  mpv
];
```
OR
#### User-Specific Installation
Add `mpv` to `home.packages` in your Home Manager configuration:
```nix
home.packages = with pkgs; [
  mpv
];
```

#### Service Not Starting
If the grayjay service fails to start, check the logs for more details:
```bash
journalctl --user -u grayjay -f
```

### Contributing

Contributions to this flake are welcome! Here’s how you can contribute:
1. Fork the repository.
2. Create a new branch for your changes:
```bash
git checkout -b my-feature
```
3. Commit your changes:
```bash
git commit -m "Add my feature"
```
4. Push the branch to your fork:
```bash
git push origin my-feature
```
5. Open a pull request on GitHub.

### License
This flake is licensed under the MIT License. grayjay itself is licensed under the GPL-3.0 License.

### Acknowledgments

## Acknowledgments
- [grayjay](https://github.com/5rahim/grayjay) by 5rahim for the amazing media server.
- [Th4tGuy69](https://github.com/Th4tGuy69) for their [NixOS configuration](https://github.com/Th4tGuy69/nixos-config) that inspired parts of this flake.
- [70705](https://github.com/70705) for their [flake setup](https://github.com/70705/nixconfig) that helped streamline this project.
- The NixOS community for their support and resources.
