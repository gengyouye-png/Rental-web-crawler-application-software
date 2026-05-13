import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import time
import sqlite3
from urllib.parse import urljoin

BASE = "https://rent.591.com.tw"

CITY_MAP = {
    "台北": 1,
    "新北": 3,
    "桃園": 6,
    "台中": 8,
    "台南": 15,
    "高雄": 17,
    "彰化": 10,
    "嘉義": 12,
}

AREA_MAP = {
    "台中": {
        "西屯區": 104,
        "北屯區": 105,
        "南屯區": 106,
        "北區": 100,
        "西區": 101,
        "南區": 102,
        "東區": 103,
        "中區": 99,
    },
    "高雄": {
        "三民區": 291,
        "左營區": 295,
        "鼓山區": 294,
        "苓雅區": 290,
        "前鎮區": 292,
        "鳳山區": 300,
    }
}

KIND_MAP = {
    "整層住家": 1,
    "獨立套房": 2,
    "分租套房": 3,
    "雅房": 4,
}

headers = {
    "User-Agent": "Mozilla/5.0",
    "Referer": "https://rent.591.com.tw/",
}

session = requests.Session()
session.headers.update(headers)


def ask_user():
    print("=== 591 租屋爬蟲 ===")

    print("\n可選縣市：")
    print("、".join(CITY_MAP.keys()))

    city = input("\n請輸入縣市：").strip()
    region = CITY_MAP.get(city)

    if not region:
        print("找不到縣市，預設台中")
        city = "台中"
        region = 8

    print("\n可選地區：")
    print("、".join(AREA_MAP.get(city, {}).keys()))

    area_name = input("\n請輸入地區，直接 Enter 不限制：").strip()
    area_id = ""

    if area_name:
        area_id = AREA_MAP.get(city, {}).get(area_name, "")

    print("\n可選房型：")
    print("、".join(KIND_MAP.keys()))

    kind_text = input("\n請輸入房型，直接 Enter 預設獨立套房：").strip()
    kind = KIND_MAP.get(kind_text, 2)

    min_price = input("\n最低租金，直接 Enter 預設 5000：").strip()
    max_price = input("最高租金，直接 Enter 預設 10000：").strip()

    min_price = min_price if min_price else "5000"
    max_price = max_price if max_price else "10000"

    subsidy = input("\n是否要租補？ y/n：").strip().lower()

    return {
        "city": city,
        "area_name": area_name,
        "region": region,
        "area_id": area_id,
        "kind": kind,
        "price": f"{min_price}_{max_price}",
        "subsidy": subsidy == "y"
    }


def build_list_url(params, page=1):
    query = {
        "region": params["region"],
        "kind": params["kind"],
        "price": params["price"],
    }

    if params["area_id"]:
        query["section"] = params["area_id"]

    if params["subsidy"]:
        query["other"] = "rental-subsidy"

    url = BASE + "/list?"
    url += "&".join([f"{k}={v}" for k, v in query.items()])

    if page > 1:
        url += f"&page={page}"

    return url


def get_house_links(list_url):
    print("\n列表頁：")
    print(list_url)

    res = session.get(list_url, timeout=15)
    res.encoding = "utf-8"

    soup = BeautifulSoup(res.text, "html.parser")

    links = []

    for a in soup.select("a[href]"):
        href = a.get("href")

        if not href:
            continue

        full_url = urljoin(BASE, href)
        house_id = full_url.rstrip("/").split("/")[-1]

        if "rent.591.com.tw" in full_url and house_id.isdigit():
            links.append(full_url)

    return list(set(links))


def parse_detail(link, city, area_name):
    res = session.get(link, timeout=15)
    res.encoding = "utf-8"

    soup = BeautifulSoup(res.text, "html.parser")
    text = soup.get_text("\n", strip=True)

    lines = [
        line.strip()
        for line in text.split("\n")
        if line.strip()
    ]

    title = ""
    price = ""
    deposit = ""
    addr = ""
    floor = ""
    area = ""
    room_type = ""

    for line in lines:
        if len(line) > 5 and "元/月" not in line and "押金" not in line:
            title = line
            break

    price_match = re.search(r'[\d,]+\s*元/月', text)
    if price_match:
        price = price_match.group().replace(" ", "")

    deposit_match = re.search(
        r'押金\s*[二一]?個月|押金面議|押金[\d,]+元',
        text
    )
    if deposit_match:
        deposit = deposit_match.group().replace(" ", "")

    for line in lines:
        if addr == "" and ("路" in line or "街" in line or "巷" in line or "區" in line):
            addr = line

        if floor == "" and "樓" in line:
            floor = line

        if area == "" and "坪" in line:
            area = line

        if room_type == "" and (
            "房" in line or "廳" in line or "衛" in line or "套房" in line or "雅房" in line
        ):
            room_type = line

    return {
        "縣市": city,
        "地區": area_name,
        "標題": title,
        "租金": price,
        "押金": deposit,
        "地址": addr,
        "樓層": floor,
        "坪數": area,
        "房型": room_type,
        "連結": link
    }


def save_to_sqlite(rows):
    conn = sqlite3.connect("rent.db")
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS houses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        縣市 TEXT,
        地區 TEXT,
        標題 TEXT,
        租金 TEXT,
        押金 TEXT,
        地址 TEXT,
        樓層 TEXT,
        坪數 TEXT,
        房型 TEXT,
        連結 TEXT UNIQUE
    )
    """)

    for row in rows:
        cursor.execute("""
        INSERT OR IGNORE INTO houses
        (縣市, 地區, 標題, 租金, 押金, 地址, 樓層, 坪數, 房型, 連結)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            row["縣市"],
            row["地區"],
            row["標題"],
            row["租金"],
            row["押金"],
            row["地址"],
            row["樓層"],
            row["坪數"],
            row["房型"],
            row["連結"]
        ))

    conn.commit()
    conn.close()


def main():
    params = ask_user()

    all_links = []

    for page in range(1, 6):
        list_url = build_list_url(params, page)
        links = get_house_links(list_url)

        print(f"\n第 {page} 頁找到 {len(links)} 筆")

        if not links:
            break

        all_links.extend(links)
        time.sleep(1)

    all_links = list(set(all_links))
    print(f"\n總連結數：{len(all_links)}")

    rows = []

    for i, link in enumerate(all_links):
        print(f"正在抓第 {i + 1}/{len(all_links)} 筆")

        try:
            data = parse_detail(
                link,
                params["city"],
                params["area_name"]
            )
            rows.append(data)

        except Exception as e:
            print("失敗：", link)
            print(e)

        time.sleep(1)

    df = pd.DataFrame(rows)

    save_to_sqlite(rows)

    df.to_excel("591租屋.xlsx", index=False)

    print("\n完成")
    print("已輸出：591租屋.xlsx")
    print("已寫入：rent.db")


if __name__ == "__main__":
    main()