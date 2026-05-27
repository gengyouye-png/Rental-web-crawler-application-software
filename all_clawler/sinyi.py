import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import time
from urllib.parse import urljoin

BASE = "https://www.sinyi.com.tw/rent/"

CITY_MAP = {
    "台北": 'Taipei-city',
    "新北": 'NewTaipei-city',
    "桃園": 'Taoyuan-city',
    "台中": 'Taichung-city',
    "台南": 'Tainan-city',
    "高雄": 'Kaohsiung-city',
    "彰化": 'Changhua-city',
}

AREA_MAP = {
    "台中": {
        "西屯區": '407-zip',
        "北屯區": '406-zip',
        "南屯區": '408-zip',
        "北區": '404-zip',
        "西區": '403-zip',
        "南區": '402-zip',
        "東區": '401-zip',
        "中區": '400-zip',
    },

    "高雄": {
        "三民區": '807-zip',
        "左營區":'813-zip',
        "鼓山區": '804-zip',
        "苓雅區": '802-zip',
        "前鎮區": '806-zip',
        "鳳山區": '830-zip',
    },
    "台北": {
        "中正區": '100-zip',
        "中山區":'104-zip',
        "大安區": '106-zip',
        "萬華區": '108-zip',
        "信義區": '110-zip',
        "南港區": '115-zip',
    },
    "新北": {
        "新店區": '231-zip',
        "板橋區":'220-zip',
        "中和區": '235-zip',
        "三重區": '241-zip',
        "新莊區": '242-zip',
        "永和區": '234-zip',
    },
    "桃園": {
        "中壢區": '320-zip',
        "八德區":'334-zip',
        "平鎮區": '324-zip',
        "大溪區": '335-zip',
    },
    "台南": {
        "中西區": '700-zip',
        "東區":'701-zip',
        "南區": '702-zip',
        "北區": '703-zip',
    },
    "彰化": {
        "彰化市": '500-zip',
        "芬園鄉":'502-zip',
        "員林市": '510-zip',
    },
}

KIND_MAP = {
    "整層住家": 'house-use',
    "獨立套房": 'rent1-use',
    "分租套房": 'rent2-use',
    "雅房": 'rent3-use',
}

headers = {
    "User-Agent": "Mozilla/5.0",
    "Referer": "https://www.sinyi.com.tw/rent/",
}

session = requests.Session()
session.headers.update(headers)


def ask_user():

    print("=== 信義租屋爬蟲 ===")

    print("\n可選縣市：")
    print("、".join(CITY_MAP.keys()))

    city = input("\n請輸入縣市：").strip()

    region = CITY_MAP.get(city)

    if not region:
        print("找不到縣市，預設台中")
        city = "台中"
        region = "Taichung-city"

    print("\n可選地區：")
    print("、".join(AREA_MAP.get(city, {}).keys()))

    area_name = input("\n請輸入地區，直接 Enter 不限制：").strip()

    area_id = ""

    if area_name:
        area_id = AREA_MAP.get(city, {}).get(area_name, "")

    print("\n可選房型：")
    print("、".join(KIND_MAP.keys()))

    kind_text = input("\n請輸入房型，直接 Enter 預設獨立套房：").strip()

    kind = KIND_MAP.get(kind_text, "rent1-use")

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
        "price": f"{min_price}-{max_price}-price",
        "subsidy": subsidy == "y"
    }


def build_list_url(params, page=1):

    query = {
        "region": params["region"],
        "section": params["area_id"],
        "price": params["price"],
        "kind": params["kind"],
        "other": params["subsidy"],
    }

    url = BASE + "list/"

    url += "/".join(map(str, query.values()))


    if page > 1:
        url += f"/{page}"

    return url


def get_house_links(list_url):

    print("\n列表頁：")
    print(list_url)

    res = session.get(list_url, timeout=15)

    res.encoding = "utf-8"

    soup = BeautifulSoup(res.text, "html.parser")

    links = set()

    for a in soup.select("a[href]"):

        href = a.get("href")

        if not href:
            continue

        full_url = urljoin(BASE, href)

        if "houseno/" in full_url:

            clean_url = full_url.split("?")[0]

            links.add(clean_url)

    return list(links)


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

    # 標題
    for line in lines:

        if (
            len(line) > 5
            and "元/月" not in line
            and "押金" not in line
        ):
            title = line
            break

    # 租金
    price_match = re.search(
        r'[\d,]+\s*元/月',
        text
    )

    if price_match:
        price = price_match.group().replace(" ", "")

    # 押金
    deposit_match = re.search(
        r'押金\s*[二一]?個月|押金面議|押金[\d,]+元',
        text
    )

    if deposit_match:
        deposit = deposit_match.group().replace(" ", "")

    # 其他資訊
    for line in lines:

        # 地址
        if (
            addr == ""
            and (
                "路" in line
                or "街" in line
                or "巷" in line
                or "區" in line
            )
        ):
            addr = line

        # 樓層
        if (
            floor == ""
            and "樓" in line
        ):
            floor = line

        # 坪數
        if (
            area == ""
            and "坪" in line
        ):
            area = line

        # 房型
        if (
            room_type == ""
            and (
                "房" in line
                or "廳" in line
                or "衛" in line
                or "套房" in line
                or "雅房" in line
            )
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

    df.to_excel(
        f"信義租屋.{params['city']}_{params['area_name']}.xlsx",
        index=False
    )

    print("\n完成")
    print(f"已輸出：信義租屋.{params['city']}_{params['area_name']}.xlsx")


if __name__ == "__main__":
    main()


