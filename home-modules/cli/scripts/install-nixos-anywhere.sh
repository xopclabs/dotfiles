#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
TEMP_DIR=""
TARGET_HOST=""
FLAKE=""
HWCONFIG_TYPE=""
HWCONFIG_PATH=""
declare -a FILES_TO_COPY=()
declare -a CHOWN_RULES=()
EXTRA_ARGS=()

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        echo -e "${YELLOW}Cleaning up temporary directory...${NC}"
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Help function
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

A wrapper script for nixos-anywhere that helps copy extra files (keys, configs, etc.)
and install NixOS on a remote machine.

REQUIRED OPTIONS:
    -t, --target-host HOST      Target machine (e.g., root@192.168.1.100)
    -f, --flake FLAKE          Flake reference (e.g., ~/dotfiles#laptop or .#hostname)

FILE MANAGEMENT OPTIONS:
    -a, --add-file SRC:DEST    Add a file to copy. SRC is local path, DEST is absolute path on target.
                               DEST should be the full path as it will appear on target machine.
                               Can be specified multiple times.
                               Example: -a ~/.ssh/id_ed25519:/home/xopc/.ssh/id_ed25519

    -c, --chown DEST:UID:GID   Set ownership for a path on target machine.
                               DEST should be the full path as it will appear on target machine.
                               Can be specified multiple times.
                               Example: -c /home/xopc/.ssh:1000:1000

HARDWARE CONFIG OPTIONS:
    --generate-hardware-config TYPE PATH
                               Generate hardware configuration during installation.
                               TYPE can be:
                                 - nixos-generate-config (standard method)
                                 - nixos-facter (experimental, more detailed)
                               PATH is where to save the config file.
                               Example: --generate-hardware-config nixos-generate-config ./hardware-configuration.nix
                               Example: --generate-hardware-config nixos-facter ./facter.json

OTHER OPTIONS:
    --vm-test                  Test configuration in a VM before actual installation
    -e, --extra-arg ARG        Pass extra argument to nixos-anywhere. Can be specified multiple times.
                               For options with values, pass flag and value as separate -e args:
                                 -e --phases -e kexec,disko
                                 -e --build-on -e remote
                               For flags without values:
                                 -e --no-disko-deps  (reduces memory for low-RAM VPS)
                                 -e --no-reboot
    --help                     Show this help message

EXAMPLES:
    # Basic installation without extra files
    $(basename "$0") -t root@192.168.1.100 -f ~/dotfiles#laptop

    # Copy SSH keys and set ownership
    $(basename "$0") \\
        -t root@192.168.1.100 \\
        -f ~/dotfiles#laptop \\
        -a ~/.ssh/id_ed25519:/home/xopc/.ssh/id_ed25519 \\
        -a ~/.ssh/id_ed25519.pub:/home/xopc/.ssh/id_ed25519.pub \\
        -c /home/xopc/.ssh:1000:1000

    # Copy SSH keys and age keys for sops
    $(basename "$0") \\
        -t root@192.168.1.100 \\
        -f ~/dotfiles#laptop \\
        -a ~/.ssh/id_ed25519:/home/xopc/.ssh/id_ed25519 \\
        -a ~/.ssh/id_ed25519.pub:/home/xopc/.ssh/id_ed25519.pub \\
        -a /var/lib/sops/age/keys.txt:/var/lib/sops/age/keys.txt \\
        -c /home/xopc/.ssh:1000:1000 \\
        -c /var/lib/sops/age:0:0

    # Generate hardware configuration with nixos-generate-config
    $(basename "$0") \\
        -t root@192.168.1.100 \\
        -f ~/dotfiles#laptop \\
        --generate-hardware-config nixos-generate-config ./hardware-configuration.nix

    # Generate hardware configuration with nixos-facter
    $(basename "$0") \\
        -t root@192.168.1.100 \\
        -f ~/dotfiles#laptop \\
        --generate-hardware-config nixos-facter ./facter.json

    # Test in VM before installation
    $(basename "$0") \\
        -f ~/dotfiles#laptop \\
        --vm-test

    # Install on VPS with limited RAM (1GB), only kexec+disko phases
    $(basename "$0") \\
        -t root@ip \\
        -f ~/dotfiles#vps \\
        -a ~/.ssh/id_ed25519:/home/xopc/.ssh/id_ed25519 \\
        -a ~/.ssh/id_ed25519.pub:/home/xopc/.ssh/id_ed25519.pub \\
        -c /home/xopc/.ssh:1000:100 \\
        -e --no-disko-deps \\
        -e --phases -e kexec,disko

EOF
}

# Error function
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Info function
info() {
    echo -e "${GREEN}$1${NC}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--target-host)
            TARGET_HOST="$2"
            shift 2
            ;;
        -f|--flake)
            FLAKE="$2"
            shift 2
            ;;
        -a|--add-file)
            FILES_TO_COPY+=("$2")
            shift 2
            ;;
        -c|--chown)
            CHOWN_RULES+=("$2")
            shift 2
            ;;
        --generate-hardware-config)
            HWCONFIG_TYPE="$2"
            HWCONFIG_PATH="$3"
            if [[ "$HWCONFIG_TYPE" != "nixos-generate-config" && "$HWCONFIG_TYPE" != "nixos-facter" ]]; then
                error "Hardware config type must be 'nixos-generate-config' or 'nixos-facter'"
            fi
            shift 3
            ;;
        --vm-test)
            EXTRA_ARGS+=("--vm-test")
            shift
            ;;
        -e|--extra-arg)
            EXTRA_ARGS+=("$2")
            shift 2
            ;;
        *)
            error "Unknown option: $1\nUse --help for usage information"
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FLAKE" ]]; then
    error "Flake reference is required. Use -f or --flake"
fi

# Target host is required unless doing VM test
if [[ -z "$TARGET_HOST" && "${#EXTRA_ARGS[@]}" -eq 0 ]]; then
    error "Target host is required unless using --vm-test. Use -t or --target-host"
fi

# Create temporary directory if we have files to copy
if [[ ${#FILES_TO_COPY[@]} -gt 0 ]]; then
    TEMP_DIR=$(mktemp -d)
    info "Created temporary directory: $TEMP_DIR"

    # Copy files
    for file_spec in "${FILES_TO_COPY[@]}"; do
        IFS=':' read -r src dest <<< "$file_spec"
        
        # Expand tilde in source path
        src="${src/#\~/$HOME}"
        
        if [[ ! -e "$src" ]]; then
            error "Source file does not exist: $src"
        fi
        
        # Strip leading slash from dest to make it relative
        dest="${dest#/}"
        
        dest_full="$TEMP_DIR/$dest"
        dest_dir=$(dirname "$dest_full")
        
        info "Copying $src -> /$dest"
        mkdir -p "$dest_dir"
        cp -r "$src" "$dest_full"
    done

    # Show directory structure
    if command -v tree &> /dev/null; then
        tree "$TEMP_DIR"
    else
        find "$TEMP_DIR" -type f
    fi
fi

# Build nixos-anywhere command
CMD=(nix run github:nix-community/nixos-anywhere --)

# Add hardware config generation if specified
if [[ -n "$HWCONFIG_TYPE" ]]; then
    CMD+=(--generate-hardware-config "$HWCONFIG_TYPE" "$HWCONFIG_PATH")
fi

# Add extra files if we have any
if [[ -n "$TEMP_DIR" ]]; then
    CMD+=(--extra-files "$TEMP_DIR")
fi

# Add chown rules
for chown_rule in "${CHOWN_RULES[@]}"; do
    IFS=':' read -r path uid gid <<< "$chown_rule"
    # Strip leading slash from path to make it relative (nixos-anywhere expects relative paths)
    path="${path#/}"
    CMD+=(--chown "$path" "$uid:$gid")
done

# Add flake
CMD+=(--flake "$FLAKE")

# Add target host if specified
if [[ -n "$TARGET_HOST" ]]; then
    CMD+=(--target-host "$TARGET_HOST")
fi

# Add any extra arguments
CMD+=("${EXTRA_ARGS[@]}")

# Print command
info "\nRunning command:"
echo "${CMD[@]}"
echo ""

# Execute
"${CMD[@]}"

info "\nInstallation completed successfully!"
