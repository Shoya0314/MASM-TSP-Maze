.model small
.stack 1000h    ; 堆疊開大一點比較不會當機

.data
    ; 迷宮基本設定
    wid equ 21
    hei equ 11
    map db 231 dup('#')    ; 預設全部填滿牆壁'#'

    ; 迷宮生成變數
    ; 跨兩格的方向，用來找下一個目標
    dx2 dw 0, 2, 0, -2
    dy2 dw -2, 0, 2, 0
    ; 跨一格的方向，用來把中間的牆壁打通
    dx1 dw 0, 1, 0, -1
    dy1 dw -1, 0, 1, 0
    cur_x dw 1
    cur_y dw 1
    dirs db 4 dup(0)       ; 記錄有幾個方向可以走
    d_count db 0
    seed dw 0              ; 亂數種子
    
    ; 自建陣列堆疊
    m_stack_x dw 250 dup(0)
    m_stack_y dw 250 dup(0)
    m_sp dw 0              ; 堆疊指標

    ; BFS尋路與TSP演算法變數
    ; 用陣列模擬Queue做BFS
    q_x dw 250 dup(0)
    q_y dw 250 dup(0)
    q_head dw 0
    q_tail dw 0
    dist db 231 dup(255)   ; 記錄步數，255代表還沒走過
    bfs_dx dw 0, 1, 0, -1
    bfs_dy dw -1, 0, 1, 0
    new_dist db 0          ; 暫存新的距離，避免暫存器卡住
    
    ; 每次呼叫BFS時要傳入的起點與終點
    bfs_sx dw 0
    bfs_sy dw 0
    bfs_tx dw 0
    bfs_ty dw 0
    
    ; 儲存3個寶物+出口之間9段節點的最短距離
    d_P_T1 dw 0
    d_P_T2 dw 0
    d_P_T3 dw 0
    d_T1_T2 dw 0
    d_T1_T3 dw 0
    d_T1_E dw 0
    d_T2_T3 dw 0
    d_T2_E dw 0
    d_T3_E dw 0
    
    shortest_steps dw 9999 ; TSP最短路徑

    ; 遊戲狀態
    px dw 1
    py dw 1
    got_t db 0             ; 已經吃到的寶物數量
    total_steps dw 0       ; 玩家目前走的步數

    ; 介面文字
    msg_start  db "Press any key to generate a random maze...$"
    msg_title  db "=== MASM TSP Maze (Final) ===", 13, 10, '$'
    msg_step   db "Steps: $"
    msg_treas  db "   Treasures: $"
    msg_win    db 13, 10, "Congratulations! You Escaped!$"
    msg_rank_s db 13, 10, "Rank: S (Perfect TSP Route!)$"
    msg_rank_a db 13, 10, "Rank: A (Good! You took a few detours)$"
    msg_rank_b db 13, 10, "Rank: B (You can do better!)$"
    msg_missed db 13, 10, "The absolute shortest TSP path was: $"
    msg_replay db 13, 10, 13, 10, "Play again? (y/n): $"
    enter_line db 13, 10, '$'

.code
JUMPS

main proc
    mov ax, @data
    mov ds, ax

    ; 顯示等待提示
    lea dx, msg_start
    mov ah, 09h
    int 21h

Wait_Start:
    ; 利用按按鍵的反應時間差來跑迴圈，確保每次迷宮都長得不一樣
    inc seed
    mov ah, 01h      ; 看有沒有按按鍵
    int 16h
    jz Wait_Start    ; 沒按就繼續累加seed
    mov ah, 00h      ; 有按就把按鍵讀出來清掉
    int 16h

Restart_Game:
    ; 重置玩家座標與狀態
    mov px, 1
    mov py, 1
    mov got_t, 0
    mov total_steps, 0

    ; 把map陣列清空重新填滿'#'
    mov cx, 231
    mov bx, 0
Clean_Map:
    mov map[bx], '#'
    inc bx
    loop Clean_Map

    ; 生成迷宮、放寶物，並在背景算TSP最短路徑
    call Make_Maze
    call Put_Items
    call Calc_TSP

Game_Loop:
    ; 用INT 10h清空螢幕，畫面比較不會閃爍
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    ; 將游標移回左上角
    mov ah, 02h
    mov bh, 00h
    mov dx, 0000h
    int 10h

    ; 印出頂部狀態列
    lea dx, msg_title
    mov ah, 09h
    int 21h
    lea dx, msg_step
    mov ah, 09h
    int 21h
    mov ax, total_steps
    call Print_Num
    
    lea dx, msg_treas
    mov ah, 09h
    int 21h
    mov al, got_t
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    
    lea dx, enter_line
    mov ah, 09h
    int 21h

    ; 畫出迷宮陣列
    call Draw_It

Wait_Key:
    ; 使用INT 16h讀鍵盤，防止中文輸入法卡死，還能支援方向鍵
    mov ah, 00h
    int 16h
    
    ; 判斷 W, w, ↑
    cmp al, 'w'
    je Go_Up
    cmp al, 'W'
    je Go_Up
    cmp ah, 48h
    je Go_Up

    ; 判斷 S, s, ↓
    cmp al, 's'
    je Go_Down
    cmp al, 'S'
    je Go_Down
    cmp ah, 50h
    je Go_Down

    ; 判斷 A, a, ←
    cmp al, 'a'
    je Go_Left
    cmp al, 'A'
    je Go_Left
    cmp ah, 4Bh
    je Go_Left

    ; 判斷 D, d, →
    cmp al, 'd'
    je Go_Right
    cmp al, 'D'
    je Go_Right
    cmp ah, 4Dh
    je Go_Right
    
    jmp Wait_Key

Go_Up:
    mov cx, px
    mov dx, py
    dec dx
    jmp Check_Hit
Go_Down:
    mov cx, px
    mov dx, py
    inc dx
    jmp Check_Hit
Go_Left:
    mov cx, px
    mov dx, py
    dec cx
    jmp Check_Hit
Go_Right:
    mov cx, px
    mov dx, py
    inc cx
    jmp Check_Hit

Check_Hit:
    ; 檢查目標座標是否為牆壁'#'
    call Calc_Index
    cmp map[si], '#'
    je Game_Loop     ; 撞牆就無視輸入，直接重畫

    ; 更新位置與步數
    mov px, cx
    mov py, dx
    inc total_steps

    ; 判斷是否吃到寶物
    cmp map[si], 'T'
    jne Check_E
    inc got_t
    mov map[si], ' ' ; 吃掉後變空地

Check_E:
    ; 判斷是否抵達出口
    cmp map[si], 'E'
    jne Game_Loop
    cmp got_t, 3
    je You_Win       ; 必須吃滿3個寶物才能通關
    jmp Game_Loop

You_Win:
    ; 清空螢幕，印出最後一個乾淨的迷宮畫面
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    mov ah, 02h
    mov bh, 00h
    mov dx, 0000h
    int 10h

    ; 印出最終狀態列
    lea dx, msg_title
    mov ah, 09h
    int 21h
    lea dx, msg_step
    mov ah, 09h
    int 21h
    mov ax, total_steps
    call Print_Num
    lea dx, msg_treas
    mov ah, 09h
    int 21h
    mov al, got_t
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    lea dx, enter_line
    mov ah, 09h
    int 21h

    call Draw_It
    lea dx, msg_win
    mov ah, 09h
    int 21h

    ; 結算系統
    mov ax, total_steps
    cmp ax, shortest_steps
    je Rank_S          ; 步數和最優路徑步數一樣給S

    mov bx, shortest_steps
    add bx, 10
    cmp ax, bx       
    jle Rank_A         ; 10步以內的失誤給A
    jmp Rank_B         ; 超過10步就給B

Rank_S:
    lea dx, msg_rank_s
    mov ah, 09h
    int 21h
    jmp Ask_Replay

Rank_A:
    lea dx, msg_rank_a
    mov ah, 09h
    int 21h
    jmp Show_Shortest

Rank_B:
    lea dx, msg_rank_b
    mov ah, 09h
    int 21h

Show_Shortest:
    ; 非S級則印出最優路線步數
    lea dx, msg_missed
    mov ah, 09h
    int 21h
    mov ax, shortest_steps
    call Print_Num

Ask_Replay:
    lea dx, msg_replay
    mov ah, 09h
    int 21h
Wait_Ans:
    mov ah, 00h
    int 16h
    cmp al, 'y'
    je Restart_Game
    cmp al, 'Y'
    je Restart_Game
    cmp al, 'n'
    je Exit_Game
    cmp al, 'N'
    je Exit_Game
    jmp Wait_Ans

Exit_Game:
    mov ah, 4Ch
    int 21h
main endp

; TSP暴力窮舉計算
; 呼叫9次BFS算出所有節點距離，再排列組合出6種路徑找最小值
Calc_TSP proc
    ; 1. 算P(1,1)到3個寶物的距離
    mov bfs_sx, 1
    mov bfs_sy, 1
    mov bfs_tx, 19
    mov bfs_ty, 1
    call Run_BFS
    mov d_P_T1, ax

    mov bfs_tx, 1
    mov bfs_ty, 9
    call Run_BFS
    mov d_P_T2, ax

    mov bfs_tx, 19
    mov bfs_ty, 9
    call Run_BFS
    mov d_P_T3, ax

    ; 2. 算T1(19,1)到其他寶物跟出口的距離
    mov bfs_sx, 19
    mov bfs_sy, 1
    mov bfs_tx, 1
    mov bfs_ty, 9
    call Run_BFS
    mov d_T1_T2, ax

    mov bfs_tx, 19
    mov bfs_ty, 9
    call Run_BFS
    mov d_T1_T3, ax

    mov bfs_tx, 9
    mov bfs_ty, 5
    call Run_BFS
    mov d_T1_E, ax

    ; 3. 算T2(1,9)到T3還有出口的距離
    mov bfs_sx, 1
    mov bfs_sy, 9
    mov bfs_tx, 19
    mov bfs_ty, 9
    call Run_BFS
    mov d_T2_T3, ax

    mov bfs_tx, 9
    mov bfs_ty, 5
    call Run_BFS
    mov d_T2_E, ax

    ; 4. 算T3(19,9)到出口的距離
    mov bfs_sx, 19
    mov bfs_sy, 9
    mov bfs_tx, 9
    mov bfs_ty, 5
    call Run_BFS
    mov d_T3_E, ax

    ; 計算6種排列組合
    mov shortest_steps, 9999

    ; 路徑1: P -> T1 -> T2 -> T3 -> E
    mov ax, d_P_T1
    add ax, d_T1_T2
    add ax, d_T2_T3
    add ax, d_T3_E
    mov shortest_steps, ax

    ; 路徑2: P -> T1 -> T3 -> T2 -> E
    mov ax, d_P_T1
    add ax, d_T1_T3
    add ax, d_T2_T3
    add ax, d_T2_E
    cmp ax, shortest_steps
    jge Skip_P2
    mov shortest_steps, ax
Skip_P2:

    ; 路徑3: P -> T2 -> T1 -> T3 -> E
    mov ax, d_P_T2
    add ax, d_T1_T2
    add ax, d_T1_T3
    add ax, d_T3_E
    cmp ax, shortest_steps
    jge Skip_P3
    mov shortest_steps, ax
Skip_P3:

    ; 路徑4: P -> T2 -> T3 -> T1 -> E
    mov ax, d_P_T2
    add ax, d_T2_T3
    add ax, d_T1_T3
    add ax, d_T1_E
    cmp ax, shortest_steps
    jge Skip_P4
    mov shortest_steps, ax
Skip_P4:

    ; 路徑5: P -> T3 -> T1 -> T2 -> E
    mov ax, d_P_T3
    add ax, d_T1_T3
    add ax, d_T1_T2
    add ax, d_T2_E
    cmp ax, shortest_steps
    jge Skip_P5
    mov shortest_steps, ax
Skip_P5:

    ; 路徑6: P -> T3 -> T2 -> T1 -> E
    mov ax, d_P_T3
    add ax, d_T2_T3
    add ax, d_T1_T2
    add ax, d_T1_E
    cmp ax, shortest_steps
    jge Skip_P6
    mov shortest_steps, ax
Skip_P6:
    ret
Calc_TSP endp

; 放寶物
Put_Items proc
    mov cx, 19
    mov dx, 1
    call Calc_Index
    mov map[si], 'T'
    
    mov cx, 1
    mov dx, 9
    call Calc_Index
    mov map[si], 'T'
    
    mov cx, 19
    mov dx, 9
    call Calc_Index
    mov map[si], 'T'
    
    mov cx, 9
    mov dx, 5
    call Calc_Index
    mov map[si], 'E'
    ret
Put_Items endp

; DFS迷宮生成
; 使用m_stack陣列模擬遞迴堆疊，保證100%連通且地形蜿蜒
Make_Maze proc
    mov m_sp, 0
    mov cx, 1
    mov dx, 1
    call Calc_Index
    mov map[si], ' '
    
    mov bx, m_sp
    add bx, bx
    mov m_stack_x[bx], 1
    mov m_stack_y[bx], 1
    inc m_sp

DFS_Loop:
    cmp m_sp, 0
    je Make_Done    ; 堆疊空了代表迷宮挖完了

    ; Pop出當前座標
    mov bx, m_sp
    dec bx
    add bx, bx
    mov cx, m_stack_x[bx]
    mov cur_x, cx
    mov dx, m_stack_y[bx]
    mov cur_y, dx

    mov d_count, 0
    mov di, 0
Check_N:
    cmp di, 4
    jge Check_Done
    
    mov ax, di
    add ax, ax
    mov bx, ax
    mov cx, cur_x
    add cx, dx2[bx]
    mov dx, cur_y
    add dx, dy2[bx]

    ; 檢查邊界
    cmp cx, 0
    jle Next_N
    cmp cx, wid-1
    jge Next_N
    cmp dx, 0
    jle Next_N
    cmp dx, hei-1
    jge Next_N

    call Calc_Index
    cmp map[si], '#'
    jne Next_N

    ; 加入可行方向名單
    mov ax, di
    mov bx, 0
    mov bl, d_count
    mov dirs[bx], al
    inc d_count

Next_N:
    inc di
    jmp Check_N

Check_Done:
    cmp d_count, 0
    je Do_Pop       ; 死路就倒退

    ; 亂數選一個方向打通
    call Get_Random
    mov ah, 0
    div d_count
    mov bl, ah
    mov bh, 0
    mov al, dirs[bx]
    mov ah, 0
    mov bx, ax
    add bx, bx

    mov cx, cur_x
    add cx, dx1[bx]
    mov dx, cur_y
    add dx, dy1[bx]
    call Calc_Index
    mov map[si], ' '

    mov cx, cur_x
    add cx, dx2[bx]
    mov dx, cur_y
    add dx, dy2[bx]
    call Calc_Index
    mov map[si], ' '

    ; 將新打通的格子Push進陣列堆疊
    mov di, m_sp
    add di, di
    mov m_stack_x[di], cx
    mov m_stack_y[di], dx
    inc m_sp
    
    jmp DFS_Loop

Do_Pop:
    dec m_sp
    jmp DFS_Loop

Make_Done:
    ret
Make_Maze endp

; BFS廣度優先搜尋
; 利用q_head與q_tail模擬Queue找最短步數
Run_BFS proc
    mov q_head, 0
    mov q_tail, 0

    ; dist陣列初始化為255，代表還沒走過
    mov cx, 231
    mov bx, 0
Reset_Dist:
    mov dist[bx], 255
    inc bx
    loop Reset_Dist

    mov bx, q_tail
    add bx, bx
    mov ax, bfs_sx
    mov q_x[bx], ax
    mov ax, bfs_sy
    mov q_y[bx], ax
    inc q_tail

    mov cx, bfs_sx
    mov dx, bfs_sy
    call Calc_Index
    mov dist[si], 0

BFS_Loop:
    mov ax, q_head
    cmp ax, q_tail
    je BFS_Fail

    mov bx, q_head
    add bx, bx
    mov cx, q_x[bx]
    mov dx, q_y[bx]
    inc q_head

    cmp cx, bfs_tx
    jne BFS_Expand
    cmp dx, bfs_ty
    jne BFS_Expand

    ; 找到目標，直接回傳距離放在ax中
    call Calc_Index
    mov al, dist[si]
    mov ah, 0
    ret

BFS_Expand:
    call Calc_Index
    mov al, dist[si]
    inc al
    mov new_dist, al ; 暫存新步數，準備寫給四周的格子

    mov di, 0
Expand_Dir:
    cmp di, 4
    jge Expand_Done

    push cx
    push dx

    mov ax, di
    add ax, ax
    mov bx, ax
    add cx, bfs_dx[bx]
    add dx, bfs_dy[bx]

    call Calc_Index
    cmp map[si], '#'
    je Next_Dir
    cmp dist[si], 255
    jne Next_Dir

    ; 寫入距離並Enqueue
    mov al, new_dist
    mov dist[si], al

    mov ax, q_tail
    add ax, ax
    mov bx, ax
    mov q_x[bx], cx
    mov q_y[bx], dx
    inc q_tail

Next_Dir:
    pop dx
    pop cx
    inc di
    jmp Expand_Dir

Expand_Done:
    jmp BFS_Loop

BFS_Fail:
    mov ax, 999
    ret
Run_BFS endp

; 畫面繪製
Draw_It proc
    mov dx, 0       ; Y座標
Draw_R:
    cmp dx, hei
    jge Draw_End
    mov cx, 0       ; X座標
Draw_C:
    cmp cx, wid
    jge Draw_N_Line

    cmp dx, py
    jne Check_W
    cmp cx, px
    jne Check_W
    mov al, 'P'     ; 如果是玩家座標，印'P'
    jmp Do_P

Check_W:
    call Calc_Index
    mov al, map[si]

Do_P:
    mov ah, 02h
    push dx
    mov dl, al
    int 21h
    pop dx
    inc cx
    jmp Draw_C

Draw_N_Line:
    push dx
    lea dx, enter_line
    mov ah, 09h
    int 21h
    pop dx
    inc dx
    jmp Draw_R
Draw_End:
    ret
Draw_It endp

; 輔助功能：計算一維陣列Index (Index = Y * Width + X)
Calc_Index proc
    push ax
    push bx
    push dx
    mov ax, dx
    mov bx, wid
    mul bx
    add ax, cx
    mov si, ax
    pop dx
    pop bx
    pop ax
    ret
Calc_Index endp

; 輔助功能：線性同餘亂數產生器
Get_Random proc
    mov ax, seed
    mov bx, 25173
    mul bx
    add ax, 13849
    mov seed, ax
    ret
Get_Random endp

; 輔助功能：將 AX 暫存器的數字轉為 10 進位印出
Print_Num proc
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
Div_L:
    mov dx, 0
    div bx
    push dx          ; 把餘數推入Stack
    inc cx
    cmp ax, 0
    jne Div_L
Pr_L:
    pop dx           ; 反向取出並印出
    add dl, '0'
    mov ah, 02h
    int 21h
    loop Pr_L
    pop dx
    pop cx
    pop bx
    pop ax
    ret
Print_Num endp

end main