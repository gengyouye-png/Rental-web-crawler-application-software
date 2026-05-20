import requests
import urllib3
import pandas as pd

urllib3.disable_warnings()

# 模擬瀏覽器
headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36"
}


# 取得台中地區代號
def get_taichung_area_map():

    area_url = "https://static.houseprice.tw/houseprice-rent/static/json/area.json"

    response = requests.get(
        area_url,
        headers=headers,
        verify=False
    )

    area_data = response.json()

    area_map = {}

    for city in area_data:

        if city["cityName"] == "台中市":

            for area in city["areaList"]:

                area_name = area["areaName"]
                sid = str(area["sid"])

                area_map[area_name] = sid

    return area_map


# 房型對照表
case_type_map = {
    "整層住家": "1",
    "獨立套房": "2",
    "分租套房": "3",
    "雅房": "4",
    "其他": "5"
}


# 價格區間對照表
price_map = {
    "1": "-10000",
    "2": "10000-15000",
    "3": "15000-20000",
    "4": "20000-30000",
    "5": "30000-"
}


print("===== 5168 租屋爬蟲 =====")

# 取得地區資料
area_map = get_taichung_area_map()

print("\n可輸入台中地區：")
print("、".join(area_map.keys()))

# 使用者輸入地區
area_name = input("\n請輸入台中地區：")

if area_name not in area_map:
    print("查無此地區")
    exit()

zipcode = area_map[area_name]


# 價格選單
print("\n價格區間：")
print("1. 10000元以下")
print("2. 10000~15000")
print("3. 15000~20000")
print("4. 20000~30000")
print("5. 30000以上")

price_choice = input("請輸入價格選項：")

if price_choice not in price_map:
    print("價格選項錯誤")
    exit()

price = price_map[price_choice]


# 房型選單
print("\n房型選項：")
print("整層住家")
print("獨立套房")
print("分租套房")
print("雅房")
print("其他")

print("\n多選請用逗號分隔")
print("例如：整層住家,獨立套房")

case_type_names = input("請輸入房型：")

casetype_list = []

for name in case_type_names.split(","):

    name = name.strip()

    if name in case_type_map:
        casetype_list.append(case_type_map[name])

casetype = "-".join(casetype_list)


# 固定住宅租屋
usage = "21"

house_list = []

# 固定抓前20頁
for page in range(1, 21):

    print(f"\n正在抓第 {page} 頁")

    url = f"https://rent.houseprice.tw/api/RentCaseList/Search/{usage}_usage/{zipcode}_zip/{price}_price/{casetype}_casetype/?p={page}"

    response = requests.get(
        url,
        headers=headers,
        verify=False
    )

    if response.status_code != 200:
        print("API請求失敗")
        break

    data = response.json()

    items = data["data"]["rentCaseInfo"]

    # 沒資料停止
    if len(items) == 0:
        print("沒有更多資料")
        break

    # 整理資料
    for item in items:

        house_data = {
            "標題": item["caseName"],
            "租金": item["rentPrice"],
            "縣市": item["city"],
            "行政區": item["district"],
            "路段": item["road"],
            "坪數": item["totalPin"],
            "房間數": item["room"],
            "類型": item["purposeName"],
            "所在樓層": item["fromFloor"],
            "總樓層": item["roofLevel"]
        }

        house_list.append(house_data)


# 轉 DataFrame
df = pd.DataFrame(house_list)

# 匯出 Excel
df.to_excel(
      r"C:\Users\HuanYu\Desktop\爬蟲網路\5168租屋資料.xlsx", index=False)

print("\n===== 完成 =====")
print("共抓取", len(house_list), "筆資料")
print("Excel 已儲存")