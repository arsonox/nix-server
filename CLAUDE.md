# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS flake-based configuration repository managing multiple server hosts. The flake is located at `/home/nox/etc/nixos` and uses flakes and nix-command experimental features.

## Build and Deploy Commands

```bash
# Build configuration for a specific host
sudo nixos-rebuild build --flake .#<hostname>

# Switch to new configuration (activate immediately)
sudo nixos-rebuild switch --flake .#<hostname>

# Build and activate on next boot (safer for remote servers)
sudo nixos-rebuild boot --flake .#<hostname>

# Test configuration without making it permanent
sudo nixos-rebuild test --flake .#<hostname>

# Update flake inputs
nix flake update

# Using nh (enabled on all hosts, flake path: /home/nox/etc/nixos)
nh os switch  # Switches to new configuration
nh os build   # Just builds without switching
nh clean      # Cleans old generations (keeps last 3 or last 4 days)
```

## Architecture

### Host Configuration Structure

Four active hosts are defined in `flake.nix`:
- **archivum**: Media/storage server with ZFS, includes VPN confinement module
- **ubiqium**: Network/UniFi controller host
- **quaesitum**: Web services host (searxng, nginx)
- **fabricum**: Development/general purpose host

Each host follows this pattern:
```
hosts/<hostname>/
├── configuration.nix       # Main host configuration, imports hardware-configuration, services, programs, and ../common
├── hardware-configuration.nix
├── disko.nix              # Declarative disk partitioning (if present)
├── services/
│   └── default.nix        # Auto-imports all .nix files in directory using lib.filesystem.listFilesRecursive
└── programs/
    └── default.nix
```

### Common Configuration

`hosts/common/` contains shared configuration imported by all hosts:
- Security hardening (audit logs, core dumps disabled, run0-sudo-shim)
- Firewall defaults
- User setup (nox user with SSH keys)
- Base services (fstrim, logrotate, journald, dbus-broker)
- Overlay configuration (unstable packages via `pkgs.unstable`)

### Flake Inputs

Key external dependencies:
- `nixpkgs`: NixOS 25.11 stable
- `nixpkgs-unstable`: Access via `pkgs.unstable` through overlays
- `home-manager`: Release 25.11
- `vpn-confinement`: VPN namespace confinement (used on archivum)
- `run0-sudo-shim`: Applied to all hosts via defaultModules

### Overlays System

Three overlay types defined in `overlays/default.nix`:
1. **additions**: Custom packages from `pkgs/` directory
2. **modifications**: Package overrides and patches
3. **unstable-packages**: Makes nixpkgs-unstable available as `pkgs.unstable`

All overlays are applied in `hosts/common/default.nix` to every host.

### Services Auto-Import Pattern

Service directories use automatic imports:
```nix
imports = builtins.filter (lib.strings.hasSuffix ".nix") (
  map toString (builtins.filter (p: p != ./default.nix) (lib.filesystem.listFilesRecursive ./.))
);
```

When adding new services to a host, create a `.nix` file in `hosts/<hostname>/services/` and it will be automatically imported.

## Automated Updates

The `auto-updates.nix` service:
- Pulls git changes at 04:40 daily (must be on main branch)
- Automatically rebuilds using `nixos-rebuild boot`
- Switches if kernel/initrd unchanged, otherwise reboots
- Configured in `hosts/common/services/auto-updates.nix`

## ZFS Hosts

Hosts using ZFS (archivum) require:
- `networking.hostId` set (generate with: `head -c4 /dev/urandom | od -A none -t x4`)
- Auto-scrub enabled via `services.zfs.autoScrub`
- Pool name on archivum is `tank` (as of recent commits)

## State Version

Current state version is 25.11 (NixOS 25.11). Do not change stateVersion without understanding the implications (see nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion).
