import re


COLUMNS = [
    "來源",
    "縣市",
    "地區",
    "標題",
    "租金",
    "租金數字",
    "押金",
    "地址",
    "樓層",
    "坪數",
    "房型",
    "連結",
]


def clean_text(value):
    if value is None:
        return ""

    return re.sub(r"\s+", " ", str(value)).strip()


def parse_price_number(value):
    if value is None:
        return None

    text = str(value)
    match = re.search(r"[\d,]+", text)

    if not match:
        return None

    return int(match.group().replace(",", ""))


def normalize_row(source, row):
    normalized = {
        "來源": source,
        "縣市": row.get("縣市", row.get("city", "")),
        "地區": row.get("地區", row.get("district", "")),
        "標題": row.get("標題", row.get("title", "")),
        "租金": row.get("租金", row.get("price_text", row.get("price", ""))),
        "租金數字": row.get("租金數字", row.get("price_num")),
        "押金": row.get("押金", row.get("deposit", "")),
        "地址": row.get("地址", row.get("address", "")),
        "樓層": row.get("樓層", row.get("floor", "")),
        "坪數": row.get("坪數", row.get("area", "")),
        "房型": row.get("房型", row.get("room_type", "")),
        "連結": row.get("連結", row.get("url", row.get("link", ""))),
    }

    if normalized["租金數字"] in (None, ""):
        normalized["租金數字"] = parse_price_number(normalized["租金"])

    for key, value in normalized.items():
        if key != "租金數字":
            normalized[key] = clean_text(value)

    return normalized


def normalize_rows(source, rows):
    return [normalize_row(source, row) for row in rows]
