import os
import sqlite3
from datetime import datetime


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "rental.db")


HOUSE_COLUMNS = {
    "來源": "TEXT",
    "縣市": "TEXT",
    "地區": "TEXT",
    "標題": "TEXT",
    "租金": "TEXT",
    "租金數字": "INTEGER",
    "押金": "TEXT",
    "地址": "TEXT",
    "坪數": "TEXT",
    "房型": "TEXT",
    "樓層": "TEXT",
    "連結": "TEXT UNIQUE",
    "建立時間": "TEXT",
}


def get_connection():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.execute("PRAGMA busy_timeout = 30000")
    return conn


def init_db():
    """建立 SQLite 資料表；如果舊表缺欄位，會自動補上。"""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("PRAGMA journal_mode = WAL")

        cursor.execute("""
        CREATE TABLE IF NOT EXISTS houses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            來源 TEXT,
            縣市 TEXT,
            地區 TEXT,
            標題 TEXT,
            租金 TEXT,
            租金數字 INTEGER,
            押金 TEXT,
            地址 TEXT,
            坪數 TEXT,
            房型 TEXT,
            樓層 TEXT,
            連結 TEXT UNIQUE,
            建立時間 TEXT
        )
        """)

        existing_columns = {
            row[1] for row in cursor.execute("PRAGMA table_info(houses)")
        }

        for column, column_type in HOUSE_COLUMNS.items():
            if column not in existing_columns:
                cursor.execute(
                    f"ALTER TABLE houses ADD COLUMN {column} {column_type}"
                )


def save_to_db(rows):
    """用本次爬蟲結果覆蓋目前房源表，讓資料庫保持最新快照。"""
    if not rows:
        return 0

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    saved_count = 0

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM houses")
        cursor.execute("DELETE FROM sqlite_sequence WHERE name = 'houses'")

        for row in rows:
            cursor.execute("""
            INSERT INTO houses (
                來源,
                縣市,
                地區,
                標題,
                租金,
                租金數字,
                押金,
                地址,
                坪數,
                房型,
                樓層,
                連結,
                建立時間
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                row.get("來源", ""),
                row.get("縣市", ""),
                row.get("地區", ""),
                row.get("標題", ""),
                row.get("租金", ""),
                row.get("租金數字"),
                row.get("押金", ""),
                row.get("地址", ""),
                row.get("坪數", ""),
                row.get("房型", ""),
                row.get("樓層", ""),
                row.get("連結") or None,
                now,
            ))

            saved_count += cursor.rowcount

    return saved_count
