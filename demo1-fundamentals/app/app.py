"""Guestbook - a tiny Flask + PostgreSQL app for the OpenShift fundamentals demo.

What it shows on every page:
  * VERSION      - change this line and rebuild to demo a new release
  * pod name     - proves load balancing across replicas
  * APP_COLOR    - banner colour from the environment (config change demo)
  * DB status    - which database host the pod talks to
"""
import os
import socket

import psycopg
from flask import Flask, redirect, render_template, request, url_for

VERSION = "1.0"

app = Flask(__name__)

DB_DSN = (
    f"host={os.getenv('DB_HOST', 'postgresql')} "
    f"port={os.getenv('DB_PORT', '5432')} "
    f"dbname={os.getenv('POSTGRESQL_DATABASE', 'guestbook')} "
    f"user={os.getenv('POSTGRESQL_USER', 'guestbook')} "
    f"password={os.getenv('POSTGRESQL_PASSWORD', '')} "
    "connect_timeout=3"
)


def db():
    return psycopg.connect(DB_DSN, autocommit=True)


def init_db():
    with db() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS entries (
                   id      SERIAL PRIMARY KEY,
                   name    TEXT NOT NULL,
                   message TEXT NOT NULL,
                   pod     TEXT NOT NULL,
                   version TEXT NOT NULL,
                   created TIMESTAMPTZ NOT NULL DEFAULT now())"""
        )


@app.route("/")
def index():
    entries, error = [], None
    try:
        init_db()
        with db() as conn:
            entries = conn.execute(
                "SELECT name, message, pod, version, created "
                "FROM entries ORDER BY created DESC LIMIT 50"
            ).fetchall()
    except Exception as exc:  # show the failure instead of a 500 - it's a demo
        error = str(exc)
    return render_template(
        "index.html",
        version=VERSION,
        pod=socket.gethostname(),
        color=os.getenv("APP_COLOR", "#cc0000"),
        title=os.getenv("APP_TITLE", "OpenShift Guestbook"),
        db_host=os.getenv("DB_HOST", "postgresql"),
        entries=entries,
        error=error,
    )


@app.post("/sign")
def sign():
    name = request.form.get("name", "").strip()[:60] or "anonymous"
    message = request.form.get("message", "").strip()[:280]
    if message:
        with db() as conn:
            conn.execute(
                "INSERT INTO entries (name, message, pod, version) VALUES (%s, %s, %s, %s)",
                (name, message, socket.gethostname(), VERSION),
            )
    return redirect(url_for("index"))


@app.route("/healthz")
def healthz():
    """Liveness: the process is up."""
    return {"status": "ok", "version": VERSION, "pod": socket.gethostname()}


@app.route("/readyz")
def readyz():
    """Readiness: only take traffic when the database is reachable."""
    try:
        with db() as conn:
            conn.execute("SELECT 1")
        return {"status": "ready"}
    except Exception as exc:
        return {"status": "not ready", "error": str(exc)}, 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
