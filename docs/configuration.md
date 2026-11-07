# Configuration values

Where each value lives, what it's for, and where to find it.
Real config files are gitignored. Only the templates are in git.

## `config/smb.env`: SimplifyMyBiz-wide

Copy from `config/smb.env.example`. Loaded by every per-customer script.

| Variable | Required | What it is | Where to get it |
|---|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Yes, for DNS | API token for SMB's Cloudflare account | Cloudflare dashboard → My Profile → API Tokens → Create Token. Permissions: **Zone → DNS → Edit** and **Zone → Zone → Read**. Zone resources: all zones in the SMB account. Prefer `export CLOUDFLARE_API_TOKEN=...` in your shell over writing it in the file. |

GCP values from the Terraform get added here in the GAM phase (see [gcp-prerequisites.md](gcp-prerequisites.md#7-outputs-this-repo-will-need-from-terraform)).

## `customers/<slug>/customer.env`: one per customer

Copy the folder `customers/_template/` to `customers/<slug>/`.

| Variable | Required | What it is | Example / where to get it |
|---|---|---|---|
| `CUSTOMER_SLUG` | Yes | Short lowercase ID. Must match the folder name. | `simplifymy-biz` |
| `CUSTOMER_NAME` | Yes | Display name | `"Acme Plumbing LLC"` |
| `CUSTOMER_DOMAIN` | Yes | Primary Workspace domain | `simplifymy.biz` |
| `CUSTOMER_SUPERADMIN` | Yes | SMB's daily super-admin in this tenant | `smb-admin@simplifymy.biz` |
| `CUSTOMER_EMERGENCY_ADMIN` | Yes | SMB's emergency super-admin, never used day to day | `smb-defcon@simplifymy.biz` |
| `WORKSPACE_EDITION` | Yes | Workspace plan | `business_starter` (also `business_standard`, `business_plus`) |
| `INTAKE_SHEET_ID` | Later phase | Google Sheet listing employees (columns in [intake-sheet.md](intake-sheet.md)) | The ID from the Sheet's URL |
| `CLOUDFLARE_ZONE_ID` | No | Cloudflare zone. Blank means look it up by domain. | Cloudflare → domain → Overview → API section |
| `DMARC_POLICY` | Yes | DMARC policy | `none` to start. Later `quarantine`, then `reject`. |
| `DMARC_RUA` | After DMARC Management is on | Report address Cloudflare assigns to this zone | Cloudflare → domain → Email → DMARC Management. Copy the `rua` address, without `mailto:`. |

## Script options and environment variables

| Name | Script | Purpose |
|---|---|---|
| `DRY_RUN=1` | all | Print changes without making them. Cloudflare reads still happen. |
| `GAM_DIR` | `00-install-gam.sh` | Install location. Default `~/bin/gam7`. |
| `GAM_VERSION` | `00-install-gam.sh` | Release tag such as `v7.50.00`. Default `latest`. |
| `--verify "google-site-verification=..."` | `20-dns-cloudflare.sh` | Domain verification TXT from Workspace signup |
| `--dkim "v=DKIM1; k=rsa; p=..."` | `20-dns-cloudflare.sh` | DKIM record from the Admin Console |
| `--replace-mx` | `20-dns-cloudflare.sh` | Delete MX records that aren't Google's |
| `--replace-spf` | `20-dns-cloudflare.sh` | Overwrite an existing SPF record that isn't Google's |

## Secrets: never in git

| Secret | Where it lives |
|---|---|
| Cloudflare API token | Shell environment. Planned: Secret Manager. |
| Super-admin and emergency-admin passwords and security keys | Password manager / physical keys |
| GAM credentials (later phase) | GAM config directory (`~/.gam` by default) and Secret Manager, never this repo |
