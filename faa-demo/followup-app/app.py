"""Follow-ups - the "parking lot" for questions and follow-up points raised
during a demo session. Opened from the Q&A slide (or its QR code), in the
presenter's browser or on the audience's phones.

Items are stored in SQLite on a persistent volume (DATA_DIR). /export.md
downloads them as Markdown, to keep with the session notes.
"""
import datetime as dt
import os
import sqlite3

from flask import Flask, Response, g, redirect, render_template, request, url_for

DATA_DIR = os.getenv("DATA_DIR", "/data")
DB_PATH = os.path.join(DATA_DIR, "followups.db")

app = Flask(__name__)


def db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    conn = g.pop("db", None)
    if conn is not None:
        conn.close()


def init_db():
    os.makedirs(DATA_DIR, exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS followups (
                   id      INTEGER PRIMARY KEY AUTOINCREMENT,
                   session TEXT NOT NULL DEFAULT '',
                   text    TEXT NOT NULL,
                   who     TEXT NOT NULL DEFAULT '',
                   done    INTEGER NOT NULL DEFAULT 0,
                   created TEXT NOT NULL)"""
        )


init_db()


def items(session):
    sql = "SELECT * FROM followups"
    args = ()
    if session:
        sql += " WHERE session = ?"
        args = (session,)
    return db().execute(sql + " ORDER BY done, id DESC", args).fetchall()


def sessions():
    rows = db().execute(
        "SELECT session, COUNT(*) AS n FROM followups GROUP BY session ORDER BY session"
    ).fetchall()
    return [(r["session"], r["n"]) for r in rows]


@app.route("/")
def index():
    session = request.args.get("session", "").strip()
    return render_template(
        "index.html", session=session, items=items(session), sessions=sessions()
    )


@app.post("/add")
def add():
    session = request.form.get("session", "").strip()[:80]
    text = request.form.get("text", "").strip()[:1000]
    who = request.form.get("who", "").strip()[:80]
    if text:
        db().execute(
            "INSERT INTO followups (session, text, who, created) VALUES (?, ?, ?, ?)",
            (session, text, who, dt.datetime.now().isoformat(timespec="seconds")),
        )
        db().commit()
    return redirect(url_for("index", session=session or None))


@app.post("/toggle/<int:item_id>")
def toggle(item_id):
    db().execute("UPDATE followups SET done = 1 - done WHERE id = ?", (item_id,))
    db().commit()
    return redirect(url_for("index", session=request.form.get("session") or None))


@app.get("/export.md")
def export():
    session = request.args.get("session", "").strip()
    title = f"Follow-ups: {session}" if session else "Follow-ups"
    lines = [f"# {title}", "", f"Exported {dt.date.today().isoformat()}", ""]
    for row in items(session):
        box = "x" if row["done"] else " "
        who = f" ({row['who']})" if row["who"] else ""
        tag = f" `{row['session']}`" if not session and row["session"] else ""
        lines.append(f"- [{box}] {row['text']}{who}{tag}")
    name = f"followups-{session or 'all'}.md"
    return Response(
        "\n".join(lines) + "\n",
        mimetype="text/markdown",
        headers={"Content-Disposition": f'attachment; filename="{name}"'},
    )


@app.get("/healthz")
def healthz():
    db().execute("SELECT 1")
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
