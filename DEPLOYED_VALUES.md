# Deployed values (actual resources created)

GCP infrastructure for the WIF POC is live. These are the real IDs.

## Projects
| Env | Project ID | Project number |
|-----|-----------|----------------|
| dev | `dig-dev-poc` | `646296190677` |
| prod | `dig-prod-poc` | `107752456095` |

Billing account linked: `01D097-FAD10A-041E97` (billingEnabled: true on both).

## Artifact Registry (generic, location `us`)
- `us-generic.pkg.dev/dig-dev-poc/dbt-artifacts`
- `us-generic.pkg.dev/dig-prod-poc/dbt-artifacts`

## Service account (single, lives in dig-dev-poc)
- `gha-dbt@dig-dev-poc.iam.gserviceaccount.com`
- Roles in BOTH projects: `roles/artifactregistry.writer`, `roles/storage.objectAdmin`
- Impersonation: `roles/iam.workloadIdentityUser` from both pools' `principalSet` for repo `DeviSreePrasanth/DIG`

## WIF providers (use these in GitHub Actions variables)
| Var | Value |
|-----|-------|
| `DEV_PROJECT_ID` | `dig-dev-poc` |
| `PROD_PROJECT_ID` | `dig-prod-poc` |
| `DEV_WIP` | `projects/646296190677/locations/global/workloadIdentityPools/github-pool/providers/github` |
| `PROD_WIP` | `projects/107752456095/locations/global/workloadIdentityPools/github-pool/providers/github` |
| `SERVICE_ACCOUNT` | `gha-dbt@dig-dev-poc.iam.gserviceaccount.com` |
| `AR_LOCATION` | `us` |

## Trust conditions (attribute-condition on each provider)
- DEV provider trusts: `repository_owner=='DeviSreePrasanth' && repository=='DeviSreePrasanth/DIG' && ref=='refs/heads/main'`
- PROD provider trusts: `repository_owner=='DeviSreePrasanth' && repository=='DeviSreePrasanth/DIG' && ref=='refs/heads/release'`

> Note: the `repository` claim is case-sensitive. The repo must be created as
> `DeviSreePrasanth/DIG` (matching case). If you create it lowercase, update the
> two providers' attribute-conditions accordingly.
