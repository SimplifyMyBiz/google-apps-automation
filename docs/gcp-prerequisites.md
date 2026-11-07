# GCP prerequisites

The basis for the Terraform in the separate infrastructure repo. This repo never creates GCP resources.

## Status

| Phase | Needs GCP? |
|---|---|
| **Built:** GAM7 install (`bin/00-install-gam.sh`) | No |
| **Built:** Cloudflare DNS (`bin/20-dns-cloudflare.sh`) | No |
| **Not built:** GAM tenant administration | Yes, see below (**proposed**) |
| **Not built:** Backups, Workspace side | Yes, see below (**proposed**) |

Everything below is **proposed**. It's what the GAM and backup phases are expected to need, and it gets confirmed
when those phases are designed. Items marked *verify* are things to check against current GAM7 / Google docs first.

---

## 1. Project

| Item | Value |
|---|---|
| Organization | SimplifyMyCloud GCP org |
| Project | One dedicated project for SMB customer operations (name/ID set by the Terraform) |
| Billing | Linked to a SimplifyMyCloud billing account |
| Customers | Need **no** GCP resources of their own. All customers are served from this one project. |

## 2. APIs to enable (proposed)

For GAM to administer customer tenants:

| API | Used for |
|---|---|
| `admin.googleapis.com` | Admin SDK: users, groups, org units, roles, domains |
| `gmail.googleapis.com` | Signatures, delegation, forwarding, mail settings |
| `drive.googleapis.com` | Shared Drives, file ownership transfer at offboarding |
| `groupssettings.googleapis.com` | Group settings (who can post, external members) |
| `licensing.googleapis.com` | Assigning/removing Workspace licenses |
| `sheets.googleapis.com` | Reading the employee intake Sheet |
| `calendar-json.googleapis.com` | Calendar resources and settings |
| `cloudidentity.googleapis.com` | Some group and device features |
| `iam.googleapis.com`, `iamcredentials.googleapis.com` | Service accounts, keyless signing if used |

*Verify:* compare with the API list GAM7 enables in its own `gam create project` flow, and add anything missing.

For backups (infrastructure is all Terraform): Cloud Storage, Cloud Run, Cloud Scheduler, Secret Manager, Artifact Registry.

## 3. Service accounts (proposed)

Two accounts, so a compromised backup job can only read data and can't administer tenants.

| Service account | Purpose | GCP IAM roles | Workspace access |
|---|---|---|---|
| `gam-admin` | GAM administration of every customer tenant | None needed for Workspace work | Domain-wide delegation granted **in each customer tenant** with admin scopes |
| `backup-reader` | Gmail and Drive backups | Write to that customer's backup bucket only | Domain-wide delegation in each tenant with **read-only** Gmail and Drive scopes |

Domain-wide delegation is granted on the Workspace side, per customer, by this repo's onboarding steps.
GCP only has to provide each account's **unique ID** (the OAuth2 client ID). In Terraform that's
`google_service_account.<name>.unique_id`.

*Verify:* the exact read-only scopes GYB and rclone need for backup-only use.

## 4. Service account keys (decision needed)

GAM, GYB and rclone normally authenticate with a JSON key file.

- Newer orgs enforce the **`iam.disableServiceAccountKeyCreation`** org policy by default. The Terraform must either:
  - add an exception for this one project (`google_org_policy_policy`), or
  - use keyless signing through the IAM Credentials API, if GAM7 supports it for this use. *Verify.*
- If keys are used, **don't create them in Terraform**, because the private key ends up in Terraform state.
  Create them separately and store them in **Secret Manager**. Only the operator gets `secretAccessor`.
- These are the most sensitive credentials in the business, because `gam-admin` is trusted by every customer tenant.

## 5. OAuth client for GAM (proposed)

GAM's administrator sign-in (one sign-in per customer tenant) uses an OAuth client in the same project.

| Item | Value |
|---|---|
| Consent screen user type | **External**, because admins from many customer orgs sign in |
| Publishing status | In production. In "Testing", refresh tokens expire after 7 days. Shows an "unverified app" warning, which is fine for fewer than 100 users. |
| Client type | Desktop app |
| Who creates it | **Probably a manual Console step:** the Terraform Google provider can't create standard Desktop OAuth clients. *Verify.* |

## 6. Backup infrastructure (all Terraform, outline only)

Agreed so far: one GCS bucket per customer in the SMB project, object versioning on, deleted or changed files kept
**90 days**, nightly backups. The jobs run as Cloud Run Jobs started by Cloud Scheduler, using GYB for Gmail and
rclone for Drive. This repo only handles each customer's Workspace side, such as authorizing `backup-reader`.

## 7. Outputs this repo will need from Terraform

| Value | Used by |
|---|---|
| Project ID | GAM config |
| `gam-admin` email + unique ID | GAM config; domain-wide delegation in each tenant |
| `backup-reader` email + unique ID | Domain-wide delegation in each tenant |
| Secret Manager secret names (keys, tokens) | Operator scripts |
| Bucket naming pattern | Backup check scripts |
