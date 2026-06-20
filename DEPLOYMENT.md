# 公開部署說明

這個專案現在可以用同一個 Flask 服務同時提供：

- Flutter Web 前端：`/`
- Flask API：`/api/*`

## 本機產生網頁版

```powershell
cd rent_app
flutter build web --release
cd ..
python flask_api.py
```

完成後開啟 `http://127.0.0.1:5000`，前端會自動使用同一個網域的 API。

## 雲端部署重點

1. 先產生 Flutter Web build，確認 `rent_app/build/web/index.html` 存在。
2. 部署 Python 後端時安裝根目錄的 `requirements.txt`。
3. 生產啟動命令使用：

```bash
gunicorn flask_api:app --bind 0.0.0.0:$PORT
```

4. 如果部署平台會重建環境，需要另外安裝爬蟲瀏覽器依賴：

```bash
python -m playwright install chromium
```

## 注意事項

- 公開網站模式下，前端預設呼叫目前網域，例如 `https://your-domain.com/api/health`。
- 爬蟲會由公開 API 觸發，正式上線前建議再加上管理密碼、速率限制，避免陌生人連續啟動爬蟲。
- SQLite 適合小型公開試用；如果多人使用或資料量增加，建議改 PostgreSQL。
