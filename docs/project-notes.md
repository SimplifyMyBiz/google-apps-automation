# Project notes

## Purpose

SimplifyMyBiz (SMB, simplifymy.biz) sets up and runs Google Workspace plus a simple static website for small
businesses (10–20 people), so they can focus on their business instead of the tech. Its GCP side lives in the
SimplifyMyCloud GCP org.

This repo automates **onboarding customers onto Google Workspace and Cloudflare**. simplifymy.biz itself is the first customer.

## Scope

| In scope (this repo) | Out of scope |
|---|---|
| Cloudflare DNS for Workspace (MX, SPF, DKIM, DMARC, verification) | GCP infrastructure: project, service accounts, buckets, Cloud Run (separate Terraform repo) |
| GAM-driven tenant setup: users, groups, OUs, Shared Drives, signatures, security, offboarding | Workspace signup and billing (manual, customer's card) |
| Workspace side of backups (authorizing the backup service account) | Customer devices: MacBooks and iPhones are the customer's own responsibility |
| Static website on Cloudflare Pages | Domain purchase (Cloudflare Registrar, before onboarding) |

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Business model | MSP, many small customers | Repeatable setup per customer |
| Who pays Google | The customer, directly | The customer clearly owns the tenant and data, and no reseller status is needed |
| Admin of each tenant | SMB as super-admin: `smb-admin@<domain>`, plus emergency super-admin `smb-defcon@<domain>` | The customer doesn't have to manage it |
| Workspace admin tool | GAM7 + shell scripts | Covers almost all tasks, free, built for many tenants, reads Google Sheets |
| GCP | One dedicated project in the SimplifyMyCloud org, built by separate Terraform | Simple. Customers need no GCP. |
| DNS and registrar | Cloudflare. Domains bought through Cloudflare Registrar and kept in SMB's Cloudflare account. | One API token covers all customers |
| Employee list | A Google Sheet per customer ([intake-sheet.md](intake-sheet.md)) | Easy for the customer to fill in |
| Initial passwords | Random, change at first login, emailed to a personal address | |
| Default plan | Business Starter | Typical customer |
| Backups | Per-customer GCS bucket, nightly, 90-day versioning, GYB + rclone on Cloud Run Jobs | Infrastructure in Terraform; this repo does the Workspace side |
| DMARC reports | Cloudflare DMARC Management, per zone | Free, readable, no mailbox needed |
| Website | Cloudflare Pages, deployed from **one GitHub repo per customer** in the [SimplifyMyBiz GitHub org](https://github.com/SimplifyMyBiz) | Free, already on Cloudflare, each push deploys |

## Conventions

- **Config as files:** `config/smb.env` (MSP-wide) and `customers/<slug>/customer.env`. Both are gitignored; only templates are committed.
- **Safe to re-run:** scripts check current state first and only change what differs.
- **`DRY_RUN=1`** on every script prints the planned changes without making them.
- **Never overwrite silently:** existing MX, SPF or DMARC report settings that aren't ours are left alone with a warning, unless a flag says otherwise.
- **No gcloud calls and no GCP resource creation** in this repo.
- Script numbering (`00-`, `20-`, ...) reflects run order. Gaps leave room for later phases.

## Security notes

- The `gam-admin` service account will be trusted by every customer tenant. It's the most sensitive credential in the business. See [gcp-prerequisites.md](gcp-prerequisites.md#4-service-account-keys-decision-needed).
- Super-admin accounts use hardware security keys. `smb-defcon@` is stored offline and never used day to day.
- Some security settings, such as **enforcing** 2-Step Verification and generating DKIM keys, have no Google API.
  They stay manual Admin Console steps in the checklist.
- The intake Sheet holds employees' personal email addresses and phone numbers. Share it narrowly.

## Known limits

- **No tenant creation by API.** Without Google Reseller status, Workspace signup is manual.
- **Business Starter:** no Vault. Shared Drives availability on Starter has changed over time, so check each tenant.
- **GAM runs commands, it doesn't compare against a desired state.** Our scripts add the check-then-change logic.
- **Your `gam` alias:** oh-my-zsh's git plugin aliases `gam` to `git am`. The installer prints the fix.

## Current status

| Item | State |
|---|---|
| `bin/00-install-gam.sh` | Written. Dry run selected the correct macOS arm64 build. Not run for real. |
| `bin/20-dns-cloudflare.sh` | Written. Tested only against a fake Cloudflare API, not against real Cloudflare. DMARC change not tested yet. |
| simplifymy.biz | Registered at Gandi until the 60-day transfer lock ends, then moves to Cloudflare Registrar. DNS is already on Cloudflare. Old Gandi MX/SPF records get replaced during onboarding. |
| GAM, baseline, users, security, backups (Workspace side), offboarding, website | Not built |
| Docs | This folder. The intake Sheet columns are a draft for review. |

## Open questions

1. **GAM credentials flow:** exact Terraform outputs, key versus keyless, how GAM gets them.
2. **Intake Sheet:** confirm the draft columns in [intake-sheet.md](intake-sheet.md).
3. **Website repos:** repo naming in the SimplifyMyBiz org (for example `<slug>-website`), and who can push to them.
