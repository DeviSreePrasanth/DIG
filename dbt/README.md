# dbt folder

This is the code the pipeline packages and pushes to Artifact Registry.

The CI workflow does **not** run dbt — it just archives this whole `dbt/`
folder into a `.tar.gz` and uploads it as a versioned artifact into an
Artifact Registry **generic** repository (`dbt-artifacts`). Downstream systems
(Composer/Airflow, Cloud Run, etc.) then pull that artifact by version.

Contents:
- `dbt_project.yml` — project config
- `profiles.example.yml` — example connection profile (local use only)
- `models/staging/stg_customers.sql` — staging model
- `models/marts/customer_summary.sql` — mart model
