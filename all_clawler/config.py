def ask_search_config():
    print("=== 租屋爬蟲整合系統 ===")

    city = input("縣市（例：台中）：").strip() or "台中"
    area_name = input("地區（例：西屯區，可空白）：").strip()
    kind_text = input("房型（例：獨立套房，可空白）：").strip() or "獨立套房"

    min_price = input("最低租金（預設 5000）：").strip() or "5000"
    max_price = input("最高租金（預設 10000）：").strip() or "10000"

    max_pages_text = input("每個網站最多抓幾頁（預設 3）：").strip()
    max_pages = int(max_pages_text) if max_pages_text.isdigit() else 3

    subsidy = input("是否要租補？ y/n（預設 n）：").strip().lower() == "y"

    default_keyword = " ".join(
        part for part in [city, area_name, kind_text] if part
    )
    keyword = input(f"租租通關鍵字（預設：{default_keyword}）：").strip()

    return {
        "city": city,
        "area_name": area_name,
        "kind_text": kind_text,
        "min_price": min_price,
        "max_price": max_price,
        "max_pages": max_pages,
        "subsidy": subsidy,
        "keyword": keyword or default_keyword,
    }
