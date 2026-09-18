# 小畫家 for Mac

以 Swift / AppKit 實作的 macOS 原生繪圖 App，介面可在 **Windows 11 / Windows 10 / Windows 7 / Windows XP** 四種小畫家之間切換。獨立開發，非 Microsoft 官方產品。

## 執行

```sh
./build.sh
./test.sh
open build/Paint.app
```

打包成 Releases 用的 zip：

```sh
./release.sh 2.1.0            # 建置、測試並產生 build/release/Paint-mac-2.1.0.zip
./release.sh 2.1.0 publish    # 同上，並用 gh 建立 GitHub Release
```

使用已安裝的 Command Line Tools，不需要第三方套件。建置目標為 Apple Silicon、macOS 13 以上；自動移除背景需要 macOS 14 以上。App 採本機 ad-hoc 簽署，未經 Apple 公證，第一次開啟請在 Finder 按右鍵選「打開」。

## 切換外觀

「檢視 → 外觀」、macOS 選單列的「檢視 → 外觀」，或工具列右端的齒輪都可以切換。選擇會記在 `UserDefaults`，下次開啟沿用。預設是 Windows 11，預設縮放是 100%。

### Windows 11（預設）

Fluent 單列工具列：選單列（檔案／編輯／檢視＋儲存、分享、復原、重做、設定），工具列為 選取項目｜影像｜工具｜筆刷｜形狀｜色彩｜Copilot｜圖層，圓形色票、畫布左側浮動的「大小」與「不透明度」直立滑桿，狀態列顯示游標座標、選取大小、畫布大小與縮放控制。

### Windows 10

扁平 ribbon：藍色「檔案」索引標籤 ＋ 常用／檢視兩個分頁，群組為 剪貼簿｜影像｜工具｜筆刷｜形狀｜大小｜色彩｜圖層，方形色票，畫布區為 `#C6CFE0 → #D8E1F0` 的漸層（取樣自實機截圖）。

### Windows 7

同樣的 ribbon 結構，改用 Aero 配色：淡藍工具列、圓角索引標籤、琥珀色 hover，畫布區為藍灰漸層。

### Windows XP

經典版面：功能表列（檔案／編輯／檢視／影像／色彩／說明）、左側 2×8 工具箱與工具選項框、底部 28 色調色盤與前景／背景色指示器、兩段式狀態列，全部使用 Windows 3D 立體邊框與 `#ECE9D8` Luna 配色，畫布靠左上角對齊、周圍為 `#808080`。

## 功能

- 鉛筆、筆刷、書法筆、螢光筆、噴槍、透明橡皮擦、連通區域填色、色彩選擇器、放大鏡。
- 23 種圖形：直線、曲線、橢圓形、矩形、圓角矩形、多邊形、三角形、直角三角形、菱形、五邊形、六邊形、四向箭頭、四／五／六角星、三種圖說文字、心形、閃電。Shift 等比例繪製，外框／填滿樣式可切換。曲線支援兩段弧度調整，多邊形可連續點選頂點、雙擊或回到起點封閉。
- 畫布內直接輸入多行文字、字型、大小；Command-Enter 完成、Esc 取消。
- 矩形選取、移動、剪下、複製、貼上、裁剪、調整大小和扭曲、旋轉與翻轉。
- 多圖層、顯示／隱藏、不透明度、排序、複製、刪除與合併。
- 復原／重做、10–800% 縮放、符合視窗、400% 以上像素格線。
- PNG、JPEG、BMP、TIFF 圖片輸出、列印、系統分享，以及保留圖層的 `.paintmac` 專案。
- macOS Vision 自動移除背景：本機分析目前圖層；若找不到前景會顯示錯誤。

所有圖示、按鈕、色票、滑桿與立體邊框都以 `NSBezierPath` 自繪，不使用 SF Symbols，以免出現 macOS 風格的外觀。

## 快捷鍵

Command-N 新增、Command-O 開啟、Command-S 儲存、Command-Shift-S 另存專案、Command-Shift-E 匯出圖片、Command-P 列印。
Command-Z 復原、Command-Shift-Z 重做、Command-X/C/V 剪下／複製／貼上、Command-A 全選。
Delete 刪除選取、Escape 取消目前拖曳或選取、Command-0 實際大小、Command-1 符合視窗、Command-G 格線。

## 驗證與限制

`test.sh` 包含 39 項檢查，驗證文字編輯完成／取消／復原、拖曳取消與歷史還原、不支援輸出格式的拒絕，以及像素方向、筆刷／形狀／橡皮擦落點、文字位置、填色邊界、透明合成、裁剪、旋轉、縮放、復原及檔案讀寫。輸出在 `build/tests/artifacts`。

與原版仍有差異：

- macOS 的視窗標題列與紅黃綠按鈕由系統繪製，換不成 Windows 的標題列與最小化／最大化／關閉；Windows 10／7 皮膚原本放在標題列的快速存取工具列，這裡移到索引標籤列右端。App 同時保留 macOS 標準選單列。
- 未實作任意選取（XP 工具箱第一格顯示為停用）、Microsoft 的雲端 AI 生圖、Cocreator、影像建立與可重新編輯的向量圖形物件。Copilot 按鈕僅連到本機的「移除背景」。
- 一般影像輸出會合併可見圖層；保留圖層請使用 `.paintmac`。GIF 可匯入第一幀，儲存時會另存為 `.paintmac` 專案。
- 字型優先使用 Segoe UI／微軟正黑體（XP 皮膚為 Tahoma），若系統未安裝則退回系統字型，字樣會與 Windows 略有不同。
