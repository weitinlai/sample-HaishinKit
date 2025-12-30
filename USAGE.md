# 使用指南

## 快速開始

### 1. 安裝依賴

專案使用 Swift Package Manager，Xcode 會自動解析依賴。如果沒有自動解析：

1. 在 Xcode 中選擇專案
2. 選擇 `HaishinKitTwitch` target
3. 點擊 `Package Dependencies` 標籤
4. 點擊 `+` 按鈕添加包
5. 輸入 URL: `https://github.com/HaishinKit/HaishinKit.swift`
6. 選擇版本並添加

### 2. 開啟專案

```bash
cd /Users/ai/Source/sample-HaishinKit
open HaishinKitTwitch.xcodeproj
```

### 3. 設定開發者帳號（實體裝置）

如果要在實體裝置上運行：
1. 在 Xcode 中選擇專案
2. 選擇 `HaishinKitTwitch` target
3. 在 `Signing & Capabilities` 中選擇您的開發者帳號

### 4. 執行應用程式

1. 選擇目標裝置（模擬器或實體裝置）
2. 按 `Cmd + R` 或點擊運行按鈕
3. 等待應用程式啟動

## 使用應用程式

### 基本使用

1. **啟動應用程式**
   - 應用程式會顯示預覽畫面和控制按鈕

2. **開始直播**
   - 點擊「開始直播」按鈕
   - 首次使用時會要求相機和麥克風權限，請點擊「允許」
   - 應用程式會自動連線到 Twitch
   - 狀態標籤會顯示連線狀態

3. **停止直播**
   - 點擊「停止直播」按鈕
   - 串流會立即停止

### 功能說明

#### 相機和麥克風串流
- 預設使用裝置的相機和麥克風
- 相機畫面會顯示在預覽視圖中
- 音訊會從麥克風捕獲

#### WAV 音訊檔案（可選）
- 如果要使用 WAV 檔案而不是麥克風：
  1. 將 WAV 檔案命名為 `sample.wav`
  2. 在 Xcode 中右鍵點擊專案
  3. 選擇 "Add Files to HaishinKitTwitch..."
  4. 選擇 `sample.wav` 檔案
  5. 確保勾選 "Copy items if needed"
  6. 點擊 "Add"

#### JPG 圖片輪播（可選）
- 如果要輪播圖片：
  1. 將圖片命名為 `sample1.jpg`, `sample2.jpg`, `sample3.jpg` 等
  2. 在 Xcode 中將這些圖片添加到專案
  3. 應用程式會每 3 秒自動切換圖片
  4. 圖片會疊加在相機畫面上（半透明）

### 狀態說明

- **準備就緒**：應用程式已準備好，等待開始直播
- **正在連線...**：正在連線到 Twitch 伺服器
- **已連線 - 開始串流...**：已連線，正在開始串流
- **已連線 - 直播中**：正在直播，觀眾可以看到您的串流
- **連線失敗**：無法連線到 Twitch，請檢查網路和 Stream Key
- **已停止**：串流已停止

## 疑難排解

### 無法連線到 Twitch

1. **檢查 Stream Key**
   - 確認 Stream Key 是否正確
   - Stream Key 在 `ViewController.swift` 第 26 行

2. **檢查網路連線**
   - 確保裝置連接到網路
   - 建議使用 Wi-Fi 而不是行動網路

3. **檢查 Twitch 服務狀態**
   - 訪問 [Twitch Status](https://status.twitch.tv/) 確認服務正常

### 沒有視訊

1. **檢查相機權限**
   - 前往「設定」>「隱私權與安全性」>「相機」
   - 確認應用程式有相機權限

2. **檢查相機是否被其他應用程式使用**
   - 關閉其他使用相機的應用程式

### 沒有音訊

1. **檢查麥克風權限**
   - 前往「設定」>「隱私權與安全性」>「麥克風」
   - 確認應用程式有麥克風權限

2. **檢查音量設定**
   - 確認裝置音量不是靜音

### 應用程式崩潰

1. **檢查 Xcode 控制台**
   - 查看錯誤訊息
   - 確認所有依賴都已正確安裝

2. **清理並重新構建**
   - 在 Xcode 中按 `Cmd + Shift + K` 清理
   - 按 `Cmd + B` 重新構建

## 在 Twitch 上查看直播

1. 登入您的 Twitch 帳號
2. 前往您的頻道頁面：`https://www.twitch.tv/您的使用者名稱`
3. 如果正在直播，您會看到直播畫面
4. 您也可以使用 Twitch Studio 或其他工具來管理直播

## 注意事項

⚠️ **安全提醒**
- Stream Key 是敏感資訊，請勿分享給他人
- 建議定期更換 Stream Key
- 不要將 Stream Key 提交到公開的版本控制系統

📱 **裝置要求**
- 建議使用實體裝置進行測試
- 模擬器可能無法使用相機和麥克風
- 確保裝置有足夠的電量或連接電源

🌐 **網路要求**
- 串流需要穩定的網路連線
- 建議上傳速度至少 3 Mbps
- 使用 Wi-Fi 比行動網路更穩定

## 進階設定

### 修改串流品質

在 `ViewController.swift` 的 `setupStream()` 方法中，您可以修改：

```swift
// 視訊解析度（目前：1280x720）
// 音訊位元率（目前：128 kbps）
// 視訊位元率（目前：2.5 Mbps）
```

### 修改圖片切換間隔

在 `startImageRotation()` 方法中，修改 `withTimeInterval` 參數：

```swift
imageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) {
    // 3.0 秒 = 每 3 秒切換一次
}
```

## 技術支援

如果遇到問題：
1. 檢查 [README.md](README.md) 和 [SETUP.md](SETUP.md)
2. 查看 [FIX_IMPORT_ERROR.md](FIX_IMPORT_ERROR.md) 了解常見錯誤
3. 參考 [HaishinKit 官方文檔](https://github.com/HaishinKit/HaishinKit.swift)

