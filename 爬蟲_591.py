from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import pandas as pd
import time
import re

# 網址
list_url = "https://www.sinyi.com.tw/rent/list/Taichung-city/407-zip/rent1-use/rentAid-source/index.html"

# 瀏覽器
options = Options()
options.add_argument("--start-maximized")

driver = webdriver.Chrome(options=options)

# 進列表頁
driver.get(list_url)

time.sleep(10)

# 滑動
for _ in range(10):
    driver.execute_script("window.scrollBy(0, 800);")
    time.sleep(1)

# 抓連結
links = driver.find_elements(By.CSS_SELECTOR, "a[href]")

house_links = []

for a in links:
    href = a.get_attribute("href")

    if not href:
        continue

    if "https://www.sinyi.com.tw/rent/list/Taichung-city/407-zip/rent1-use/rentAid-source/index.html" in href:

        house_id = href.rstrip("/").split("/")[-1]

        if house_id.isdigit():
            house_links.append(href)

# 去重複
house_links = list(set(house_links))

print("房源：", len(house_links))

# 抓詳細頁
rows = []

for index, link in enumerate(house_links):

    print(f"{index + 1}/{len(house_links)}")

    driver.get(link)

    time.sleep(5)
    # 滑動
    for _ in range(5):
        driver.execute_script("window.scrollBy(0, 600);")
        time.sleep(1)

    page_text = driver.find_element(By.TAG_NAME, "body").text

    lines = page_text.split("\n")

    title = ""
    price = ""
    addr = ""
    layout = ""
    area = ""
    floor = ""
    pet = ""
    manage_fee = ""
    poster = ""

    # 清理
    bad_words = [
        "首頁",
        "新建案",
        "中古屋",
        "租屋",
        "車位",
        "刊登",
        "登入"
    ]

    clean_lines = []

    for line in lines:
        line = line.strip()

        if line and line not in bad_words:
            clean_lines.append(line)

    # 標題
    for line in clean_lines:

        if (
            "元/月" not in line
            and "押金" not in line
            and len(line) > 5
        ):
            title = line
            break

    # 租金
    price_match = re.search(
        r'[\d,]+\s*元/月|月租\s*[\d,]+|租金\s*[\d,]+',
        page_text
    )

    if price_match:
        price = price_match.group().replace(" ", "")

    # 其他
    for line in clean_lines:

        if (
            ("高雄" in line or "路" in line or "街" in line or "巷" in line)
            and addr == ""
        ):
            addr = line

        if "房" in line and "廳" in line and layout == "":
            layout = line

        if "坪" in line and area == "":
            area = line

        if "樓" in line and floor == "":
            floor = line

        if "寵物" in line and pet == "":
            pet = line

        if "管理費" in line and manage_fee == "":
            manage_fee = line

        if (
            ("屋主" in line or "仲介" in line or "代理人" in line)
            and poster == ""
        ):
            poster = line

    rows.append({
        "mark": "",
        "title": title,
        "price": price,
        "price_adjusted": price,
        "link": link,
        "addr": addr,
        "explain": " | ".join(clean_lines[:30]),
        "社區": "",
        "車位": "",
        "管理費": manage_fee,
        "poster": poster,
        "寵物": pet,
        "格局": layout,
        "坪數": area,
        "樓層": floor
    })

# 關閉
driver.quit()

# 輸出
df = pd.DataFrame(rows)

df.to_excel("591租屋詳細資料.xlsx", index=False)

print("完成")