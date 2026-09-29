# Guestbook

A tiny Flask + PostgreSQL app used in the OpenShift fundamentals demo.

- **New version:** change `VERSION = "1.0"` in `app.py` and commit. The webhook starts the OpenShift pipeline, which builds and rolls out the new image.
- **Banner color / title:** set the `APP_COLOR` / `APP_TITLE` environment variables on the Deployment.
- **Database:** `POSTGRESQL_USER`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_DATABASE` (from the `guestbook-db` secret); `DB_HOST` defaults to `postgresql`.
- **Health:** `/healthz` (liveness), `/readyz` (readiness - checks the database).
