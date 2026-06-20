import importlib
import os
from datetime import datetime

import pandas as pd

try:
    from .config import ask_search_config
    from .db import DB_PATH, init_db, save_to_db
    from .schema import COLUMNS, normalize_rows
except ImportError:
    from config import ask_search_config
    from db import DB_PATH, init_db, save_to_db
    from schema import COLUMNS, normalize_rows

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

    module_name = crawler["module"]
    if __package__:
        module_name = f"{__package__}.{module_name}"

    module = importlib.import_module(module_name)

    if not hasattr(module, "crawl"):
        raise AttributeError(f"{crawler['module']} 缺少 crawl(config) 函式")

    rows = module.crawl(config)
    normalized = normalize_rows(crawler["name"], rows)

    print(f"{crawler['name']} 完成，共 {len(normalized)} 筆")
    return normalized


def save_results(rows):
    if not rows:
        print("\n沒有資料可以輸出")
        return {
            "total": 0,
            "inserted": 0,
            "db_path": DB_PATH,
            "excel_path": None,
            "csv_path": None,
        }

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    df = pd.DataFrame(rows)
    df = df.reindex(columns=COLUMNS)
    df = dedupe_results(df)
    saved_count = save_to_db(df.to_dict("records"))

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    excel_path = os.path.join(OUTPUT_DIR, f"租屋總表_{timestamp}.xlsx")
    csv_path = os.path.join(OUTPUT_DIR, f"租屋總表_{timestamp}.csv")

    df.to_excel(excel_path, index=False)
    df.to_csv(csv_path, index=False, encoding="utf-8-sig")

    print("\n========== 整合完成 ==========")
    print(f"總筆數：{len(df)}")
    print(f"SQLite：{DB_PATH}")
    print(f"SQLite 目前保存筆數：{saved_count}")
    print(f"Excel：{excel_path}")
    print(f"CSV：{csv_path}")

    return {
        "total": len(df),
        "inserted": saved_count,
        "saved": saved_count,
        "storage_mode": "latest_snapshot",
        "db_path": DB_PATH,
        "excel_path": excel_path,
        "csv_path": csv_path,
    }


def dedupe_results(df):
    df = df.copy()

    # 第一層用連結去重，第二層再用地址/租金與標題/地址抓跨平台重複物件。
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


def run_all_crawlers(config, progress_callback=None):
    init_db()
    all_rows = []
    errors = []
    enabled_crawlers = [crawler for crawler in CRAWLERS if crawler["enabled"]]
    total_crawlers = len(enabled_crawlers)

    if progress_callback:
        progress_callback({
            "current": 0,
            "total": total_crawlers,
            "source": "",
            "message": "準備開始爬蟲",
        })

    for index, crawler in enumerate(enabled_crawlers, start=1):
        try:
            if progress_callback:
                progress_callback({
                    "current": index - 1,
                    "total": total_crawlers,
                    "source": crawler["name"],
                    "message": f"正在爬取 {crawler['name']}",
                })

            rows = run_crawler(crawler, config)
            all_rows.extend(rows)

            if progress_callback:
                progress_callback({
                    "current": index,
                    "total": total_crawlers,
                    "source": crawler["name"],
                    "message": f"{crawler['name']} 完成，共 {len(rows)} 筆",
                })
        except Exception as exc:
            message = f"{crawler['name']} 執行失敗：{exc}"
            print(message)
            errors.append(message)

            if progress_callback:
                progress_callback({
                    "current": index,
                    "total": total_crawlers,
                    "source": crawler["name"],
                    "message": message,
                })

    if progress_callback:
        progress_callback({
            "current": total_crawlers,
            "total": total_crawlers,
            "source": "",
            "message": "正在整理與儲存資料",
        })

    result = save_results(all_rows)
    result["errors"] = errors
    return result


def main():
    config = ask_search_config()
    run_all_crawlers(config)



if __name__ == "__main__":
    main()
