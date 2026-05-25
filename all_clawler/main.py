# main.py


import subprocess
import os
import pandas as pd
from glob import glob


BASE_DIR = os.path.dirname(os.path.abspath(__file__))


# ====== 要執行的爬蟲 ======
crawler_files = [
    "clawler_591.py",
    "clawler_sinyi.py",
    "zuzutong.py"
]


# ====== 執行所有爬蟲 ======
def run_all_crawlers():

    for file in crawler_files:

        file_path = os.path.join(BASE_DIR, file)

        print(f"\n========== 開始執行 {file} ==========")

        try:

            subprocess.run(
                ["python", file_path],
                check=True
            )

            print(f"\n{file} 執行完成")

        except Exception as e:

            print(f"\n{file} 執行失敗")
            print(e)


# ====== 合併所有 Excel ======
def merge_excel_files():

    excel_files = glob(os.path.join(BASE_DIR, "*.xlsx"))

    # 排除最後輸出的總表
    excel_files = [
        f for f in excel_files
        if "總表" not in os.path.basename(f)
    ]

    if not excel_files:
        print("\n找不到 Excel 檔案")
        return

    all_df = []

    for file in excel_files:

        try:

            print(f"讀取：{os.path.basename(file)}")

            df = pd.read_excel(file)

            # 新增來源檔名
            df["來源檔案"] = os.path.basename(file)

            all_df.append(df)

        except Exception as e:

            print(f"讀取失敗：{file}")
            print(e)

    if not all_df:
        print("\n沒有成功讀取的資料")
        return

    merged_df = pd.concat(all_df, ignore_index=True)

    # ===== 去重 =====
    merged_df.drop_duplicates(inplace=True)

    output_path = os.path.join(BASE_DIR, "租屋總表.xlsx")

    merged_df.to_excel(output_path, index=False)

    print(f"\n已輸出總表：{output_path}")
    print(f"總筆數：{len(merged_df)}")


if __name__ == "__main__":

    run_all_crawlers()

    merge_excel_files()

    print("\n全部完成")