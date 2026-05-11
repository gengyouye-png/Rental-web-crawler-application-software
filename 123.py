import sqlite3
import pandas as pd

# =========================
# 模擬爬蟲抓到的資料
# =========================

houses = [
    {
        "title": "逢甲套房",
        "price": 8000,
        "address": "台中市西屯區",
        "url": "https://rent.com/001"
    },
    {
        "title": "近學校雅房",
        "price": 6500,
        "address": "台中市西屯區",
        "url": "https://rent.com/002"
    },
    {
        "title": "逢甲套房",
        "price": 8000,
        "address": "台中市西屯區",
        "url": "https://rent.com/001"
    }
]

# =========================
# 轉成 DataFrame
# =========================

df = pd.DataFrame(houses)

# =========================
# 連接 SQLite
# =========================

conn = sqlite3.connect("rent.db")

cursor = conn.cursor()

# =========================
# 建立資料表
# =========================

cursor.execute("""
CREATE TABLE IF NOT EXISTS houses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    price INTEGER,
    address TEXT,
    url TEXT UNIQUE
)
""")

# =========================
# 插入資料
# =========================

for _, row in df.iterrows():

    cursor.execute("""
    INSERT OR IGNORE INTO houses
    (title, price, address, url)
    VALUES (?, ?, ?, ?)
    """, (
        row["title"],
        row["price"],
        row["address"],
        row["url"]
    ))

# =========================
# 儲存
# =========================

conn.commit()

# =========================
# 讀取資料
# =========================

result = pd.read_sql("""
SELECT * FROM houses
""", conn)

print(result)

# =========================
# 關閉資料庫
# =========================

conn.close()