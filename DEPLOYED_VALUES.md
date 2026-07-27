# Deployed values (centralized DSF hub architecture)

All WIF + Artifact Registry live in the **DSF hub** projects. App projects
(`dig-*`, `etp-*`) hold no WIF/AR — they are where app runtime would live later.

## Hub projects (hold WIF + Artifact Registry)
| Env | Project ID | Project number |
|-----|-----------|----------------|
| dev | `dsf-dev-poc` | `637530616995` |
| prod | `dsf-prod-poc` | `1083911620746` |

Billing account: `01D097-FAD10A-041E97`.

## App projects (placeholders, billing unlinked in POC)
`dig-dev-poc`, `dig-prod-poc`, `etp-dev-poc`, `etp-prod-poc`

## Artifact Registry (generic, location `us`) — all in the hub
| Repo | dev | prod |
|------|-----|------|
| DIG dbt | `us-generic.pkg.dev/dsf-dev-poc/dig-dbt` | `us-generic.pkg.dev/dsf-prod-poc/dig-dbt` |
| ETP dbt | `us-generic.pkg.dev/dsf-dev-poc/etp-dbt` | `us-generic.pkg.dev/dsf-prod-poc/etp-dbt` |

## Central service account (single, in dsf-dev-poc)
- `gha-publisher@dsf-dev-poc.iam.gserviceaccount.com`
- Roles in BOTH hub projects: `roles/artifactregistry.writer`, `roles/storage.objectAdmin`
- Impersonation (`workloadIdentityUser`) from both hub pools, for repos `DeviSreePrasanth/DIG` and `DeviSreePrasanth/ETP`

## WIF providers (used by both DIG and ETP workflows)
| Var | Value |
|-----|-------|
| `DEV_WIP` | `projects/637530616995/locations/global/workloadIdentityPools/github-pool/providers/github` |
| `PROD_WIP` | `projects/1083911620746/locations/global/workloadIdentityPools/github-pool/providers/github` |
| `SERVICE_ACCOUNT` | `gha-publisher@dsf-dev-poc.iam.gserviceaccount.com` |

## Trust conditions (attribute-condition per provider)
- dev provider (dsf-dev-poc): `repository_owner=='DeviSreePrasanth' && repository in ['DeviSreePrasanth/DIG','DeviSreePrasanth/ETP'] && ref=='refs/heads/main'`
- prod provider (dsf-prod-poc): `... && ref=='refs/heads/release'`

## Per-repo workflow setting
Each app repo's workflow sets `AR_REPO` to its own hub repo:
- DIG → `AR_REPO: dig-dbt`
- ETP → `AR_REPO: etp-dbt`
