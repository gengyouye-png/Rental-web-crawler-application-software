from playwright.sync_api import sync_playwright
import pandas as pd
import re

# =========================
# 使用者輸入
# =========================
city = input("縣市（例：台中市）：")
area = input("地區（例：西屯）：")

url = f"https://rent.yungching.com.tw/list/{city}-{area}_c"

rows = []
seen = set()

# =========================
# 開始 Playwright
# =========================
with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)
    page = browser.new_page()

    page.goto(url)
    page.wait_for_timeout(8000)

    # =========================
    # 🔥 觸發 lazy load
    # =========================
    for _ in range(10):
        page.mouse.wheel(0, 2500)
        page.wait_for_timeout(1200)

    # =========================
    # 抓所有可點擊元素
    # =========================
    cards = page.locator("a[href]").all()

    real_cards = []

    # =========================
    # 🔥 過濾出「像房源的卡片」
    # =========================
    for c in cards:
        try:
            text = c.inner_text()
        except:
            continue

        if not text or len(text) < 30:
            continue

        # 房源特徵（比精準 selector 更穩）
        if ("租" in text or "元/月" in text):
            real_cards.append(c)

    print("房源候選數:", len(real_cards))

    # =========================
    # 解析每一筆
    # =========================
    for c in real_cards:

        try:
            text = c.inner_text()
        except:
            continue

        lines = text.split("\n")

        # =========================
        # title
        # =========================
        title = lines[0] if lines else ""

        # =========================
        # price（🔥最穩版本）
        # =========================
        price = ""
        price_num = None

        m = re.search(r"([\d,]+)\s*元/月", text)

        if m:
            price = m.group()
            try:
                price_num = int(m.group(1).replace(",", ""))
            except:
                pass

        # backup（防漏）
        if price_num is None:
            m2 = re.search(r"([\d,]+)", text)
            if m2:
                try:
                    price_num = int(m2.group(1).replace(",", ""))
                    price = m2.group()
                except:
                    pass

        # =========================
        # address
        # =========================
        addr = ""
        for l in lines:
            if ("路" in l or "街" in l or "巷" in l) and len(l) < 40:
                addr = l
                break

        # =========================
        # link
        # =========================
        link = c.get_attribute("href")

        if not link:
            continue

        # 去重
        if link in seen:
            continue
        seen.add(link)

        rows.append({
            "title": title,
            "price": price,
            "price_num": price_num,
            "address": addr,
            "link": link,
            "raw": text[:120]
        })

    browser.close()

# =========================
# Excel輸出
# =========================
df = pd.DataFrame(rows)
df.to_excel("永慶租屋_完整版.xlsx", index=False)

print("完成 ✔")
print("總筆數:", len(rows))