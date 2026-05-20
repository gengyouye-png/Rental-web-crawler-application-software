import requests
import urllib3
import pandas as pd
from urllib.parse import quote

urllib3.disable_warnings()

# 模擬瀏覽器
headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36"
}


# 房型對照表
case_type_map = {
    "整層住家": "1",
    "獨立套房": "2",
    "分租套房": "3",
    "雅房": "4",
    "其他": "5"
}


# 依照使用者輸入的最高金額，轉成 5168 API 可接受的價格區間
# 注意：5168 的 API 是區間查詢，所以後面還會再用程式過濾一次真正的最高金額
def get_api_price_range(max_price):
    if max_price <= 10000:
        return "-10000"
    elif max_price <= 15000:
        return "10000-15000"
    elif max_price <= 20000:
        return "15000-20000"
    elif max_price <= 30000:
        return "20000-30000"
    else:
        return "30000-"


# 把租金轉成整數，避免出現逗號或文字造成比較錯誤
def parse_price(price_text):
    if price_text is None:
        return 0

    price_text = str(price_text)
    number_text = ""

    for ch in price_text:
        if ch.isdigit():
            number_text += ch

    if number_text == "":
        return 0

    return int(number_text)


print("===== 5168 租屋爬蟲｜關鍵字搜尋版 =====")

# 1. 輸入關鍵字
keyword = input("\n請輸入關鍵字：").strip()

if keyword == "":
    print("關鍵字不可空白")
    exit()

keyword_encoded = quote(keyword)


# 2. 輸入最高金額
max_price_input = input("請輸入最高金額：").strip()

if not max_price_input.isdigit():
    print("最高金額請輸入數字，例如：15000")
    exit()

max_price = int(max_price_input)
price = get_api_price_range(max_price)


# 3. 輸入房型
print("\n房型選項：")
print("整層住家")
print("獨立套房")
print("分租套房")
print("雅房")
print("其他")
print("\n多選請用逗號分隔，例如：整層住家,獨立套房")

case_type_names = input("請輸入房型：").strip()

casetype_list = []

for name in case_type_names.split(","):
    name = name.strip()

    if name in case_type_map:
        casetype_list.append(case_type_map[name])

if len(casetype_list) == 0:
    print("房型輸入錯誤")
    exit()

casetype = "-".join(casetype_list)


# 固定住宅租屋
usage = "21"

# 關鍵字搜尋時，zip 可以用全台範圍
# 這一串是你提供的 API 範例中的 zip 條件
zipcode = "120-126-115"

house_list = []

# 固定抓前 20 頁
for page in range(1, 21):

    print(f"\n正在抓第 {page} 頁")

    url = f"https://rent.houseprice.tw/api/RentCaseList/Search/{usage}_usage/{zipcode}_zip/{price}_price/{casetype}_casetype/{keyword_encoded}_kw/?p={page}"

    response = requests.get(
        url,
        headers=headers,
        verify=False
    )

    if response.status_code != 200:
        print("API 請求失敗")
        print("狀態碼：", response.status_code)
        break

    data = response.json()

    items = data["data"]["rentCaseInfo"]

    # 沒資料停止
    if len(items) == 0:
        print("沒有更多資料")
        break

    # 整理資料
    for item in items:

        rent_price = parse_price(item.get("rentPrice"))

        # 因為 API 是區間查詢，所以這裡再次過濾最高金額
        if rent_price > max_price:
            continue

        house_data = {
            "標題": item.get("caseName"),
            "租金": rent_price,
            "縣市": item.get("city"),
            "行政區": item.get("district"),
            "路段": item.get("road"),
            "坪數": item.get("totalPin"),
            "房間數": item.get("room"),
            "類型": item.get("purposeName"),
            "所在樓層": item.get("fromFloor"),
            "總樓層": item.get("roofLevel")
        }

        house_list.append(house_data)


# 轉 DataFrame
if len(house_list) == 0:
    print("\n沒有符合條件的資料")
else:
    df = pd.DataFrame(house_list)

    # 匯出 Excel
    output_path = r"C:\Users\HuanYu\Desktop\爬蟲網路\5168租屋資料_關鍵字搜尋.xlsx"

    df.to_excel(output_path, index=False)

    print("\n===== 完成 =====")
    print("共抓取", len(house_list), "筆資料")
    print("Excel 已儲存：", output_path)
