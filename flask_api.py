import sqlite3
import threading
import traceback
import uuid
from datetime import datetime

from flask import Flask, jsonify, request

from all_clawler.db import DB_PATH, init_db
from all_clawler.main import run_all_crawlers

app = Flask(__name__)
app.config["JSON_AS_ASCII"] = False
app.json.ensure_ascii = False

JOBS = {}
JOBS_LOCK = threading.Lock()
CRAWL_LOCK = threading.Lock()
MAX_JOBS = 20


@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    return response


@app.route("/", methods=["GET"])
def api_index():
    return jsonify({
        "ok": True,
        "name": "Rental crawler API",
        "endpoints": {
            "health": "/api/health",
            "start_crawl": "POST /api/crawl",
            "latest_crawl": "/api/crawl/latest",
            "crawl_status": "/api/crawl/<job_id>",
            "houses": "/api/houses",
            "house_detail": "/api/houses/<id>",
            "house_stats": "/api/houses/stats",
        },
    })


@app.route("/api/health", methods=["GET"])
def health_check():
    init_db()
    return jsonify({
        "ok": True,
        "db_path": DB_PATH,
        "time": _now_text(),
    })


@app.route("/api/crawl", methods=["POST", "OPTIONS"])
def crawl_houses():
    if request.method == "OPTIONS":
        return ("", 204)

    payload = request.get_json(silent=True) or {}
    config, errors = _build_crawl_config(payload)

    if errors:
        return jsonify({
            "ok": False,
            "errors": errors,
        }), 400

    job_id = uuid.uuid4().hex
    job = {
        "id": job_id,
        "status": "pending",
        "config": config,
        "result": None,
        "error": None,
        "progress": {
            "current": 0,
            "total": 0,
            "percent": 0,
            "source": "",
            "message": "等待開始",
        },
        "created_at": _now_text(),
        "started_at": None,
        "finished_at": None,
    }

    with JOBS_LOCK:
        active_job = _get_active_job_locked()
        if active_job:
            return jsonify({
                "ok": False,
                "error": "crawler_is_running",
                "job": active_job.copy(),
            }), 409

        _trim_jobs_locked()
        JOBS[job_id] = job
        response_job = job.copy()

    thread = threading.Thread(
        target=_run_crawl_job,
        args=(job_id, config),
        daemon=True,
    )
    thread.start()

    response = jsonify({
        "ok": True,
        "job": response_job,
    })
    response.status_code = 202
    response.headers["Location"] = f"/api/crawl/{job_id}"
    return response


@app.route("/api/crawl/latest", methods=["GET"])
def get_latest_crawl_job():
    with JOBS_LOCK:
        if not JOBS:
            return jsonify({
                "ok": True,
                "job": None,
            })

        job = max(JOBS.values(), key=lambda item: item["created_at"]).copy()

    return jsonify({
        "ok": True,
        "job": job,
    })


@app.route("/api/crawl/<job_id>", methods=["GET"])
def get_crawl_job(job_id):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if job:
            job = job.copy()

    if not job:
        return jsonify({
            "ok": False,
            "error": "job_not_found",
        }), 404

    return jsonify({
        "ok": True,
        "job": job,
    })


@app.route("/api/houses", methods=["GET"])
def get_houses():
    city = (request.args.get("city") or "").strip()
    district = (request.args.get("district") or "").strip()
    source = (request.args.get("source") or "").strip()
    keyword = (request.args.get("keyword") or "").strip()
    limit = _parse_int(request.args.get("limit"), default=100, minimum=1, maximum=500)
    offset = _parse_int(request.args.get("offset"), default=0, minimum=0, maximum=1000000)

    init_db()

    where_sql, params = _build_house_filters(
        city=city,
        district=district,
        source=source,
        keyword=keyword,
    )

    sql = f"""
    SELECT *
    FROM houses
    {where_sql}
    ORDER BY id DESC
    LIMIT ? OFFSET ?
    """
    page_params = params + [limit, offset]

    count_sql = f"""
    SELECT COUNT(*) AS total
    FROM houses
    {where_sql}
    """

    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(sql, page_params).fetchall()
        total = conn.execute(count_sql, params).fetchone()["total"]

    return jsonify({
        "ok": True,
        "items": [dict(row) for row in rows],
        "total": total,
        "limit": limit,
        "offset": offset,
        "filters": {
            "city": city,
            "district": district,
            "source": source,
            "keyword": keyword,
        },
    })


@app.route("/api/houses/stats", methods=["GET"])
def get_house_stats():
    init_db()

    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        conn.row_factory = sqlite3.Row
        total = conn.execute("SELECT COUNT(*) AS total FROM houses").fetchone()["total"]
        by_source = conn.execute("""
            SELECT COALESCE(NULLIF(來源, ''), '未分類') AS source, COUNT(*) AS count
            FROM houses
            GROUP BY COALESCE(NULLIF(來源, ''), '未分類')
            ORDER BY count DESC, source ASC
        """).fetchall()
        by_city = conn.execute("""
            SELECT COALESCE(NULLIF(縣市, ''), '未分類') AS city, COUNT(*) AS count
            FROM houses
            GROUP BY COALESCE(NULLIF(縣市, ''), '未分類')
            ORDER BY count DESC, city ASC
        """).fetchall()
        by_district = conn.execute("""
            SELECT COALESCE(NULLIF(地區, ''), '未分類') AS district, COUNT(*) AS count
            FROM houses
            GROUP BY COALESCE(NULLIF(地區, ''), '未分類')
            ORDER BY count DESC, district ASC
        """).fetchall()

    return jsonify({
        "ok": True,
        "total": total,
        "by_source": [dict(row) for row in by_source],
        "by_city": [dict(row) for row in by_city],
        "by_district": [dict(row) for row in by_district],
    })


@app.route("/api/houses/<int:house_id>", methods=["GET"])
def get_house_detail(house_id):
    init_db()

    with sqlite3.connect(DB_PATH, timeout=30) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM houses WHERE id = ?",
            (house_id,),
        ).fetchone()

    if not row:
        return jsonify({
            "ok": False,
            "error": "house_not_found",
        }), 404

    return jsonify({
        "ok": True,
        "item": dict(row),
    })


def _build_crawl_config(payload):
    errors = []

    city = str(payload.get("city") or "台中").strip()
    area_name = str(payload.get("district") or payload.get("area_name") or "").strip()
    kind_text = str(payload.get("kind_text") or "獨立套房").strip()
    min_price = _parse_int(payload.get("min_price"), default=5000, minimum=0, maximum=1000000)
    max_price = _parse_int(payload.get("max_price"), default=10000, minimum=0, maximum=1000000)
    max_pages = _parse_int(payload.get("max_pages"), default=3, minimum=1, maximum=20)

    if not city:
        errors.append("city is required")

    if min_price > max_price:
        errors.append("min_price cannot be greater than max_price")

    config = {
        "city": city,
        "area_name": area_name,
        "kind_text": kind_text,
        "min_price": str(min_price),
        "max_price": str(max_price),
        "max_pages": max_pages,
        "subsidy": _parse_bool(payload.get("subsidy", False)),
    }

    config["keyword"] = str(payload.get("keyword") or " ".join(
        part for part in [config["city"], config["area_name"], config["kind_text"]] if part
    )).strip()

    return config, errors


def _build_house_filters(city="", district="", source="", keyword=""):
    conditions = []
    params = []

    if city:
        conditions.append("縣市 LIKE ?")
        params.append(f"%{city}%")

    if district:
        conditions.append("地區 LIKE ?")
        params.append(f"%{district}%")

    if source:
        conditions.append("來源 = ?")
        params.append(source)

    if keyword:
        conditions.append("(標題 LIKE ? OR 地址 LIKE ? OR 房型 LIKE ?)")
        params.extend([f"%{keyword}%", f"%{keyword}%", f"%{keyword}%"])

    if not conditions:
        return "", params

    return " WHERE " + " AND ".join(conditions), params


def _run_crawl_job(job_id, config):
    with CRAWL_LOCK:
        _update_job(
            job_id,
            status="running",
            started_at=_now_text(),
            progress={
                "current": 0,
                "total": 0,
                "percent": 0,
                "source": "",
                "message": "爬蟲啟動中",
            },
        )

        try:
            result = run_all_crawlers(
                config,
                progress_callback=lambda progress: _update_job_progress(
                    job_id,
                    progress,
                ),
            )
        except Exception as exc:
            _update_job(
                job_id,
                status="failed",
                error={
                    "message": str(exc),
                    "traceback": traceback.format_exc(),
                },
                progress={
                    "current": 0,
                    "total": 0,
                    "percent": 0,
                    "source": "",
                    "message": f"爬蟲失敗：{exc}",
                },
                finished_at=_now_text(),
            )
            return

        _update_job(
            job_id,
            status="done",
            result=result,
            progress={
                "current": 1,
                "total": 1,
                "percent": 100,
                "source": "",
                "message": "爬蟲完成",
            },
            finished_at=_now_text(),
        )


def _update_job(job_id, **changes):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if job:
            job.update(changes)


def _update_job_progress(job_id, progress):
    total = max(int(progress.get("total") or 0), 0)
    current = max(int(progress.get("current") or 0), 0)
    percent = int((current / total) * 100) if total else 0
    percent = max(0, min(percent, 100))

    _update_job(
        job_id,
        progress={
            "current": current,
            "total": total,
            "percent": percent,
            "source": str(progress.get("source") or ""),
            "message": str(progress.get("message") or ""),
        },
    )


def _get_active_job_locked():
    for job in JOBS.values():
        if job["status"] in {"pending", "running"}:
            return job

    return None


def _trim_jobs_locked():
    if len(JOBS) < MAX_JOBS:
        return

    sorted_jobs = sorted(JOBS.values(), key=lambda item: item["created_at"])
    for job in sorted_jobs[: len(JOBS) - MAX_JOBS + 1]:
        if job["status"] not in {"pending", "running"}:
            JOBS.pop(job["id"], None)


def _now_text():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _parse_int(value, default, minimum, maximum):
    try:
        number = int(value)
    except (TypeError, ValueError):
        number = default

    return max(minimum, min(number, maximum))


def _parse_bool(value):
    if isinstance(value, bool):
        return value

    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y"}

    return bool(value)


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
