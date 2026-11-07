#!/usr/bin/env bash
# Set Google Workspace DNS records for a customer in Cloudflare. Safe to re-run.
#
#   bin/20-dns-cloudflare.sh <slug> [options]
#     --verify "google-site-verification=..."   TXT shown during Workspace signup
#     --dkim   "v=DKIM1; k=rsa; p=..."          from Admin Console > Gmail > Authenticate email
#     --replace-mx                              remove non-Google MX records
#     --replace-spf                             overwrite an existing non-Google SPF record
#   DRY_RUN=1 shows the changes without making them.
#
# Manages: MX, SPF, DMARC, and (when given) domain verification + DKIM.

source "$(dirname "$0")/../lib/common.sh"
require_cmd curl jq

slug="${1:-}"; shift || true
load_smb_config
load_customer_config "$slug"
require CLOUDFLARE_API_TOKEN CUSTOMER_DOMAIN DMARC_POLICY

VERIFY_TXT="" DKIM_TXT="" REPLACE_MX=0 REPLACE_SPF=0
while (( $# )); do
  case "$1" in
    --verify)      VERIFY_TXT="$2"; shift 2 ;;
    --dkim)        DKIM_TXT="$2"; shift 2 ;;
    --replace-mx)  REPLACE_MX=1; shift ;;
    --replace-spf) REPLACE_SPF=1; shift ;;
    *) die "Unknown option: $1" ;;
  esac
done

GOOGLE_MX="smtp.google.com"
SPF_RECORD="v=spf1 include:_spf.google.com ~all"
DMARC_RECORD="v=DMARC1; p=$DMARC_POLICY"
[[ -n "${DMARC_RUA:-}" ]] && DMARC_RECORD+="; rua=mailto:$DMARC_RUA"

CF_API="https://api.cloudflare.com/client/v4"

# cf METHOD PATH [JSON]: call Cloudflare, print .result, fail on API errors
cf() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" "$CF_API$path" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json")
  [[ -n "$body" ]] && args+=(--data "$body")
  local resp
  resp="$(curl "${args[@]}")" || die "Cloudflare request failed: $method $path"
  [[ "$(jq -r .success <<<"$resp")" == "true" ]] || die "Cloudflare $method $path: $(jq -c .errors <<<"$resp")"
  jq -c .result <<<"$resp"
}

# cf_write: like cf, but only prints in dry-run mode
cf_write() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '\033[2m[dry-run]\033[0m %s %s %s\n' "$1" "$2" "${3:-}"
  else
    cf "$@" >/dev/null
  fi
}

# Cloudflare may return TXT content wrapped in quotes; compare without them
unquote() { sed -e 's/^"//' -e 's/"$//'; }

records() { # records TYPE NAME
  cf GET "/zones/$ZONE/dns_records?type=$1&name=$2&per_page=100"
}

create_record() { # create_record TYPE NAME CONTENT [PRIORITY]
  local body
  body="$(jq -nc --arg t "$1" --arg n "$2" --arg c "$3" --arg p "${4:-}" \
    '{type:$t, name:$n, content:$c, ttl:1} + (if $p != "" then {priority:($p|tonumber)} else {} end)')"
  log "Create $1 $2 -> $3"
  cf_write POST "/zones/$ZONE/dns_records" "$body"
}

update_record() { # update_record ID TYPE NAME CONTENT
  log "Update $2 $3 -> $4"
  cf_write PATCH "/zones/$ZONE/dns_records/$1" "$(jq -nc --arg c "$4" '{content:$c}')"
}

delete_record() { # delete_record ID DESCRIPTION
  log "Delete $2"
  cf_write DELETE "/zones/$ZONE/dns_records/$1"
}

# ensure_txt NAME CONTENT MATCH_PREFIX [REPLACE] [HINT]: one TXT at NAME starting with MATCH_PREFIX should equal CONTENT.
# With REPLACE=0 an existing, different record is left alone and HINT is printed.
ensure_txt() {
  local name="$1" content="$2" prefix="$3" replace="${4:-1}" hint="${5:-}"
  local existing id current
  existing="$(records TXT "$name" | jq -c --arg p "$prefix" '[.[] | select((.content | ltrimstr("\"")) | startswith($p))]')"
  case "$(jq length <<<"$existing")" in
    0) create_record TXT "$name" "$content" ;;
    1)
      id="$(jq -r '.[0].id' <<<"$existing")"
      current="$(jq -r '.[0].content' <<<"$existing" | unquote)"
      if [[ "$current" == "$content" ]]; then
        log "OK  TXT $name ($prefix...)"
      elif [[ "$replace" == "1" ]]; then
        update_record "$id" TXT "$name" "$content"
      else
        warn "TXT $name already has: $current"
        warn "Not changing it. $hint"
      fi ;;
    *) warn "Multiple TXT records at $name start with '$prefix'; fix these by hand in Cloudflare" ;;
  esac
}

# --- Zone ---
ZONE="${CLOUDFLARE_ZONE_ID:-}"
if [[ -z "$ZONE" ]]; then
  ZONE="$(cf GET "/zones?name=$CUSTOMER_DOMAIN" | jq -r '.[0].id // empty')"
  [[ -n "$ZONE" ]] || die "No Cloudflare zone for $CUSTOMER_DOMAIN that this token can see"
fi
log "Zone $CUSTOMER_DOMAIN ($ZONE)"

# --- Verification ---
if [[ -n "$VERIFY_TXT" ]]; then
  [[ "$VERIFY_TXT" == google-site-verification=* ]] || die "--verify should start with google-site-verification="
  ensure_txt "$CUSTOMER_DOMAIN" "$VERIFY_TXT" "$VERIFY_TXT"
fi

# --- MX ---
mx="$(records MX "$CUSTOMER_DOMAIN")"
others="$(jq -c --arg g "$GOOGLE_MX" '[.[] | select(.content != $g)]' <<<"$mx")"
if (( $(jq length <<<"$others") > 0 )); then
  if [[ "$REPLACE_MX" == "1" ]]; then
    while read -r id content; do delete_record "$id" "MX $content"; done \
      < <(jq -r '.[] | "\(.id) \(.content)"' <<<"$others")
  else
    warn "Existing non-Google MX records: $(jq -r '[.[].content] | join(", ")' <<<"$others")"
    warn "Mail may still go there. Re-run with --replace-mx to remove them."
  fi
fi
if jq -e --arg g "$GOOGLE_MX" 'any(.[]; .content == $g)' <<<"$mx" >/dev/null; then
  log "OK  MX $GOOGLE_MX"
else
  create_record MX "$CUSTOMER_DOMAIN" "$GOOGLE_MX" 1
fi

# --- SPF / DMARC / DKIM ---
ensure_txt "$CUSTOMER_DOMAIN" "$SPF_RECORD" "v=spf1" "$REPLACE_SPF" \
  "Merge Google into it by hand, or re-run with --replace-spf."

# Cloudflare DMARC Management adds its own rua= to the record. Without DMARC_RUA set,
# leave such a record alone rather than dropping the report address.
dmarc_replace=1
if [[ -z "${DMARC_RUA:-}" ]] && records TXT "_dmarc.$CUSTOMER_DOMAIN" | jq -e 'any(.[]; .content | contains("rua="))' >/dev/null; then
  dmarc_replace=0
fi
ensure_txt "_dmarc.$CUSTOMER_DOMAIN" "$DMARC_RECORD" "v=DMARC1" "$dmarc_replace" \
  "It has a report address; copy it into DMARC_RUA in customer.env and re-run."
if [[ -n "$DKIM_TXT" ]]; then
  ensure_txt "google._domainkey.$CUSTOMER_DOMAIN" "$DKIM_TXT" "v=DKIM1"
else
  log "No --dkim given; skipping DKIM (generate it in Admin Console after signup, then re-run)"
fi

log "Done"
