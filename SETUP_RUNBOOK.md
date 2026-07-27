# WIF POC — Setup Runbook

End-to-end manual setup for: **one GitHub repo → two GCP projects (dev/prod) →
one service account impersonated via Workload Identity Federation → pushes the
`dbt/` folder to Artifact Registry.**

- `main` branch  → **dev** project
- `release` branch → **prod** project

Run everything in **Git Bash** (so the `$VARS` and line continuations work).
Commands assume the accounts you gave me:
- GCP user: `venr72480@gmail.com`
- GitHub user/repo owner: `DeviSreePrasanth`

---

## 0. Configuration — set these once per shell session

Pick globally-unique project IDs (lowercase, 6–30 chars). Edit and paste:

```bash
# ---- GitHub ----
export GH_OWNER="DeviSreePrasanth"
export GH_REPO="dsf-wif-poc"          # the NEW repo we create for the POC

# ---- GCP projects (must be globally unique) ----
export DEV_PROJECT="dsf-poc-dev-$RANDOM"
export PROD_PROJECT="dsf-poc-prod-$RANDOM"

# ---- Billing account (see step 2 to find it) ----
export BILLING_ACCOUNT="XXXXXX-XXXXXX-XXXXXX"

# ---- Fixed names used throughout ----
export AR_LOCATION="us"               # Artifact Registry location
export POOL="github-pool"
export PROVIDER="github"
export SA_NAME="gha-dbt"              # single service account (lives in DEV project)
export SA_EMAIL="${SA_NAME}@${DEV_PROJECT}.iam.gserviceaccount.com"
```

> Tip: because these are shell variables, if you open a new terminal you must
> re-export them (or save this block to a `.env` and `source` it).

---

## 1. Prerequisites (one-time)

### 1a. Point gcloud at your personal Google account
gcloud is currently logged in as a corporate account. Switch it:

```bash
gcloud auth login venr72480@gmail.com          # opens a browser
gcloud config set account venr72480@gmail.com
```

### 1b. Install + authenticate GitHub CLI
`gh` is not installed. Install it, then log in as DeviSreePrasanth:

- Windows: `winget install --id GitHub.cli`  (then reopen the terminal)
- Docs: https://cli.github.com/

```bash
gh auth login          # choose GitHub.com > HTTPS > login with browser
gh auth status
```

---

## 2. Create the two GCP projects + link billing

Find your billing account ID and set `BILLING_ACCOUNT` above:

```bash
gcloud billing accounts list
```

> A brand-new gmail has **no** billing account until you add one in the Cloud
> Console (https://console.cloud.google.com/billing) — a card or free-trial
> credit. Project creation for a personal account works without an org.

Create + link + enable APIs for **both** projects:

```bash
for P in "$DEV_PROJECT" "$PROD_PROJECT"; do
  gcloud projects create "$P" --name="$P"
  gcloud billing projects link "$P" --billing-account="$BILLING_ACCOUNT"
  gcloud services enable \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com \
    artifactregistry.googleapis.com \
    storage.googleapis.com \
    --project="$P"
done
```

Capture project **numbers** (needed for the WIF principal strings):

```bash
export DEV_NUM=$(gcloud projects describe "$DEV_PROJECT" --format="value(projectNumber)")
export PROD_NUM=$(gcloud projects describe "$PROD_PROJECT" --format="value(projectNumber)")
echo "DEV_NUM=$DEV_NUM   PROD_NUM=$PROD_NUM"
```

---

## 3. Create the Artifact Registry repos (generic format, one per project)

```bash
for P in "$DEV_PROJECT" "$PROD_PROJECT"; do
  gcloud artifacts repositories create dbt-artifacts \
    --project="$P" \
    --location="$AR_LOCATION" \
    --repository-format="generic" \
    --description="DBT code artifacts (POC)"
done
```

---

## 4. Create the single service account + grant permissions

The SA lives in the **DEV** project but is granted roles in **both** projects.

```bash
gcloud iam service-accounts create "$SA_NAME" \
  --project="$DEV_PROJECT" \
  --display-name="GitHub Actions DBT publisher (POC)"

# Grant Artifact Registry writer + GCS access in BOTH projects
for P in "$DEV_PROJECT" "$PROD_PROJECT"; do
  gcloud projects add-iam-policy-binding "$P" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/artifactregistry.writer"

  gcloud projects add-iam-policy-binding "$P" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectAdmin"
done
```

> Roles granted to the SA: **Artifact Registry Writer** and **Storage Object
> Admin (GCS)**. "WIF permission" is not a role the SA *holds* — it's the
> `workloadIdentityUser` binding put ON the SA in step 6, which lets GitHub
> impersonate it.

---

## 5. Create the WIF pool + provider in BOTH projects

The `--attribute-condition` is the security gate. Note the branch differs:
dev provider trusts **main**, prod provider trusts **release**.

### DEV project (trusts `main`)

```bash
gcloud iam workload-identity-pools create "$POOL" \
  --project="$DEV_PROJECT" --location="global" \
  --display-name="GitHub Actions pool"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --project="$DEV_PROJECT" --location="global" \
  --workload-identity-pool="$POOL" \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository_owner=='${GH_OWNER}' && assertion.repository=='${GH_OWNER}/${GH_REPO}' && assertion.ref=='refs/heads/main'"
```

### PROD project (trusts `release`)

```bash
gcloud iam workload-identity-pools create "$POOL" \
  --project="$PROD_PROJECT" --location="global" \
  --display-name="GitHub Actions pool"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --project="$PROD_PROJECT" --location="global" \
  --workload-identity-pool="$POOL" \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository_owner=='${GH_OWNER}' && assertion.repository=='${GH_OWNER}/${GH_REPO}' && assertion.ref=='refs/heads/release'"
```

Capture the full provider resource names (these go into GitHub as variables):

```bash
export DEV_WIP=$(gcloud iam workload-identity-pools providers describe "$PROVIDER" \
  --project="$DEV_PROJECT" --location="global" --workload-identity-pool="$POOL" \
  --format="value(name)")

export PROD_WIP=$(gcloud iam workload-identity-pools providers describe "$PROVIDER" \
  --project="$PROD_PROJECT" --location="global" --workload-identity-pool="$POOL" \
  --format="value(name)")

echo "DEV_WIP=$DEV_WIP"
echo "PROD_WIP=$PROD_WIP"
```

---

## 6. Let each pool impersonate the single service account

Two bindings, both ON the SA (which lives in the DEV project), one referencing
the DEV pool and one the PROD pool:

```bash
# DEV pool -> SA
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$DEV_PROJECT" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${DEV_NUM}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${GH_OWNER}/${GH_REPO}"

# PROD pool -> SA
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$DEV_PROJECT" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROD_NUM}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${GH_OWNER}/${GH_REPO}"
```

---

## 7. Create the GitHub repo, push the POC, set variables

From inside the `wif-dbt-poc` folder I generated:

```bash
cd "wif-dbt-poc"

git init -b main
git add .
git commit -m "WIF POC: dbt folder + publish workflow"

# Create the repo on GitHub and push main
gh repo create "${GH_OWNER}/${GH_REPO}" --private --source=. --remote=origin --push

# Create the release (prod) branch
git checkout -b release
git push -u origin release
git checkout main
```

Set the repo-level Actions **Variables** the workflow reads:

```bash
gh variable set DEV_PROJECT_ID  --repo "${GH_OWNER}/${GH_REPO}" --body "$DEV_PROJECT"
gh variable set PROD_PROJECT_ID --repo "${GH_OWNER}/${GH_REPO}" --body "$PROD_PROJECT"
gh variable set DEV_WIP         --repo "${GH_OWNER}/${GH_REPO}" --body "$DEV_WIP"
gh variable set PROD_WIP        --repo "${GH_OWNER}/${GH_REPO}" --body "$PROD_WIP"
gh variable set SERVICE_ACCOUNT --repo "${GH_OWNER}/${GH_REPO}" --body "$SA_EMAIL"
gh variable set AR_LOCATION     --repo "${GH_OWNER}/${GH_REPO}" --body "$AR_LOCATION"
```

(Optional, recommended) Protect prod: **GitHub → Settings → Environments → New
environment `prod` → add yourself as a required reviewer.** Now every `release`
push pauses for approval before it can touch the prod project.

---

## 8. Test

- **Dev:** make any small change on `main`, commit, push. The workflow runs,
  authenticates via the **dev** provider, and uploads to `dbt-artifacts` in the
  **dev** project.
- **Prod:** merge `main` into `release` and push. The workflow authenticates via
  the **prod** provider and uploads to the **prod** project (after approval if
  you set up the environment).

Verify the artifact landed:

```bash
gcloud artifacts versions list \
  --project="$DEV_PROJECT" --location="$AR_LOCATION" \
  --repository="dbt-artifacts" --package="dsf-dbt"
```

You can watch the run with: `gh run watch --repo "${GH_OWNER}/${GH_REPO}"`

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Permission 'iam.serviceAccounts.getAccessToken' denied` | The `workloadIdentityUser` binding (step 6) is missing or the `principalSet` doesn't match. Check project **number** and repo name. |
| `Unable to acquire impersonated credentials` / condition failed | Attribute condition (step 5) rejected the token — wrong branch, repo, or owner. Confirm the branch matches the provider (main↔dev, release↔prod). |
| `PERMISSION_DENIED` on upload | SA missing `artifactregistry.writer` in that project (step 4), or the repo/location name is wrong. |
| Billing / `FAILED_PRECONDITION` on project create | No billing account linked — do step 2 in the Console first. |
| Workflow can't find `vars.DEV_WIP` etc. | Variables not set (step 7) or set as *secrets* instead of *variables*. |

---

## What connects to what (recap)

```
GitHub push (main/release)
   └─ OIDC token (repo + branch claims)
        └─ WIF provider in matching project  (validates owner+repo+branch)
             └─ pool principal  ──(workloadIdentityUser)──►  gha-dbt SA
                  └─ SA token with AR-writer + GCS in that project
                       └─ gcloud artifacts generic upload  →  dbt-artifacts
```
