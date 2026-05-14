import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import time
from urllib.parse import quote, urljoin

BASE = "https://rent.yungching.com.tw"

headers = {
    "User-Agent": "Mozilla/5.0",
    "Referer": BASE,
}

session = requests.Session()
session.headers.update(headers)


def ask_user():
    print("=== 永慶租屋 requests 爬蟲 ===")

    city = input("請輸入縣市，例如 台北市、台中市：").strip()
    area = input("請輸入地區，例如 大安區、西屯區，直接 Enter 不限制：").strip()
    pages = input("要抓幾頁？直接 Enter 預設 3 頁：").strip()

    if not city:
        city = "台北市"

    max_pages = int(pages) if pages.isdigit() else 3

    return city, area, max_pages


def build_list_url(city, area="", page=1):
    if area:
        path = f"{city}-{area}_c"
    else:
        path = f"{city}-_c"

    url = f"{BASE}/list/{quote(path)}"

    if page > 1:
        url += f"?pg={page}"

    return url


def get_house_links(list_url):
    print("列表頁：", list_url)

    res = session.get(list_url, timeout=15)
    res.encoding = "utf-8"

    soup = BeautifulSoup(res.text, "html.parser")

    links = []

    for a in soup.select("a[href]"):
        href = a.get("href")
        if not href:
            continue

        full_url = urljoin(BASE, href)

        # 永慶物件網址常含 list 後面的物件編號或 shop 類型
        if "rent.yungching.com.tw" in full_url:
            text = a.get_text(strip=True)

            if (
                re.search(r'\d+(?:\.\d+)?坪', text)
                or re.search(r'\d+\s*/\s*\d+\s*樓', text)
                or "整層住家" in text
                or "獨立套房" in text
                or "分租套房" in text
                or "雅房" in text
            ):
                if full_url not in links:
                    links.append(full_url)

    return links


def parse_list_items(list_url):
    res = session.get(list_url, timeout=15)
    res.encoding = "utf-8"

    soup = BeautifulSoup(res.text, "html.parser")
    text = soup.get_text("\n", strip=True)

    rows = []

    # 從搜尋結果文字直接切物件，永慶列表頁本身有部分物件摘要
    pattern = re.compile(
        r'(?P<title>.+?)\s+'
        r'(?P<addr>.{2,20}[市縣].{1,10}[區鄉鎮市].{0,30}[路街巷弄段大道].*?)\s+'
        r'(?P<type>整層住家|獨立套房|分租套房|雅房|車位|店面|辦公)\s+'
        r'(?P<area>\d+(?:\.\d+)?坪)\s+'
        r'(?P<floor>\d+/\d+樓|\d+樓|地下\d+樓|B\d+)\s+'
        r'(?P<layout>[\d\-]+房.*?衛.*?)\s+'
        r'(?P<price>[\d,]+)',
        re.S
    )

    for m in pattern.finditer(text):
        rows.append({
            "標題": m.group("title").strip()[-30:],
            "租金": m.group("price").strip(),
            "地址": m.group("addr").strip(),
            "樓層": m.group("floor").strip(),
            "坪數": m.group("area").strip(),
            "格局": m.group("layout").strip(),
            "房型": m.group("type").strip(),
            "來源頁": list_url,
        })

    return rows


def main():
    city, area, max_pages = ask_user()

    rows = []

    for page in range(1, max_pages + 1):
        list_url = build_list_url(city, area, page)

        try:
            page_rows = parse_list_items(list_url)
            print(f"第 {page} 頁抓到 {len(page_rows)} 筆")
            rows.extend(page_rows)

        except Exception as e:
            print("失敗：", list_url)
            print(e)

        time.sleep(1)

    df = pd.DataFrame(rows)

    excel_name = "永慶租屋資料.xlsx"
    csv_name = "永慶租屋資料.csv"

    df.to_excel(excel_name, index=False)
    df.to_csv(csv_name, index=False, encoding="utf-8-sig")

    print("\n完成")
    print(f"Excel：{excel_name}")
    print(f"CSV：{csv_name}")
    print(f"共 {len(df)} 筆資料")


if __name__ == "__main__":
    main()