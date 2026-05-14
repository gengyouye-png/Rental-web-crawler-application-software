import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import time
from urllib.parse import urljoin, quote

BASE = "https://rent.yungching.com.tw"

# 你的 cookie
COOKIE = r"""TRID_G=fd63f64e-5839-421b-80c6-4e5c5ea13799; _gcl_gs=2.1.k1$i1778775100$u87386507; _gcl_au=1.1.2022880119.1778775102; __ltm_https_flag=true; _ga=GA1.1.888598861.1778775102; _ycuserid=568ddd18-65bc-40a9-9dc1-3c8bcf0e728b; _fbp=fb.2.1778775102585.997989108402001975; _clck=uxki9u%5E2%5Eg61%5E0%5E2325; _gcl_aw=GCL.1778775104.CjwKCAjw5ZXQBhBdEiwAI5XVWW7WooiqJ69lYKv18AEdAwjB1Vo1hL5IX8rjwRIN7wPcSzLPmzBmqhoCftMQAvD_BwE; __ltmwga=utmcsr%3Dgoogle%7Cutmcmd%3Dcpc%7Cutmcct%3Dbuy_pmax; __lt__cid=2ae2988f-98cf-4c8b-b8e8-ff24675bf71a; __lt__sid=0417f04d-b0e52a5a; _pk_ses.20.e415=*"""

CITY_MAP = {
    "台北市": "台北市",
    "新北市": "新北市",
    "桃園市": "桃園市",
    "台中市": "台中市",
    "台南市": "台南市",
    "高雄市": "高雄市",
}

AREA_MAP = {
    "台北市": [
        "大安區",
        "信義區",
        "中山區",
        "文山區",
        "內湖區",
    ],

    "台中市": [
        "西屯區",
        "北屯區",
        "南屯區",
        "北區",
        "西區",
    ],

    "高雄市": [
        "三民區",
        "左營區",
        "鼓山區",
        "苓雅區",
    ]
}

headers = {
    "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    "accept-language": "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7",
    "cache-control": "max-age=0",
    "referer": BASE,
    "sec-ch-ua": '"Chromium";v="148", "Google Chrome";v="148", "Not/A)Brand";v="99"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"Windows"',
    "sec-fetch-dest": "document",
    "sec-fetch-mode": "navigate",
    "sec-fetch-site": "same-origin",
    "upgrade-insecure-requests": "1",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
    "cookie": COOKIE,
}

session = requests.Session()
session.headers.update(headers)


def ask_user():

    print("=== 永慶租屋 requests 爬蟲 ===")

    print("\n可選縣市：")
    print("、".join(CITY_MAP.keys()))

    city = input("\n請輸入縣市：").strip()

    if city not in CITY_MAP:
        print("縣市不存在，預設台北市")
        city = "台北市"

    print("\n可選地區：")
    print("、".join(AREA_MAP.get(city, [])))

    area = input("\n請輸入地區，直接 Enter 不限制：").strip()

    min_price = input("\n最低租金：").strip()
    max_price = input("最高租金：").strip()

    if not min_price:
        min_price = "0"

    if not max_price:
        max_price = "999999"

    pages = input("\n要抓幾頁？直接 Enter 預設 1 頁：").strip()

    max_pages = int(pages) if pages.isdigit() else 1

    return {
        "city": city,
        "area": area,
        "min_price": min_price,
        "max_price": max_price,
        "max_pages": max_pages
    }


def build_page_url(params, page=1):

    city = params["city"]
    area = params["area"]
    min_price = params["min_price"]
    max_price = params["max_price"]

    if area:
        area_text = f"{city}-{area}_c"
    else:
        area_text = f"{city}-_c"

    url = (
        f"{BASE}/list/"
        f"{quote(area_text)}/"
        f"{min_price}-{max_price}_price"
    )

    if page > 1:
        url += f"?pg={page}"

    return url


def get_page(url):

    res = session.get(url, timeout=20)

    res.encoding = "utf-8"

    print("狀態碼：", res.status_code)

    return res.text


def get_house_links(list_url):

    html = get_page(list_url)

    soup = BeautifulSoup(html, "html.parser")

    links = []

    for a in soup.select("a[href]"):

        href = a.get("href")

        if not href:
            continue

        full_url = urljoin(BASE, href)

        if "rent.yungching.com.tw" not in full_url:
            continue

        text = a.get_text(" ", strip=True)

        if (
            re.search(r'\d+(?:\.\d+)?\s*坪', text)
            or re.search(r'\d+\s*房', text)
            or "元/月" in text
            or "套房" in text
            or "雅房" in text
            or "整層住家" in text
        ):

            if full_url not in links:
                links.append(full_url)

    return links


def parse_detail(link):

    html = get_page(link)

    soup = BeautifulSoup(html, "html.parser")

    text = soup.get_text("\n", strip=True)

    lines = [
        line.strip()
        for line in text.split("\n")
        if line.strip()
    ]

    title = ""
    price = ""
    addr = ""
    floor = ""
    area = ""
    layout = ""

    # 標題
    for line in lines:

        if (
            len(line) > 5
            and "元" not in line
            and "坪" not in line
            and "樓" not in line
            and "房" not in line
            and "廳" not in line
        ):

            title = line
            break

    # 租金
    price_match = re.search(
        r'[\d,]+\s*元/月|'
        r'月租\s*[\d,]+|'
        r'租金\s*[\d,]+|'
        r'[\d,]+\s*/\s*月',
        text
    )

    if price_match:
        price = price_match.group().replace(" ", "")

    # 坪數
    area_match = re.search(
        r'\d+(?:\.\d+)?\s*坪',
        text
    )

    if area_match:
        area = area_match.group().replace(" ", "")

    # 樓層
    floor_patterns = [
        r'\d+\s*樓\s*/\s*\d+\s*樓',
        r'\d+F\s*/\s*\d+F',
        r'地下\d+\s*樓',
        r'\d+\s*樓',
        r'B\d+',
        r'頂樓加蓋',
    ]

    for pattern in floor_patterns:

        floor_match = re.search(
            pattern,
            text,
            re.IGNORECASE
        )

        if floor_match:
            floor = floor_match.group().replace(" ", "")
            break

    # 格局
    layout_match = re.search(
        r'\d+\s*房\s*\d+\s*廳\s*\d+\s*衛|'
        r'\d+\s*房\s*\d+\s*廳|'
        r'套房|雅房|整層住家',
        text
    )

    if layout_match:
        layout = layout_match.group().replace(" ", "")

    # 地址
    address_patterns = [
        r'.{1,8}[市縣].{1,8}[區鄉鎮市].{0,40}[路街巷弄段大道].*',
        r'.{1,8}[區鄉鎮市].{0,40}[路街巷弄段大道].*',
    ]

    bad_addr_words = [
        "附近",
        "生活機能",
        "租金",
        "管理費",
        "坪",
        "樓",
        "房",
        "廳",
        "衛",
        "屋主",
        "仲介",
        "照片",
        "影片",
    ]

    for line in lines:

        if len(line) < 6 or len(line) > 80:
            continue

        if any(word in line for word in bad_addr_words):
            continue

        for pattern in address_patterns:

            if re.search(pattern, line):
                addr = line
                break

        if addr:
            break

    return {
        "標題": title,
        "租金": price,
        "地址": addr,
        "樓層": floor,
        "坪數": area,
        "格局": layout,
        "連結": link,
    }


def main():

    params = ask_user()

    all_links = []

    for page in range(1, params["max_pages"] + 1):

        page_url = build_page_url(params, page)

        print("\n目前頁面：")
        print(page_url)

        links = get_house_links(page_url)

        print(f"第 {page} 頁找到連結：{len(links)}")

        if not links:
            continue

        all_links.extend(links)

        time.sleep(1)

    all_links = list(set(all_links))

    print("\n總連結數：", len(all_links))

    rows = []

    for index, link in enumerate(all_links):

        print(f"\n{index + 1}/{len(all_links)}")

        try:

            data = parse_detail(link)

            rows.append(data)

        except Exception as e:

            print("失敗：", link)
            print(e)

        time.sleep(1)

    df = pd.DataFrame(rows)

    excel_name = "永慶租屋資料.xlsx"
    csv_name = "永慶租屋資料.csv"

    df.to_excel(
        excel_name,
        index=False
    )

    df.to_csv(
        csv_name,
        index=False,
        encoding="utf-8-sig"
    )

    print("\n完成")
    print(f"Excel：{excel_name}")
    print(f"CSV：{csv_name}")
    print(f"共 {len(df)} 筆資料")


if __name__ == "__main__":
    main()