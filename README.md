# HaishinKit Twitch 串流專案

這是一個最小可行的 iOS 專案，使用 HaishinKit 將 WAV 音訊和 JPG 圖片串流到 Twitch。

## 功能特色

- ✅ 使用 HaishinKit 進行 RTMP 串流
- ✅ 支援 WAV 音訊檔案播放
- ✅ 支援 JPG 圖片輪播串流
- ✅ 支援相機和麥克風串流（備用方案）
- ✅ 串流到 Twitch 平台

## 需求

- iOS 18.0 或更高版本
- Xcode 15.0 或更高版本
- CocoaPods 或 Swift Package Manager
- Twitch Stream Key

## 安裝步驟

### 1. 安裝 CocoaPods 依賴

```bash
cd /Users/ai/Source/sample-HaishinKit
pod install
```

### 2. 開啟專案

開啟 `HaishinKitTwitch.xcworkspace`（不是 `.xcodeproj`）

```bash
open HaishinKitTwitch.xcworkspace
```

### 3. 設定 Twitch Stream Key

在 `ViewController.swift` 中，找到以下行並替換為您的 Twitch Stream Key：

```swift
private let twitchStreamKey = "YOUR_TWITCH_STREAM_KEY_HERE"
```

**如何取得 Twitch Stream Key：**
1. 登入 [Twitch Creator Dashboard](https://dashboard.twitch.tv/)
2. 前往 Settings > Stream
3. 複製 Primary Stream Key

### 4. 新增資源檔案（可選）

#### WAV 音訊檔案
將您的 WAV 檔案命名為 `sample.wav` 並加入到專案中：
- 在 Xcode 中右鍵點擊專案
- 選擇 "Add Files to..."
- 選擇 `sample.wav` 檔案
- 確保 "Copy items if needed" 已勾選

#### JPG 圖片檔案
將您的 JPG 圖片命名為 `sample1.jpg`, `sample2.jpg`, `sample3.jpg` 等，並加入到專案中：
- 在 Xcode 中右鍵點擊專案
- 選擇 "Add Files to..."
- 選擇所有 JPG 檔案
- 確保 "Copy items if needed" 已勾選

**注意：** 如果沒有提供 WAV 或 JPG 檔案，應用程式會自動使用麥克風和相機作為替代方案。

## 使用方式

1. 執行應用程式
2. 點擊「開始直播」按鈕
3. 允許相機和麥克風權限（如果尚未授權）
4. 應用程式會自動連線到 Twitch 並開始串流
5. 點擊「停止直播」按鈕來結束串流

## 專案結構

```
HaishinKitTwitch/
├── AppDelegate.swift          # 應用程式委派
├── ViewController.swift       # 主要的串流控制器
├── Main.storyboard            # 主介面
├── LaunchScreen.storyboard      # 啟動畫面
├── Info.plist                  # 應用程式設定
└── Assets.xcassets            # 資源檔案
```

## 技術細節

### 串流設定

- **iOS 版本：** iOS 18.0+
- **視訊解析度：** 1280x720 (720p)
- **視訊位元率：** 2.5 Mbps
- **音訊位元率：** 128 kbps
- **音訊取樣率：** 44.1 kHz

### 圖片輪播

如果提供了多張 JPG 圖片，應用程式會每 3 秒自動切換一張圖片進行串流。

### 音訊處理

- 如果提供了 `sample.wav` 檔案，應用程式會使用 AVAudioEngine 播放該檔案
- 如果沒有提供 WAV 檔案，應用程式會使用麥克風作為音訊來源

## 注意事項

1. **Stream Key 安全：** 請勿將 Stream Key 提交到版本控制系統（如 Git）。建議使用環境變數或配置檔案（已加入 .gitignore）。

2. **網路需求：** 串流需要穩定的網路連線，建議使用 Wi-Fi。

3. **權限：** 應用程式需要相機和麥克風權限才能進行串流。

4. **圖片串流限制：** HaishinKit 主要設計用於相機串流。圖片串流功能可能需要額外的實作來完全支援。

## 疑難排解

### 無法連線到 Twitch
- 檢查 Stream Key 是否正確
- 確認網路連線正常
- 檢查 Twitch 服務狀態

### 沒有音訊
- 確認已授權麥克風權限
- 如果使用 WAV 檔案，確認檔案已正確加入到專案中

### 沒有視訊
- 確認已授權相機權限
- 如果使用 JPG 圖片，確認圖片已正確加入到專案中

## 授權

此專案僅供學習和示範用途。

## 參考資源

- [HaishinKit GitHub](https://github.com/shogo4405/HaishinKit.swift)
- [Twitch Stream Key 指南](https://help.twitch.tv/s/article/how-to-use-stream-key)
- [RTMP 協議規範](https://www.adobe.com/devnet/rtmp.html)

