# google-apps-automation

Set up and onboard SimplifyMyBiz (SMB) small-business customers (10–20 people) onto **Google Workspace + Cloudflare**.

SMB is the super-admin in each customer's Workspace tenant (`smb-admin@<domain>`); the customer pays Google directly.
GCP infrastructure (the dedicated project in the SimplifyMyCloud org, its service accounts, backup storage)
is built by separate Terraform. This repo never creates GCP resources and doesn't call gcloud.

## Docs

- [docs/onboarding-checklist.md](docs/onboarding-checklist.md): starting point and step-by-step checklist for a new customer
- [docs/configuration.md](docs/configuration.md): every value, where it lives and where to get it
- [docs/intake-sheet.md](docs/intake-sheet.md): columns of the employee intake Google Sheet (draft)
- [docs/gcp-prerequisites.md](docs/gcp-prerequisites.md): what must exist on GCP (basis for the Terraform repo)
- [docs/project-notes.md](docs/project-notes.md): scope, decisions, conventions, status, open questions

## Layout

```
config/smb.env.example        MSP-wide settings (Cloudflare token). Copy to config/smb.env.
customers/_template/          Per-customer settings. Copy to customers/<slug>/.
bin/00-install-gam.sh         Install/upgrade GAM7 on this Mac
bin/20-dns-cloudflare.sh      Per customer: MX, SPF, DMARC, verification, DKIM in Cloudflare
lib/common.sh                 Shared helpers (logging, config loading, DRY_RUN)
```

`config/smb.env` and `customers/<slug>/` are gitignored. Customer data and credentials never go in git.
Every script can be re-run safely, and `DRY_RUN=1` prints changes without making them.

## One-time setup (SimplifyMyBiz)

1. `cp config/smb.env.example config/smb.env` and fill it in.
2. `bin/00-install-gam.sh`, then fix the `gam` alias as the script tells you.
3. Create a Cloudflare API token with **Zone → DNS → Edit** and **Zone → Zone → Read**, and `export CLOUDFLARE_API_TOKEN=...`.

## Per-customer onboarding

Follow [docs/onboarding-checklist.md](docs/onboarding-checklist.md).

## Next phases (to be designed together)

- GAM: per-customer setup using credentials from the Terraform-built project
- Baseline: org units, groups and aliases, Shared Drives, signatures
- Users from an intake Google Sheet
- Security baseline (API where possible, Admin Console checklist for the rest)
- Backups, Workspace side only: authorize the backup service account in each tenant
- Offboarding
- Static website on Cloudflare Pages
