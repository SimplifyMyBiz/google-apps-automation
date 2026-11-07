# New customer onboarding checklist

Covers Google Workspace + Cloudflare. Steps that aren't built yet are marked **(later phase)**.

## Assumed starting point

Before this checklist starts, all of these are true:

- [ ] The customer's domain was **bought through Cloudflare Registrar in SimplifyMyBiz's Cloudflare account**.
      That means DNS is already on Cloudflare and the SMB API token can reach the zone.
- [ ] **Google Workspace signup is complete** for that domain:
  - [ ] The tenant exists on the agreed plan (usually **Business Starter**).
  - [ ] SMB's super-admin `smb-admin@<domain>` was created during signup.
  - [ ] The **customer's** payment method is on the Workspace subscription.
- [ ] Nothing else has been set up in the tenant or in DNS beyond what Cloudflare Registrar and the signup created.

If the domain isn't verified yet at the end of signup, that happens in step 3 below.

## One-time, per operator Mac

- [ ] Install GAM7: `bin/00-install-gam.sh`, then fix the `gam` alias as the script tells you.
- [ ] `cp config/smb.env.example config/smb.env`.
- [ ] Cloudflare API token created (see [configuration.md](configuration.md)) and exported as `CLOUDFLARE_API_TOKEN`.

## Per customer

### 1. Secure the super-admin
- [ ] Sign in as `smb-admin@<domain>` and enroll **2-Step Verification with a hardware security key**.
- [ ] Create the **emergency** super-admin `smb-defcon@<domain>`. Give it a strong password and its own
      security key, and keep both in the password manager / safe. Don't use it day to day.
- [ ] Save both account names in the password manager entry for this customer.

### 2. Create the customer config
- [ ] `cp -R customers/_template customers/<slug>`
- [ ] Fill in `customers/<slug>/customer.env`. Leave `DMARC_RUA` blank for now.

### 3. Email DNS records
- [ ] Dry run first and read every line of output:
      `DRY_RUN=1 bin/20-dns-cloudflare.sh <slug> [--verify "google-site-verification=..."]`
- [ ] If it warns about existing MX or SPF records (for example a "no email" `v=spf1 -all` record Cloudflare
      can add to new domains), confirm they aren't needed. Only then add `--replace-mx` / `--replace-spf`.
- [ ] Run it for real with the same options.
- [ ] If the domain wasn't verified yet: click **Verify** in the Workspace setup.

### 4. DKIM
- [ ] Admin Console → Apps → Google Workspace → Gmail → **Authenticate email** → Generate new record (2048-bit, prefix `google`).
- [ ] `bin/20-dns-cloudflare.sh <slug> --dkim "v=DKIM1; k=rsa; p=..."`
- [ ] Wait for DNS (usually minutes, at most 48 hours), then click **Start authentication**. It should show "Authenticating email".

### 5. DMARC reporting
- [ ] Cloudflare → domain → Email → **DMARC Management** → Enable.
- [ ] Copy the `rua` report address Cloudflare shows into `DMARC_RUA` in `customer.env`.
- [ ] Re-run `bin/20-dns-cloudflare.sh <slug>`. It should report the DMARC record as `OK`, or update it to include the address.

### 6. Check mail works
- [ ] Google Admin Toolbox **Check MX** (toolbox.googleapps.com) for the domain: no errors.
- [ ] Send mail from the new account to an outside Gmail address → **Show original** → SPF, DKIM and DMARC all `PASS`.
- [ ] Send mail from outside to the new account and confirm it arrives.

### 7. Later phases (not built yet)
- [ ] GAM: authorize `gam-admin` (domain-wide delegation) and run the one-time GAM sign-in for this tenant **(later phase)**
- [ ] Baseline: org units, groups and aliases, Shared Drives if the plan includes them, signatures **(later phase)**
- [ ] Users from the intake Sheet, random password + change at first login, emailed to a personal address **(later phase)**
- [ ] Security baseline, including the Admin Console checklist for settings with no API **(later phase)**
- [ ] Backups: authorize `backup-reader` (domain-wide delegation) and confirm the first backup **(later phase)**
- [ ] Static website on Cloudflare Pages **(later phase)**

### 8. Follow-up after 2–4 weeks
- [ ] Review DMARC Management reports. Every legitimate sender (Workspace, website forms, invoicing tools) should pass.
- [ ] Then set `DMARC_POLICY="quarantine"` and re-run the DNS script. Move to `reject` once that's been clean for a while.
