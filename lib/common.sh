#!/usr/bin/env bash
# Shared helpers. Source from bin/ scripts:  source "$(dirname "$0")/../lib/common.sh"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# Run a command, or just print it when DRY_RUN=1.
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '\033[2m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

load_smb_config() {
  local f="$REPO_ROOT/config/smb.env"
  [[ -f "$f" ]] || die "Missing $f (copy config/smb.env.example and fill it in)"
  # shellcheck disable=SC1090
  source "$f"
}

load_customer_config() {
  local slug="${1:-}"
  [[ -n "$slug" ]] || die "Usage: $0 <customer-slug>"
  local f="$REPO_ROOT/customers/$slug/customer.env"
  [[ -f "$f" ]] || die "Missing $f (copy customers/_template/ to customers/$slug/)"
  # shellcheck disable=SC1090
  source "$f"
  [[ "$CUSTOMER_SLUG" == "$slug" ]] || die "CUSTOMER_SLUG in $f is '$CUSTOMER_SLUG', expected '$slug'"
}

# require VAR [VAR...]: fail if any are empty
require() {
  local missing=()
  for v in "$@"; do
    [[ -n "${!v:-}" ]] || missing+=("$v")
  done
  (( ${#missing[@]} == 0 )) || die "Not set: ${missing[*]}"
}

require_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "'$c' is not installed"
  done
}
