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

## 本機伺服器模式

目前主流程回到本機 Flask 即時爬蟲：

```text
使用者開啟 http://127.0.0.1:5000
  -> Flask 提供 Flutter Web
  -> 前端呼叫同一台 Flask API
  -> /api/crawl 即時執行爬蟲
  -> SQLite 保存最新快照
```

如果重新安裝環境，需要安裝爬蟲瀏覽器依賴：

```bash
python -m playwright install chromium
```

## 注意事項

- Firebase 目前只負責登入與收藏，不負責執行爬蟲。
- `users/{uid}/favorites/{favoriteId}`：登入使用者自己的收藏。
- 即時爬蟲由本機 Flask API 觸發，電腦與 Flask 需要開著。
- SQLite 適合本機試用；如果多人使用或資料量增加，再考慮 PostgreSQL。
