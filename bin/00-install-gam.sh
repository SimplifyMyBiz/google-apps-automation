#!/usr/bin/env bash
# Install (or upgrade) GAM7 on macOS from the official GitHub release.
#   bin/00-install-gam.sh            install latest into ~/bin/gam7
#   GAM_VERSION=v7.50.00 bin/00-install-gam.sh
# Does not touch your shell config; prints what to add instead.

source "$(dirname "$0")/../lib/common.sh"
require_cmd curl jq tar shasum

GAM_DIR="${GAM_DIR:-$HOME/bin/gam7}"
GAM_VERSION="${GAM_VERSION:-latest}"

[[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS"
arch="$(uname -m)"                       # arm64 | x86_64
IFS=. read -r os_maj os_min _ <<<"$(sw_vers -productVersion)"
os_min="${os_min:-0}"

if [[ "$GAM_VERSION" == "latest" ]]; then
  api="https://api.github.com/repos/GAM-team/GAM/releases/latest"
else
  api="https://api.github.com/repos/GAM-team/GAM/releases/tags/$GAM_VERSION"
fi
release="$(curl -fsSL "$api")" || die "Could not fetch release info from $api"
tag="$(jq -r .tag_name <<<"$release")"

# Newest macOS build for this arch that is not built for a newer macOS than ours
asset="$(jq -c --arg arch "$arch" --argjson maj "$os_maj" --argjson min "$os_min" '
  [ .assets[]
    | select(.name | test("-macos[0-9.]+-" + $arch + "\\.tar\\.xz$"))
    | . + (.name | capture("macos(?<M>[0-9]+)\\.(?<m>[0-9]+)") | {M: (.M|tonumber), m: (.m|tonumber)})
    | select(.M < $maj or (.M == $maj and .m <= $min)) ]
  | sort_by(.M, .m) | last // empty' <<<"$release")"
[[ -n "$asset" ]] || die "No GAM $tag build for macOS $os_maj.$os_min $arch"

name="$(jq -r .name <<<"$asset")"
url="$(jq -r .browser_download_url <<<"$asset")"
digest="$(jq -r '.digest // empty' <<<"$asset")"   # "sha256:<hex>" on newer GitHub releases

if [[ -x "$GAM_DIR/gam" ]]; then
  log "Currently installed: $("$GAM_DIR/gam" version simple 2>/dev/null || echo unknown)"
fi
log "Installing GAM $tag ($name) into $GAM_DIR"
[[ "$DRY_RUN" == "1" ]] && { log "Dry run, stopping here"; exit 0; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$name" "$url"

if [[ -n "$digest" ]]; then
  expected="${digest#sha256:}"
  actual="$(shasum -a 256 "$tmp/$name" | awk '{print $1}')"
  [[ "$expected" == "$actual" ]] || die "SHA-256 mismatch for $name"
  log "SHA-256 verified"
else
  warn "Release has no published digest; skipping checksum check"
fi

mkdir -p "$tmp/x"
tar -xJf "$tmp/$name" -C "$tmp/x"
bin="$(find "$tmp/x" -type f -name gam -perm -u+x | head -1)"
[[ -n "$bin" ]] || die "gam binary not found in archive"
src_dir="$(dirname "$bin")"

if [[ -d "$GAM_DIR" ]]; then
  backup="$GAM_DIR.bak-$(date +%Y%m%d%H%M%S)"
  mv "$GAM_DIR" "$backup"
  log "Previous install moved to $backup"
fi
mkdir -p "$(dirname "$GAM_DIR")"
mv "$src_dir" "$GAM_DIR"
xattr -dr com.apple.quarantine "$GAM_DIR" 2>/dev/null || true

log "Installed: $("$GAM_DIR/gam" version simple)"

cat <<EOF

Your zsh has 'gam' aliased to 'git am' (oh-my-zsh git plugin).
Add these lines to ~/.zshrc AFTER the 'source \$ZSH/oh-my-zsh.sh' line:

  unalias gam 2>/dev/null
  alias gam="$GAM_DIR/gam"

Then open a new terminal and run:  gam version
EOF
