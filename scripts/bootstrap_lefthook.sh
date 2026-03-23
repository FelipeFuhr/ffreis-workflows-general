#!/usr/bin/env bash
set -euo pipefail

LEFTHOOK_VERSION="${LEFTHOOK_VERSION:-}"
BIN_DIR="${BIN_DIR:-.bin}"

if [[ -z "$LEFTHOOK_VERSION" ]]; then
  echo "ERROR: LEFTHOOK_VERSION is required"
  exit 1
fi

mkdir -p "$BIN_DIR"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64) arch="x86_64" ;;
  aarch64|arm64) arch="arm64" ;;
  *) echo "ERROR: unsupported arch: $arch"; exit 1 ;;
esac

tarball="lefthook_${LEFTHOOK_VERSION}_${os}_${arch}.tar.gz"
url="https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/${tarball}"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

curl -fsSL "$url" -o "$tmp/$tarball"
tar -xzf "$tmp/$tarball" -C "$tmp"

install -m 0755 "$tmp/lefthook" "$BIN_DIR/lefthook"
echo "Installed lefthook to $BIN_DIR/lefthook"

