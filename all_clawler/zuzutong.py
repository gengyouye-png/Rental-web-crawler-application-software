import time
import requests
from bs4 import BeautifulSoup
from urllib.parse import quote
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

BASE_URL = "https://dd-room.com"

headers = {
    "User-Agent": "Mozilla/5.0"
}


def get_search_url(keyword, page):
    keyword = quote(keyword)
    return (
        f"https://dd-room.com/search?"
        f"category=house&keywords={keyword}"
        f"&order=recommend&sort=desc&page={page}"
    )


def parse_price(price_text):
    num = ""
    for ch in price_text:
        if ch.isdigit():
            num += ch
    return int(num) if num else 0


def get_soup(url):
    res = requests.get(url, headers=headers)
    res.encoding = "utf-8"
    return BeautifulSoup(res.text, "html.parser")


def get_object_links(driver, search_url):
    driver.get(search_url)
    time.sleep(3)

    links = []

    a_tags = driver.find_elements(By.CSS_SELECTOR, 'a[href*="/object/"]')

    for a in a_tags:
        href = a.get_attribute("href")

        if href and href not in links:
            links.append(href)

    return links


def crawl_detail(url, city="", area_name=""):
    soup = get_soup(url)

    title = ""
    price = ""

    h1 = soup.select_one("h1")
    h3 = soup.select_one("h3")

    if h1:
        title = h1.get_text(strip=True)

    if h3:
        price = h3.get_text(strip=True)

    texts = list(soup.stripped_strings)

    address = ""
    floor = ""
    area = ""
    room_type = ""

    for i, text in enumerate(texts):

        if "台中市" in text or "臺中市" in text:
            address = text

        if "樓層" in text and i + 1 < len(texts):
            floor = texts[i + 1]

        if "坪數" in text and i + 1 < len(texts):
            area = texts[i + 1]

        if "面積" in text:
            area = text

        if "套房" in text or "雅房" in text or "整層住家" in text:
            room_type = text

    return {
        "縣市": city,
        "地區": area_name,
        "標題": title,
        "租金": price,
        "租金數字": parse_price(price),
        "押金": "",
        "地址": address,
        "樓層": floor,
        "坪數": area,
        "房型": room_type,
        "連結": url,
    }


def ask_user():
    keyword = input("請輸入搜尋關鍵字：").strip()
    max_price_text = input("請輸入最高租金：").strip()
    max_page_text = input("請輸入要爬幾頁：").strip()

    return {
        "keyword": keyword,
        "max_price": max_price_text or "10000",
        "max_pages": int(max_page_text) if max_page_text.isdigit() else 3,
        "city": "",
        "area_name": "",
    }


def crawl(config=None):
    config = config or ask_user()

    keyword = config.get("keyword") or "租屋"
    max_price = int(config.get("max_price") or 10000)
    max_pages = int(config.get("max_pages") or 3)
    city = config.get("city", "")
    area_name = config.get("area_name", "")

    options = Options()
    options.add_argument("--start-maximized")

    driver = webdriver.Chrome(options=options)

    all_links = []

    try:
        for page in range(1, max_pages + 1):
            search_url = get_search_url(keyword, page)

            print("\n搜尋頁：", search_url)

            links = get_object_links(driver, search_url)

            print("找到連結數量：", len(links))

            all_links.extend(links)
    finally:
        driver.quit()

    all_links = list(set(all_links))

    print("\n總物件數：", len(all_links))

    rows = []

    for link in all_links:
        try:
            print("\n正在爬：", link)

            house = crawl_detail(link, city, area_name)

            if house["租金數字"] <= max_price:
                rows.append(house)

                print("標題：", house["標題"])
                print("租金：", house["租金"])
                print("地址：", house["地址"])
                print("樓層：", house["樓層"])
                print("坪數：", house["坪數"])
                print("房型：", house["房型"])
                print("網址：", house["連結"])

        except Exception as e:
            print("爬取失敗：", e)

        time.sleep(1)

    return rows


def main():
    crawl()


if __name__ == "__main__":
    main()
