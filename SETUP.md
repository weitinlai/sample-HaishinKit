# 快速設定指南

## 1. 安裝依賴

```bash
pod install
```

## 2. 開啟專案

```bash
open HaishinKitTwitch.xcworkspace
```

**重要：** 必須開啟 `.xcworkspace` 檔案，不是 `.xcodeproj`！

## 3. 設定 Twitch Stream Key

編輯 `HaishinKitTwitch/ViewController.swift`，找到第 20 行：

```swift
private let twitchStreamKey = "YOUR_TWITCH_STREAM_KEY_HERE"
```

替換為您的實際 Stream Key。

## 4. 新增資源檔案（可選）

### WAV 音訊檔案
- 將檔案命名為 `sample.wav`
- 拖放到 Xcode 專案中
- 確保勾選 "Copy items if needed"

### JPG 圖片檔案
- 將圖片命名為 `sample1.jpg`, `sample2.jpg`, `sample3.jpg` 等
- 拖放到 Xcode 專案中
- 確保勾選 "Copy items if needed"

## 5. 執行專案

1. 選擇目標裝置（模擬器或實體裝置）
2. 按 Cmd+R 執行
3. 點擊「開始直播」按鈕

## 注意事項

- 實體裝置需要開發者帳號才能執行
- 確保網路連線穩定（建議使用 Wi-Fi）
- 首次執行會要求相機和麥克風權限

