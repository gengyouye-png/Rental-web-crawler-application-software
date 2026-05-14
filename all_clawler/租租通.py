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

# ===== 使用者輸入 =====
KEYWORD = input("請輸入搜尋關鍵字：")
MAX_PRICE = int(input("請輸入最高租金："))
MAX_PAGE = int(input("請輸入要爬幾頁："))
# =====================


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


def crawl_detail(url):
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
        "title": title,
        "price_text": price,
        "price": parse_price(price),
        "address": address,
        "floor": floor,
        "area": area,
        "room_type": room_type,
        "url": url
    }


def main():
    options = Options()
    options.add_argument("--start-maximized")

    driver = webdriver.Chrome(options=options)

    all_links = []

    for page in range(1, MAX_PAGE + 1):
        search_url = get_search_url(KEYWORD, page)

        print("\n搜尋頁：", search_url)

        links = get_object_links(driver, search_url)

        print("找到連結數量：", len(links))

        all_links.extend(links)

    driver.quit()

    all_links = list(set(all_links))

    print("\n總物件數：", len(all_links))

    for link in all_links:
        try:
            print("\n正在爬：", link)

            house = crawl_detail(link)

            if house["price"] <= MAX_PRICE:
                print("標題：", house["title"])
                print("租金：", house["price_text"])
                print("地址：", house["address"])
                print("樓層：", house["floor"])
                print("坪數：", house["area"])
                print("房型：", house["room_type"])
                print("網址：", house["url"])

        except Exception as e:
            print("爬取失敗：", e)

        time.sleep(1)


main()