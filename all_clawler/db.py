import sqlite3
import os
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "rental.db")
print("db.py 已載入")
print("DB實際路徑 =", os.path.abspath(DB_PATH))
def get_connection():
    print("正在寫入SQLite位置：", os.path.abspath(DB_PATH))
    return sqlite3.connect(DB_PATH)


def init_db():
    print("init_db 開始")
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS houses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        來源 TEXT,
        標題 TEXT,
        租金 TEXT,
        地址 TEXT,
        坪數 TEXT,
        房型 TEXT,
        樓層 TEXT,
        連結 TEXT UNIQUE,

        建立時間 TEXT
    )
    """)

    conn.commit()
    conn.close()


def save_to_db(rows):
    conn = get_connection()
    cursor = conn.cursor()

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    for row in rows:
        cursor.execute("""
        INSERT OR IGNORE INTO houses (
            來源,
            標題,
            租金,
            地址,
            坪數,
            房型,
            樓層,
            連結,
            建立時間
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            row.get("來源", ""),
            row.get("標題", ""),
            row.get("租金", ""),
            row.get("地址", ""),
            row.get("坪數", ""),
            row.get("房型", ""),
            row.get("樓層", ""),
            row.get("連結", ""),
            now
        ))

    conn.commit()
    conn.close()