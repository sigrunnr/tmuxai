#!/bin/bash

# Usage:
# ./install-local.sh                 # Installs tmuxai from the local working repo
#
set -euo pipefail


GH_REPO="sigrunnr/tmuxai"
PROJECT_NAME="tmuxai"
DEFAULT_INSTALL_DIR="/usr/local/bin"

CONFIG_DIR="$HOME/.config/tmuxai"
CONFIG_FILE="$CONFIG_DIR/config.example.yaml"
EXAMPLE_CONFIG_URL="https://raw.githubusercontent.com/sigrunnr/tmuxai/main/config.example.yaml"

tmp_dir=""

err() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() {
  echo "$*"
}

# Checks if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Main Script Logic ---

main() {
  local version="" # Keep version local to main
  local install_dir="$DEFAULT_INSTALL_DIR" # Keep install_dir local to main

  while [ $# -gt 0 ]; do
    case $1 in
      -b | --bin-dir)
        install_dir="$2"
        shift 2
        ;;
      -V | --version)
        version="$2"
        shift 2
        ;;
      # Allow specifying version directly as the first argument (e.g., bash -s v1.0.0)
      v*)
        if [ -z "$version" ]; then # Only if version not already set by -V
            version="$1"
        fi
        shift
        ;;
      *)
        echo "Unknown argument: $1"
        # You could add a usage function here
        exit 1
        ;;
    esac
  done

  # Ensure the target installation directory exists
  mkdir -p "$install_dir" || err "Failed to create installation directory: $install_dir"

  # --- Check for tmux ---
  if ! command_exists tmux; then
    info "-----------------------------------------------------------"
    info "'tmux' command not found."
    info "tmuxai requires tmux to function."
    info "Please install tmux:"
    info "  On Debian/Ubuntu: sudo apt update && sudo apt install tmux"
    info "-----------------------------------------------------------"
    exit 1
  fi

  # --- Dependency Checks ---
  command_exists curl || err "'curl' is required but not installed."
  command_exists grep || err "'grep' is required but not installed."
  command_exists cut || err "'cut' is required but not installed."
  command_exists tar || err "'tar' is required but not installed."
  command_exists mktemp || err "'mktemp' is required but not installed."


  # --- Platform Detection ---
  # Keep these local as they are only used within main
  local os_raw os_lower arch archive_ext
  os_raw=$(uname -s)
  os_lower=$(echo "$os_raw" | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)

  case "$os_lower" in
    linux)
      archive_ext="tar.gz"
      ;;
    mingw* | cygwin* | msys*)
      os_raw="Windows"
      archive_ext="zip"
      command_exists unzip || err "'unzip' is required for Windows assets."
      ;;
    *)
      err "Unsupported operating system: $os_raw"
      ;;
  esac

  case "$arch" in
    x86_64 | amd64)
      arch="amd64"
      ;;
    arm64 | aarch64)
      arch="arm64"
      ;;
    *)
      err "Unsupported architecture: $arch"
      ;;
  esac

  local api_url release_data download_url asset_filename tag_name
  tag_name=$(git describe --tags)
  if [ -z "$tag_name" ]; then
    err "Could not determine latest release version tag."
  fi
  info "Using latest version tag: $tag_name"

  asset_filename="${PROJECT_NAME}_${os_raw}_${arch}.${archive_ext}"

  # --- Build and Install ---
  tmp_dir=$(mktemp -d -t ${PROJECT_NAME}_install_XXXXXX)

  info "Building $asset_filename..."
  goreleaser release --clean --skip publish || err "Build failed."
  cp "dist/$asset_filename" "$tmp_dir/."

  pushd "$tmp_dir" > /dev/null
  case "$archive_ext" in
    tar.gz)
      tar -xzf "$asset_filename" || err "Failed to extract tar.gz archive."
      ;;
    zip)
      unzip -q "$asset_filename" || err "Failed to extract zip archive."
      ;;
    *)
      popd > /dev/null
      err "Unsupported archive extension: $archive_ext"
      ;;
  esac
  popd > /dev/null

  # Keep binary_path local
  local binary_path="dist/$PROJECT_NAME"
  if [ ! -f "$binary_path" ]; then
     info "Binary not found at top level, searching subdirectories..."
     local found_binary=$(find "dist" -maxdepth 2 -type f -name "$PROJECT_NAME" -print -quit)
     if [ -z "$found_binary" ]; then
        err "Could not find executable '$PROJECT_NAME' in the extracted archive."
     fi
     binary_path="$found_binary"
     info "Found executable in subdirectory: $binary_path"
  fi

  # --- Installation ---
  local target_path="$install_dir/$PROJECT_NAME"
  local sudo_cmd=""

  if [ -d "$install_dir" ] && [ ! -w "$install_dir" ] || { [ ! -e "$install_dir" ] && [ ! -w "$(dirname "$install_dir")" ]; }; then
      info "Write permission required for $install_dir or its parent. Using sudo."
      command_exists sudo || err "'sudo' command not found, but required to write to $install_dir. Please install sudo or choose a writable directory with -b option."
      sudo_cmd="sudo"
  fi

  if command_exists install; then
    $sudo_cmd install -m 755 "$binary_path" "$target_path" || err "Installation failed using 'install' command."
  else
    info "Command 'install' not found, using 'mv' and 'chmod'."
    $sudo_cmd mv "$binary_path" "$target_path" || err "Failed to move binary to $target_path."
    $sudo_cmd chmod 755 "$target_path" || err "Failed to make binary executable."
  fi

  # --- Verification and Completion ---
  info "Installed binary: $target_path"

  # Keep installed_version_output local
  local installed_version_output="N/A"
  if "$target_path" --version > /dev/null 2>&1; then
      installed_version_output=$("$target_path" --version)
  elif "$target_path" version > /dev/null 2>&1; then
      installed_version_output=$("$target_path" version)
  else
      installed_version_output="(version command failed or not supported by '$PROJECT_NAME')"
  fi
  info ""
  info "$installed_version_output"
  info ""

  # --- Install Configuration File ---
  mkdir -p "$CONFIG_DIR" || err "Failed to create configuration directory: $CONFIG_DIR"
  if curl -sfLo "$CONFIG_FILE" "$EXAMPLE_CONFIG_URL"; then
    info "Example configuration added to $CONFIG_FILE"
  fi

  case ":$PATH:" in
      *":$install_dir:"*)
          ;;
      *)
          info "Warning: '$install_dir' is not in your PATH."
          info "You may need to add it to your shell configuration (e.g., ~/.bashrc, ~/.zshrc):"
          info "  export PATH=\"\$PATH:$install_dir\""
          info "Then, restart your shell or run: source ~/.your_shell_rc"
          ;;
  esac
  info ""
  info "To get started, set the TMUXAI_OPENROUTER_API_KEY environment variable or add it to the config: ${CONFIG_DIR}/config.yaml"
}

main "$@"