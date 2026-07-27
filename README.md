# DSF WIF POC

Proof-of-concept: a single GitHub repo that publishes its `dbt/` folder to
Google Artifact Registry using **Workload Identity Federation** — no service
account keys.

## Design

- **1 GitHub repo**, two branches:
  - `main`    → **dev** GCP project
  - `release` → **prod** GCP project
- **2 GCP projects** (dev + prod), each with:
  - a Workload Identity **pool + provider** trusting GitHub OIDC (scoped to this
    repo + the matching branch)
  - an Artifact Registry **generic** repo `dbt-artifacts`
- **1 service account** (`gha-dbt`, lives in the dev project) impersonated from
  both pools, granted **Artifact Registry Writer** + **Storage Object Admin**
  in both projects.

```
GitHub push (main/release)
   → OIDC token (repo + branch)
   → WIF provider in matching project (validates owner + repo + branch)
   → impersonate gha-dbt service account
   → gcloud artifacts generic upload  →  dbt-artifacts
```

## Contents

| Path | What it is |
|---|---|
| `dbt/` | The dbt project that gets packaged and pushed |
| `.github/workflows/deploy-dbt.yml` | CI: auth via WIF + upload dbt to Artifact Registry |
| `SETUP_RUNBOOK.md` | **Start here** — every gcloud/gh command to stand this up |
| `.gitignore` | Ignores dbt build output + local artifacts |

## How to use

1. Follow **[SETUP_RUNBOOK.md](SETUP_RUNBOOK.md)** top to bottom (creates the
   GCP projects, WIF, service account, and this GitHub repo).
2. Push to `main` → artifact lands in the dev project.
3. Push to `release` → artifact lands in the prod project.

## Security notes

- No SA JSON keys anywhere. GitHub mints a short-lived OIDC token per run.
- Each provider's attribute condition restricts trust to **this repo + one
  branch + your org**.
- With a single shared SA, the branch/repo checks gate *authentication*; the SA
  token itself can reach both projects. Protect the `prod` GitHub Environment
  with a required reviewer so prod pushes need approval (see runbook step 7).
