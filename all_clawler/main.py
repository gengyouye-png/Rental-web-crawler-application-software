import pandas as pd
from concurrent.futures import ThreadPoolExecutor, as_completed

# ====== import 真正爬蟲 ======
from clawler_591 import main as crawler_591
from clawler_sinyi import main as crawler_sinyi
from zuzutong import main as crawler_zuzutong


# ====== 統一管理所有爬蟲 ======
crawlers = [
    crawler_591,
    crawler_sinyi,
    crawler_zuzutong
]


def run_all_crawlers():

    all_data = []

    with ThreadPoolExecutor(max_workers=len(crawlers)) as executor:

        futures = [
            executor.submit(crawler)
            for crawler in crawlers
        ]

        for future in as_completed(futures):

            try:
                result = future.result()

                if result:
                    all_data.extend(result)

            except Exception as e:
                print("爬蟲錯誤：", e)

    return all_data


# ====== 輸出 Excel ======
def save_to_excel(data, filename="output.xlsx"):

    df = pd.DataFrame(data)

    columns_order = [
        "title",
        "price",
        "source"
    ]

    df = df.reindex(columns=columns_order)

    df.to_excel(filename, index=False)

    print(f"已輸出：{filename}")


if __name__ == "__main__":

    data = run_all_crawlers()

    print("總資料筆數：", len(data))

    save_to_excel(data)