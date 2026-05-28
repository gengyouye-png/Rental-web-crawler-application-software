import importlib
import os
from datetime import datetime

import pandas as pd

from config import ask_search_config
from schema import COLUMNS, normalize_rows
from db import init_db, save_to_db
import db

print(db.__file__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(BASE_DIR, "output")


CRAWLERS = [
    {
        "name": "591",
        "module": "clawler_591",
        "enabled": True,
    },
    {
        "name": "信義",
        "module": "sinyi",
        "enabled": True,
    },
    {
        "name": "租租通",
        "module": "zuzutong",
        "enabled": True,
    },
]


def run_crawler(crawler, config):
    print(f"\n========== 開始執行 {crawler['name']} ==========")

    module = importlib.import_module(crawler["module"])

    if not hasattr(module, "crawl"):
        raise AttributeError(f"{crawler['module']} 缺少 crawl(config) 函式")

    rows = module.crawl(config)
    normalized = normalize_rows(crawler["name"], rows)

    print(f"{crawler['name']} 完成，共 {len(normalized)} 筆")
    return normalized


def save_results(rows):
    if not rows:
        print("\n沒有資料可以輸出")
        return

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    df = pd.DataFrame(rows)
    df = df.reindex(columns=COLUMNS)
    df = dedupe_results(df)
    save_to_db(df.to_dict("records"))

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    excel_path = os.path.join(OUTPUT_DIR, f"租屋總表_{timestamp}.xlsx")
    csv_path = os.path.join(OUTPUT_DIR, f"租屋總表_{timestamp}.csv")

    df.to_excel(excel_path, index=False)
    df.to_csv(csv_path, index=False, encoding="utf-8-sig")

    print("\n========== 整合完成 ==========")
    print(f"總筆數：{len(df)}")
    print(f"Excel：{excel_path}")
    print(f"CSV：{csv_path}")


def dedupe_results(df):
    df = df.copy()

    for column in ["連結", "地址", "租金", "標題"]:
        df[column] = df[column].fillna("").astype(str).str.strip()

    has_link = df["連結"] != ""
    with_link = df[has_link].drop_duplicates(subset=["連結"], keep="first")
    without_link = df[~has_link]

    df = pd.concat([with_link, without_link], ignore_index=True)

    has_address_price = (df["地址"] != "") & (df["租金"] != "")
    address_price_rows = df[has_address_price].drop_duplicates(
        subset=["地址", "租金"],
        keep="first",
    )
    other_rows = df[~has_address_price]

    df = pd.concat([address_price_rows, other_rows], ignore_index=True)

    has_title_address = (df["標題"] != "") & (df["地址"] != "")
    title_address_rows = df[has_title_address].drop_duplicates(
        subset=["標題", "地址"],
        keep="first",
    )
    other_rows = df[~has_title_address]

    return pd.concat([title_address_rows, other_rows], ignore_index=True)


def main():
    init_db()
    config = ask_search_config()
    all_rows = []

    for crawler in CRAWLERS:
        if not crawler["enabled"]:
            continue

        try:
            all_rows.extend(run_crawler(crawler, config))
        except Exception as exc:
            print(f"{crawler['name']} 執行失敗：{exc}")

    save_results(all_rows)


if __name__ == "__main__":
    main()
