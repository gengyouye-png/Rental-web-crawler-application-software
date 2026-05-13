import requests

url = "https://www.sinyi.com.tw/"

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36" #反爬蟲
}

response = requests.get(url, headers=headers)

print(response.status_code)

if response.status_code == 200:
    with open("output.html", "w", encoding="utf-8") as f:
        f.write(response.text)
    print("寫入成功")
else:
    print("沒有抓取到網頁")