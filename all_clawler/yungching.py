import re

from playwright.sync_api import sync_playwright


CITY_MAP = {
    "台北": "台北市",
    "新北": "新北市",
    "桃園": "桃園市",
    "台中": "台中市",
    "台南": "台南市",
    "高雄": "高雄市",
    "彰化": "彰化縣",
}


def ask_user():
    return {
        "city": input("縣市（例：台中市）：").strip() or "台中市",
        "area_name": input("地區（例：西屯）：").strip(),
    }


def crawl(config=None):
    config = config or ask_user()

    city = config.get("city") or "台中"
    city_for_url = CITY_MAP.get(city, city)
    area = config.get("area_name") or ""
    url = f"https://rent.yungching.com.tw/list/{city_for_url}-{area}_c"

    rows = []
    seen = set()

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        page = browser.new_page()

        try:
            page.goto(url)
            page.wait_for_timeout(8000)

            for _ in range(10):
                page.mouse.wheel(0, 2500)
                page.wait_for_timeout(1200)

            cards = page.locator("a[href]").all()
            real_cards = []

            for card in cards:
                try:
                    text = card.inner_text()
                except Exception:
                    continue

                if not text or len(text) < 30:
                    continue

                if "租" in text or "元/月" in text:
                    real_cards.append(card)

            print("房源候選數:", len(real_cards))

            for card in real_cards:
                try:
                    text = card.inner_text()
                except Exception:
                    continue

                lines = text.split("\n")
                title = lines[0] if lines else ""

                price = ""
                price_num = None

                match = re.search(r"([\d,]+)\s*元/月", text)

                if match:
                    price = match.group()
                    price_num = int(match.group(1).replace(",", ""))

                if price_num is None:
                    backup_match = re.search(r"([\d,]+)", text)
                    if backup_match:
                        price = backup_match.group()
                        price_num = int(backup_match.group(1).replace(",", ""))

                address = ""
                for line in lines:
                    if ("路" in line or "街" in line or "巷" in line) and len(line) < 40:
                        address = line
                        break

                link = card.get_attribute("href")

                if not link or link in seen:
                    continue

                seen.add(link)

                rows.append({
                    "縣市": city,
                    "地區": area,
                    "標題": title,
                    "租金": price,
                    "租金數字": price_num,
                    "押金": "",
                    "地址": address,
                    "樓層": "",
                    "坪數": "",
                    "房型": "",
                    "連結": link,
                })
        finally:
            browser.close()

    print("總筆數:", len(rows))
    return rows


def main():
    crawl()


if __name__ == "__main__":
    main()
