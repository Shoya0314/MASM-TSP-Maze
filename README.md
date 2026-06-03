# 🏆 MASM-TSP-Maze (動態迷宮尋寶遊戲)

**系統程式期末專題：基於 32-bit MASM 的動態迷宮與 TSP 尋路演算法**

本專案是一個使用 **MASM (x86 組合語言)** 撰寫的終端機迷宮尋寶遊戲。結合了基礎資料結構與圖論演算法，在底層硬體架構中實現動態地圖生成與最佳路徑運算。本專案採用 32-bit 架構並搭配 Kip Irvine 教授的 Irvine32 函式庫進行開發。

## ✨ 核心特色與演算法

* **🎲 動態迷宮生成 (Iterative DFS)**
  捨棄容易導致 Stack Overflow 的遞迴呼叫，手動在記憶體中維護陣列堆疊 (Stack) 模擬遞迴。透過深度優先搜尋演算法，每次執行皆會生成 100% 絕對連通且具備挑戰性的隨機迷宮。
* **🧠 動態評分系統 (BFS + TSP 暴力窮舉)**
  遊戲不僅僅是走到出口，系統會在背景執行 9 次 **廣度優先搜尋 (BFS)** 算出起點、3 個寶物與出口兩兩之間的最短距離，並使用窮舉法解決 **旅行推銷員問題 (TSP)** ($3! = 6$ 種組合)，算出理論上「吃完所有寶物並走到出口」的絕對最短步數。
* **🎮 智慧評價機制 (S / A / B Rank)**
  玩家通關後，系統會比對玩家實際步數與 TSP 理論最短步數：
  * **Rank S**: 步數與理論最短步數完全一致（完美路線）。
  * **Rank A**: 誤差在 10 步以內。
  * **Rank B**: 誤差過大，系統會無情印出理論最短步數供玩家參考。
* **⚡ 現代化 32-bit I/O 控制**
  使用 Irvine32 函式庫封裝的 Win32 Console API (`call ReadChar`, `call Clrscr`)，徹底解決早期 16-bit DOS 中斷 (`INT 21h`) 容易被中文輸入法卡死的問題，提供流暢的遊戲體驗。

## 🎮 遊戲玩法與控制

* **目標**：控制玩家 (`P`)，收集迷宮中所有的寶物 (`T`)，最後抵達出口 (`E`)。
* **操作方式**：
  * `W` / `↑` : 向上移動
  * `S` / `↓` : 向下移動
  * `A` / `←` : 向左移動
  * `D` / `→` : 向右移動
* **介面**：畫面上方會即時顯示目前消耗的 **步數 (Steps)** 以及已收集的 **寶物數量 (Treasures)**。

## 🚀 開發與執行環境

本專案升級為 32-bit Windows 應用程式，捨棄老舊的 DOSBox，可直接於現代 Windows 系統執行。

* **開發工具**: Visual Studio (2019/2022) 含 C++ 桌面開發工作負載
* **編譯器**: Microsoft Macro Assembler (ML.EXE)
* **外部依賴**: [Irvine32 Library (Kip Irvine 7th Edition)](http://www.asmirvine.com/)

### 🛠️ 如何在本機編譯執行

1. 將本專案 Clone 到本機：
   ```bash
   git clone [https://github.com/Shoya0314/MASM-TSP-Maze.git](https://github.com/Shoya0314/MASM-TSP-Maze.git)
