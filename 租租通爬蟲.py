import requests
import pandas as pd

keyword = input("請輸入搜尋關鍵字：")

url = "https://api.dd-room.com/api/v1/search"

house_list = []

# 先抓第 1 頁，確認總共有幾頁
params = {
    "category": "house",
    "keywords": keyword,
    "order": "recommend",
    "sort": "desc",
    "page": 1
}

response = requests.get(url, params=params)
data = response.json()

last_page = data["data"]["search"]["last_page"]

print("總頁數：", last_page)

max_page = min(last_page, 20)

# 從第 1 頁抓到最後一頁
for page in range(1, max_page + 1):
    print("正在抓第", page, "頁")

    params = {
        "category": "house",
        "keywords": keyword,
        "order": "recommend",
        "sort": "desc",
        "page": page
    }

    response = requests.get(url, params=params)
    data = response.json()

    items = data["data"]["search"]["items"]

    for item in items:
        house_data = {
            "標題": item["title"],
            "租金": item["rent"],
            "地址": item["address"],
            "樓層": item["floor"],
            "坪數": item["ping"],
            "房型": item["type_space_name"]
        }

        house_list.append(house_data)

df = pd.DataFrame(house_list)

df.to_excel(r"C:\Users\HuanYu\Desktop\租屋資料.xlsx", index=False)

print("完成，共抓到", len(house_list), "筆資料")
