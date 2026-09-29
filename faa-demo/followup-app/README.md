# Follow-ups

The "parking lot" for questions and follow-up points raised during a demo
session. The Q&A slide of each deck links here (with `?session=<demo>`) and
shows a QR code for the audience.

- Stored in SQLite on a PVC (`/data`). One replica only.
- `/export.md[?session=...]` downloads the list as Markdown.
- Deployed to the `faa-demo` namespace by `faa-demo/playbook.yml`; the source
  is pushed to Gitea (`ocpdemo/faa-followups`) and built by a pipeline.
