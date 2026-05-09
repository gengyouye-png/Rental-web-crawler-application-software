import requests
from bs4 import BeautifulSoup

def crawl_site1(keyword="", min_price=0, max_price=999999):
    """
    租屋網站 1 爬蟲框架
    回傳格式一定要統一
    """

    results = []

    # 這裡之後換成真正的租屋網站網址
    url = "https://example.com/rent"

    params = {
        "keyword": keyword,
        "min_price": min_price,
        "max_price": max_price
    }

    headers = {
        "User-Agent": "Mozilla/5.0"
    }

    try:
        response = requests.get(
            url,
            params=params,
            headers=headers,
            timeout=10
        )

        response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")

        # 這裡之後依照網站 HTML 結構修改
        house_cards = soup.select(".house-card")

        for card in house_cards:
            title = card.select_one(".title").get_text(strip=True)
            price_text = card.select_one(".price").get_text(strip=True)
            address = card.select_one(".address").get_text(strip=True)
            room_type = card.select_one(".room-type").get_text(strip=True)
            size = card.select_one(".size").get_text(strip=True)
            link = card.select_one("a")["href"]

            price = parse_price(price_text)

            if not check_filter(title, address, price, keyword, min_price, max_price):
                continue

            item = {
                "title": title,
                "price": price,
                "address": address,
                "room_type": room_type,
                "size": size,
                "source": "租屋網站1",
                "url": link
            }

            results.append(item)

    except Exception as e:
        print("crawler_site1 發生錯誤：", e)

    return results


def parse_price(price_text):
    """
    將租金文字轉成數字
    例如：'8,000元/月' → 8000
    """

    price_text = price_text.replace(",", "")
    price_text = price_text.replace("元", "")
    price_text = price_text.replace("/月", "")
    price_text = price_text.strip()

    number = ""

    for char in price_text:
        if char.isdigit():
            number += char

    if number == "":
        return 0

    return int(number)


def check_filter(title, address, price, keyword, min_price, max_price):
    """
    篩選資料
    """

    if price < min_price or price > max_price:
        return False

    if keyword:
        if keyword not in title and keyword not in address:
            return False

    return True