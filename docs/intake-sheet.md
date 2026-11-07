# Employee intake Sheet

**Status: draft for review.** One Google Sheet per customer, filled in by the customer (or SMB with them),
read by the user-creation script (later phase). Its ID goes in `INTAKE_SHEET_ID` in `customer.env`.

One row per employee. The first row holds exactly these column names.

## Columns

| Column | Required | What to enter | Example | Used for |
|---|---|---|---|---|
| `first_name` | Yes | Given name | `Jane` | Account name |
| `last_name` | Yes | Family name | `Doe` | Account name |
| `work_email` | Yes | The new Workspace address to create | `jane@acmeplumbing.com` | The account itself |
| `personal_email` | Yes | The employee's own, non-work address | `jane.doe@gmail.com` | Where the temporary password is sent; account recovery email |
| `mobile_phone` | Yes | Mobile number with country code | `+15551234567` | Phone on the user profile; account recovery phone |
| `job_title` | Yes | Their role in the business | `Office Manager` | Title on the profile and in the email signature |
| `department` | No | Team or area | `Operations` | Profile; later possibly org unit and department group |
| `manager_email` | No | Work email of their manager | `bob@acmeplumbing.com` | Profile (shows in the directory) |

## Rules

- Phone numbers need the country code (`+1...`), so they work as recovery numbers.
- `work_email` must be on the customer's domain, and each address appears once.
- The script only **creates** users that don't exist yet. Existing users are reported, not changed.
- The Sheet holds personal data: share it only with the customer's owner and SMB, not company-wide.
