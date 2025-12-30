# 修復 "Cannot find type 'RTMPStream' in scope" 錯誤

## 問題
如果遇到 `Cannot find type 'RTMPStream' in scope` 錯誤，這通常是因為 HaishinKit 依賴沒有正確連結到專案。

## 解決方案

### 方案 1：使用 Swift Package Manager（推薦）

1. **在 Xcode 中打開專案**
   ```bash
   open HaishinKitTwitch.xcodeproj
   ```

2. **讓 Xcode 解析 Swift Package**
   - 在 Xcode 中，選擇 `File` > `Packages` > `Resolve Package Versions`
   - 或者等待 Xcode 自動解析（可能需要幾秒鐘）

3. **確認 Package 已添加**
   - 在 Project Navigator 中，展開專案
   - 應該能看到 `Package Dependencies` 區塊
   - 確認 `HaishinKit` 已列出

4. **清理並重新構建**
   - 按 `Cmd + Shift + K` 清理構建
   - 按 `Cmd + B` 重新構建專案

### 方案 2：使用 CocoaPods

如果 Swift Package Manager 有問題，可以使用 CocoaPods：

1. **安裝依賴**
   ```bash
   pod install
   ```

2. **開啟 workspace（不是 project）**
   ```bash
   open HaishinKitTwitch.xcworkspace
   ```

3. **清理並重新構建**
   - 在 Xcode 中按 `Cmd + Shift + K` 清理
   - 按 `Cmd + B` 重新構建

### 方案 3：手動添加 Package（如果上述方法都失敗）

1. 在 Xcode 中選擇專案（最上層的藍色圖標）
2. 選擇 `HaishinKitTwitch` target
3. 點擊 `Package Dependencies` 標籤
4. 點擊 `+` 按鈕
5. 輸入 URL: `https://github.com/HaishinKit/HaishinKit.swift`
6. 選擇版本規則：`Up to Next Major Version`，版本 `2.2.3`
7. 點擊 `Add Package`
8. 選擇 `HaishinKit` 產品並添加到 target

## 驗證

構建成功後，`ViewController.swift` 中的以下導入應該能正常工作：
```swift
import HaishinKit
```

並且 `RTMPStream` 和 `RTMPConnection` 類型應該能被識別。

## 如果問題仍然存在

1. **檢查 Xcode 版本**：確保使用 Xcode 15.0 或更高版本
2. **檢查 iOS 部署目標**：確保設定為 iOS 18.0
3. **重啟 Xcode**：有時需要完全重啟 Xcode
4. **刪除 DerivedData**：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

