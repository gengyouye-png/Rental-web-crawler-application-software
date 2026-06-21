import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import time
from urllib.parse import urlencode, urljoin

from all_clawler.schema import parse_price_number

BASE = "https://rent.591.com.tw"

CITY_MAP = {
    "台北": 1, "基隆": 2, "新北": 3, "新竹市": 4, "新竹縣": 5,
    "桃園": 6, "苗栗": 7, "台中": 8, "彰化": 10, "南投": 11,
    "嘉義市": 12, "嘉義縣": 13, "雲林": 14, "台南": 15,
    "高雄": 17, "屏東": 19, "宜蘭": 21, "台東": 22,
    "花蓮": 23, "澎湖": 24, "金門": 25, "連江": 26,
}

AREA_MAP = {
    "台北": {"中正區": 1, "大同區": 2, "中山區": 3, "松山區": 4, "大安區": 5, "萬華區": 6, "信義區": 7, "士林區": 8, "北投區": 9, "內湖區": 10, "南港區": 11, "文山區": 12},
    "基隆": {"仁愛區": 13, "信義區": 14, "中正區": 15, "中山區": 16, "安樂區": 17, "暖暖區": 18, "七堵區": 19},
    "新北": {"萬里區": 20, "金山區": 21, "板橋區": 26, "汐止區": 27, "深坑區": 28, "石碇區": 29, "瑞芳區": 30, "平溪區": 31, "雙溪區": 32, "貢寮區": 33, "新店區": 34, "坪林區": 35, "烏來區": 36, "永和區": 37, "中和區": 38, "土城區": 39, "三峽區": 40, "樹林區": 41, "鶯歌區": 42, "三重區": 43, "新莊區": 44, "泰山區": 45, "林口區": 46, "蘆洲區": 47, "五股區": 48, "八里區": 49, "淡水區": 50, "三芝區": 51, "石門區": 52},
    "新竹市": {"東區": 371, "北區": 372, "香山區": 370},
    "新竹縣": {"竹北市": 54, "湖口鄉": 55, "新豐鄉": 56, "新埔鎮": 57, "關西鎮": 58, "芎林鄉": 59, "寶山鄉": 60, "竹東鎮": 61, "五峰鄉": 62, "橫山鄉": 63, "尖石鄉": 64, "北埔鄉": 65, "峨嵋鄉": 66},
    "桃園": {"中壢區": 67, "平鎮區": 68, "龍潭區": 69, "楊梅區": 70, "新屋區": 71, "觀音區": 72, "桃園區": 73, "龜山區": 74, "八德區": 75, "大溪區": 76, "復興區": 77, "大園區": 78, "蘆竹區": 79},
    "苗栗": {"竹南鎮": 80, "頭份市": 81, "三灣鄉": 82, "南庄鄉": 83, "獅潭鄉": 84, "後龍鎮": 85, "通霄鎮": 86, "苑裡鎮": 87, "苗栗市": 88, "造橋鄉": 89, "頭屋鄉": 90, "公館鄉": 91, "大湖鄉": 92, "泰安鄉": 93, "銅鑼鄉": 94, "三義鄉": 95, "西湖鄉": 96, "卓蘭鎮": 97},
    "台中": {"中區": 98, "東區": 99, "南區": 100, "西區": 101, "北區": 102, "北屯區": 103, "西屯區": 104, "南屯區": 105, "太平區": 106, "大里區": 107, "霧峰區": 108, "烏日區": 109, "豐原區": 110, "后里區": 111, "石岡區": 112, "東勢區": 113, "和平區": 114, "新社區": 115, "潭子區": 116, "大雅區": 117, "神岡區": 118, "大肚區": 119, "沙鹿區": 120, "龍井區": 121, "梧棲區": 122, "清水區": 123, "大甲區": 124, "外埔區": 125, "大安區": 126},
    "彰化": {"彰化市": 127, "芬園鄉": 128, "花壇鄉": 129, "秀水鄉": 130, "鹿港鎮": 131, "福興鄉": 132, "線西鄉": 133, "和美鎮": 134, "伸港鄉": 135, "員林市": 136, "社頭鄉": 137, "永靖鄉": 138, "埔心鄉": 139, "溪湖鎮": 140, "大村鄉": 141, "埔鹽鄉": 142, "田中鎮": 143, "北斗鎮": 144, "田尾鄉": 145, "埤頭鄉": 146, "溪州鄉": 147, "竹塘鄉": 148, "二林鎮": 149, "大城鄉": 150, "芳苑鄉": 151, "二水鄉": 152},
    "南投": {"南投市": 153, "中寮鄉": 154, "草屯鎮": 155, "國姓鄉": 156, "埔里鎮": 157, "仁愛鄉": 158, "名間鄉": 159, "集集鎮": 160, "水里鄉": 161, "魚池鄉": 162, "信義鄉": 163, "竹山鎮": 164, "鹿谷鄉": 165},
    "嘉義市": {"西區": 373, "東區": 374},
    "嘉義縣": {"番路鄉": 167, "梅山鄉": 168, "竹崎鄉": 169, "阿里山鄉": 170, "中埔鄉": 171, "大埔鄉": 172, "水上鄉": 173, "鹿草鄉": 174, "太保市": 175, "朴子市": 176, "東石鄉": 177, "六腳鄉": 178, "新港鄉": 179, "民雄鄉": 180, "大林鎮": 181, "溪口鄉": 182, "義竹鄉": 183, "布袋鎮": 184},
    "雲林": {"斗南鎮": 185, "大埤鄉": 186, "虎尾鎮": 187, "土庫鎮": 188, "褒忠鄉": 189, "東勢鄉": 190, "臺西鄉": 191, "崙背鄉": 192, "麥寮鄉": 193, "斗六市": 194, "林內鄉": 195, "古坑鄉": 196, "莿桐鄉": 197, "西螺鎮": 198, "二崙鄉": 199, "北港鎮": 200, "水林鄉": 201, "口湖鄉": 202, "四湖鄉": 203, "元長鄉": 204},
    "台南": {"東區": 206, "南區": 207, "中西區": 208, "北區": 209, "安平區": 210, "安南區": 211, "永康區": 212, "歸仁區": 213, "新化區": 214, "左鎮區": 215, "玉井區": 216, "楠西區": 217, "南化區": 218, "仁德區": 219, "關廟區": 220, "龍崎區": 221, "官田區": 222, "麻豆區": 223, "佳里區": 224, "西港區": 225, "七股區": 226, "將軍區": 227, "學甲區": 228, "北門區": 229, "新營區": 230, "後壁區": 231, "白河區": 232, "東山區": 233, "六甲區": 234, "下營區": 235, "柳營區": 236, "鹽水區": 237, "善化區": 238, "大內區": 239, "山上區": 240, "新市區": 241, "安定區": 242},
    "高雄": {"新興區": 243, "前金區": 244, "苓雅區": 245, "鹽埕區": 246, "鼓山區": 247, "旗津區": 248, "前鎮區": 249, "三民區": 250, "楠梓區": 251, "小港區": 252, "左營區": 253, "仁武區": 254, "大社區": 255, "岡山區": 258, "路竹區": 259, "阿蓮區": 260, "田寮區": 261, "燕巢區": 262, "橋頭區": 263, "梓官區": 264, "彌陀區": 265, "永安區": 266, "湖內區": 267, "鳳山區": 268, "大寮區": 269, "林園區": 270, "鳥松區": 271, "大樹區": 272, "旗山區": 273, "美濃區": 274, "六龜區": 275, "內門區": 276, "杉林區": 277, "甲仙區": 278, "桃源區": 279, "那瑪夏區": 280, "茂林區": 281, "茄萣區": 282},
    "屏東": {"屏東市": 295, "三地門鄉": 296, "霧臺鄉": 297, "瑪家鄉": 298, "九如鄉": 299, "里港鄉": 300, "高樹鄉": 301, "鹽埔鄉": 302, "長治鄉": 303, "麟洛鄉": 304, "竹田鄉": 305, "內埔鄉": 306, "萬丹鄉": 307, "潮州鎮": 308, "泰武鄉": 309, "來義鄉": 310, "萬巒鄉": 311, "崁頂鄉": 312, "新埤鄉": 313, "南州鄉": 314, "林邊鄉": 315, "東港鎮": 316, "琉球鄉": 317, "佳冬鄉": 318, "新園鄉": 319, "枋寮鄉": 320, "枋山鄉": 321, "春日鄉": 322, "獅子鄉": 323, "車城鄉": 324, "牡丹鄉": 325, "恆春鎮": 326, "滿州鄉": 327},
    "宜蘭": {"宜蘭市": 328, "頭城鎮": 329, "礁溪鄉": 330, "壯圍鄉": 331, "員山鄉": 332, "羅東鎮": 333, "三星鄉": 334, "大同鄉": 335, "五結鄉": 336, "冬山鄉": 337, "蘇澳鎮": 338, "南澳鄉": 339},
    "台東": {"台東市": 341, "綠島鄉": 342, "蘭嶼鄉": 343, "延平鄉": 344, "卑南鄉": 345, "鹿野鄉": 346, "關山鎮": 347, "海端鄉": 348, "池上鄉": 349, "東河鄉": 350, "成功鎮": 351, "長濱鄉": 352, "太麻里鄉": 353, "金峰鄉": 354, "大武鄉": 355, "達仁鄉": 356},
    "花蓮": {"花蓮市": 357, "新城鄉": 358, "秀林鄉": 359, "吉安鄉": 360, "壽豐鄉": 361, "鳳林鎮": 362, "光復鄉": 363, "豐濱鄉": 364, "瑞穗鄉": 365, "萬榮鄉": 366, "玉里鎮": 367, "卓溪鄉": 368, "富里鄉": 369},
    "澎湖": {"馬公市": 283, "西嶼鄉": 284, "望安鄉": 285, "七美鄉": 286, "白沙鄉": 287, "湖西鄉": 288},
    "金門": {"金沙鎮": 289, "金湖鎮": 290, "金寧鄉": 291, "金城鎮": 292, "烈嶼鄉": 293, "烏坵鄉": 294},
    "連江": {"南竿鄉": 22, "北竿鄉": 23, "莒光鄉": 24, "東引鄉": 25},
}

CITY_ALIASES = {
    "臺北": "台北", "台北市": "台北", "臺北市": "台北",
    "基隆市": "基隆", "新北市": "新北",
    "新竹": "新竹市",
    "桃園市": "桃園", "苗栗縣": "苗栗",
    "臺中": "台中", "台中市": "台中", "臺中市": "台中",
    "彰化縣": "彰化", "南投縣": "南投",
    "嘉義": "嘉義市",
    "雲林縣": "雲林", "臺南": "台南", "台南市": "台南", "臺南市": "台南",
    "高雄市": "高雄", "屏東縣": "屏東", "宜蘭縣": "宜蘭",
    "臺東": "台東", "台東縣": "台東", "臺東縣": "台東",
    "花蓮縣": "花蓮", "澎湖縣": "澎湖", "金門縣": "金門",
    "連江縣": "連江", "馬祖": "連江",
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


def normalize_city(value):
    city = (value or "").strip().replace(" ", "")
    city = city.replace("臺", "台")
    return CITY_ALIASES.get(city, city)


def normalize_area_name(city, value):
    area = (value or "").strip().replace(" ", "")
    area = area.replace("臺", "台")
    if not area:
        return ""

    area_map = AREA_MAP.get(city, {})
    normalized_area_map = {
        key.replace("臺", "台"): key
        for key in area_map
    }
    if area in normalized_area_map:
        return normalized_area_map[area]

    for suffix in ("區", "市", "鎮", "鄉"):
        candidate = area + suffix
        if candidate in normalized_area_map:
            return normalized_area_map[candidate]

    return area


def parse_int_text(value, default=0):
    try:
        return int(str(value).replace(",", "").strip())
    except (TypeError, ValueError):
        return default


def params_from_values(city, area_name, kind_text, min_price, max_price, subsidy, max_pages):
    city = normalize_city(city or "台中")
    if city not in CITY_MAP:
        raise ValueError(f"591 不支援或找不到縣市：{city}")

    area_name = normalize_area_name(city, area_name)
    area_id = ""
    if area_name:
        area_id = AREA_MAP.get(city, {}).get(area_name)
        if not area_id:
            raise ValueError(f"591 找不到 {city} 的地區：{area_name}")

    kind_text = (kind_text or "獨立套房").strip()
    kind = KIND_MAP.get(kind_text, 2)
    min_price = parse_int_text(min_price, 5000)
    max_price = parse_int_text(max_price, 10000)

    if min_price > max_price:
        raise ValueError("最低租金不能大於最高租金")

    return {
        "city": city,
        "area_name": area_name,
        "region": CITY_MAP[city],
        "area_id": area_id,
        "kind": kind,
        "kind_text": kind_text,
        "min_price": min_price,
        "max_price": max_price,
        "price": f"{min_price}_{max_price}",
        "subsidy": bool(subsidy),
        "max_pages": int(max_pages or 3),
    }


def ask_user():

    print("=== 591 租屋爬蟲 ===")

    print("\n可選縣市：")
    print("、".join(CITY_MAP.keys()))

    city = normalize_city(input("\n請輸入縣市：").strip())

    if city not in CITY_MAP:
        print("找不到縣市，預設台中")
        city = "台中"

    print("\n可選地區：")
    print("、".join(AREA_MAP.get(city, {}).keys()))

    area_name = normalize_area_name(city, input("\n請輸入地區：").strip())

    print("\n可選房型：")
    print("、".join(KIND_MAP.keys()))

    kind_text = input("\n請輸入房型：").strip()

    if not kind_text:
        kind_text = "獨立套房"

    min_price = input("\n最低租金：").strip() or "5000"
    max_price = input("最高租金：").strip() or "10000"

    subsidy = input("\n是否要租補？ y/n：").strip().lower()

    max_pages_text = input("\n要抓幾頁？").strip()

    max_pages = int(max_pages_text) if max_pages_text.isdigit() else 5

    return params_from_values(
        city=city,
        area_name=area_name,
        kind_text=kind_text,
        min_price=min_price,
        max_price=max_price,
        subsidy=subsidy == "y",
        max_pages=max_pages,
    )


def params_from_config(config):
    return params_from_values(
        city=config.get("city") or "台中",
        area_name=config.get("area_name") or "",
        kind_text=config.get("kind_text") or "獨立套房",
        min_price=config.get("min_price") or "5000",
        max_price=config.get("max_price") or "10000",
        subsidy=config.get("subsidy"),
        max_pages=config.get("max_pages") or 3,
    )


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

    if page > 1:
        query["page"] = page

    return BASE + "/list?" + urlencode(query)


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


def is_noise_line(line):
    noise_words = [
        "591", "免費", "立即", "現在加入", "網路平臺", "登入", "註冊",
        "房東收費", "刊登", "客服", "廣告", "下載APP", "APP",
    ]
    return any(word in line for word in noise_words)


def infer_district(city, text):
    normalized_text = text.replace("臺", "台")
    districts = sorted(AREA_MAP.get(city, {}).keys(), key=len, reverse=True)
    for district in districts:
        if district.replace("臺", "台") in normalized_text:
            return district
    return ""


def extract_address(lines, city, area_name):
    districts = sorted(AREA_MAP.get(city, {}).keys(), key=len, reverse=True)
    district_pattern = "|".join(re.escape(item) for item in districts)
    city_variants = {city, city + "市", city + "縣", city.replace("台", "臺")}

    patterns = []
    if area_name:
        patterns.extend([
            rf'({re.escape(area_name)}[-\s　]?.{{0,45}}(?:路|街|巷|弄|段|大道|村|里|鄰|號).*)',
            rf'(?:{"|".join(re.escape(item) for item in city_variants)}).{{0,12}}({re.escape(area_name)}.{{0,45}}(?:路|街|巷|弄|段|大道|村|里|鄰|號).*)',
        ])

    if district_pattern:
        patterns.append(rf'(({district_pattern})[-\s　]?.{{0,45}}(?:路|街|巷|弄|段|大道|村|里|鄰|號).*)')

    for line in lines:
        if is_noise_line(line):
            continue
        compact = re.sub(r"\s+", "", line)
        for pattern in patterns:
            match = re.search(pattern, compact)
            if match:
                return match.group(1)

    return ""


def row_matches_filters(row, params):
    price_num = row.get("租金數字")
    if price_num is None:
        return False

    if price_num < params["min_price"] or price_num > params["max_price"]:
        return False

    expected_area = params.get("area_name") or ""
    if expected_area:
        haystack = "".join(str(row.get(key) or "") for key in ("地區", "地址", "標題"))
        haystack = haystack.replace("臺", "台")
        if expected_area.replace("臺", "台") not in haystack:
            return False

    return True


def parse_detail(link, city, area_name, requested_kind=""):

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
    room_type = requested_kind

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
        price = re.sub(r"\s+", "", price_match.group())

    deposit_match = re.search(
        r'押金\s*(?:[一二三四五六七八九十\d]+個月|面議|[\d,]+元)',
        text
    )

    if deposit_match:
        deposit = deposit_match.group().replace(" ", "")

    addr = extract_address(lines, city, area_name)
    district = area_name or infer_district(city, addr + "\n" + title + "\n" + text[:2000])

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

    if not room_type:
        room_match = re.search(
            r'\d+\s*房\s*\d+\s*廳\s*\d+\s*衛|'
            r'獨立套房|分租套房|雅房|整層住家',
            text
        )

        if room_match:
            room_type = room_match.group().replace(" ", "")

    return {
        "縣市": city,
        "地區": district,
        "標題": title,
        "租金": price,
        "租金數字": parse_price_number(price),
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
                params["area_name"],
                params["kind_text"],
            )

            if row_matches_filters(data, params):
                rows.append(data)
            else:
                print("略過不符合條件：", link)

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
