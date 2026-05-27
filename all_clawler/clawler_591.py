import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import time
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
    },

    "台北": {
        "大安區": 5,
        "文山區": 12,
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

    area_name = input("\n請輸入地區：").strip()

    area_id = AREA_MAP.get(city, {}).get(area_name, "")

    print("\n可選房型：")
    print("、".join(KIND_MAP.keys()))

    kind_text = input("\n請輸入房型：").strip()

    if not kind_text:
        kind_text = "獨立套房"

    kind = KIND_MAP.get(kind_text, 2)

    min_price = input("\n最低租金：").strip() or "5000"
    max_price = input("最高租金：").strip() or "10000"

    subsidy = input("\n是否要租補？ y/n：").strip().lower()

    max_pages_text = input("\n要抓幾頁？").strip()

    max_pages = int(max_pages_text) if max_pages_text.isdigit() else 5

    return {
        "city": city,
        "area_name": area_name,
        "region": region,
        "area_id": area_id,
        "kind": kind,
        "price": f"{min_price}_{max_price}",
        "subsidy": subsidy == "y",
        "max_pages": max_pages
    }


def params_from_config(config):
    city = config.get("city") or "台中"
    region = CITY_MAP.get(city, 8)

    area_name = config.get("area_name") or ""
    area_id = AREA_MAP.get(city, {}).get(area_name, "")

    kind_text = config.get("kind_text") or "獨立套房"
    kind = KIND_MAP.get(kind_text, 2)

    min_price = config.get("min_price") or "5000"
    max_price = config.get("max_price") or "10000"

    return {
        "city": city,
        "area_name": area_name,
        "region": region,
        "area_id": area_id,
        "kind": kind,
        "price": f"{min_price}_{max_price}",
        "subsidy": bool(config.get("subsidy")),
        "max_pages": int(config.get("max_pages") or 3),
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

        if (
            "rent.591.com.tw" in full_url
            and house_id.isdigit()
        ):
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

        if (
            len(line) > 5
            and "元/月" not in line
            and "押金" not in line
            and "坪" not in line
            and "樓" not in line
        ):
            title = line
            break

    price_match = re.search(r'[\d,]+\s*元/月', text)

    if price_match:
        price = price_match.group().replace(" ", "")

    deposit_match = re.search(
        r'押金\s*(?:[一二三四五六七八九十\d]+個月|面議|[\d,]+元)',
        text
    )

    if deposit_match:
        deposit = deposit_match.group().replace(" ", "")

    address_patterns = [
        rf'{city}.{{0,10}}{area_name}.{{0,30}}[路街巷弄段大道].*',
        rf'{area_name}.{{0,30}}[路街巷弄段大道].*',
    ]

    for line in lines:

        for pattern in address_patterns:

            if re.search(pattern, line):
                addr = line
                break

        if addr:
            break

    floor_patterns = [
        r'\d+\s*樓\s*/\s*\d+\s*樓',
        r'\d+F\s*/\s*\d+F',
        r'地下\d+\s*樓',
        r'\d+\s*樓',
        r'B\d+',
        r'頂樓加蓋',
    ]

    for pattern in floor_patterns:

        floor_match = re.search(pattern, text)

        if floor_match:
            floor = floor_match.group().replace(" ", "")
            break

    area_match = re.search(r'\d+(?:\.\d+)?\s*坪', text)

    if area_match:
        area = area_match.group().replace(" ", "")

    room_match = re.search(
        r'\d+\s*房\s*\d+\s*廳\s*\d+\s*衛|'
        r'獨立套房|分租套房|雅房|整層住家',
        text
    )

    if room_match:
        room_type = room_match.group().replace(" ", "")

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


def crawl(config=None):

    params = params_from_config(config) if config else ask_user()

    all_links = []

    for page in range(1, params["max_pages"] + 1):

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

    print("\n完成")
    print(f"共 {len(df)} 筆資料")

    return rows


def main():
    crawl()


if __name__ == "__main__":
    main()
