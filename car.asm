[org 0x0100]
jmp start

buffer times 80 dw 0      
row_chars  equ 80
row_words  equ 80
tree_positions dw 2, 6, 10, 14, 18, 22  ; Tree rows that wrap around
current_tree_index dw 0
car_position dw 37         ; Current car column position (37-39)
old_car_position dw 37     ; Store previous position for proper clearing
game_active db 1           ; 1=game running, 0=game over
score dw 0               
random_seed dw 12345       
obstacle_cars dw 0,0,0,0,0 ; Column positions of obstacle cars (0 = no car)
bonus_seed dw 54321        ; Seed for bonus generation
bonus_objects dw 0,0,0,0,0 ; Column positions of bonus objects (0 = no bonus)
bonus_counter dw 0         ; Counter to control bonus appearance frequency

; New variables for ESC confirmation
esc_pressed db 0          ; Flag to indicate ESC was pressed
game_paused db 0           ; Flag to indicate game is paused
old_int9 dd 0             ; Store original INT 9 vector

; Timer ISR variables - SIRF TREES KE LIYE
old_int8 dd 0             ; Store original INT 8 vector
tree_scroll_counter dw 0  ; Counter for tree scroll timing
tree_scroll_speed equ 1   ; Tree scroll every 3 timer ticks

welcome_msg1 db 'CAR RACING GAME', 0
welcome_msg2 db 'Made By:', 0
welcome_msg3 db 'Ajwa (24L-0950)', 0
welcome_msg4 db 'Zainab (24L-0916)', 0
welcome_msg5 db 'Fall 2025', 0
welcome_msg6 db 'Press ANY KEY to Start', 0
welcome_msg7 db 'Use LEFT/RIGHT ARROWS to Move', 0
welcome_msg8 db 'Press ESC to Exit', 0
gameover_msg1 db 'GAME OVER', 0
gameover_msg2 db 'Press R to Restart', 0
gameover_msg3 db 'Press ESC to Exit', 0
score_msg db 'SCORE: 0000', 0
exit_confirm_msg db 'Are you sure you want to exit the game?', 0
yes_no_msg db 'Press Y for Yes, N for No', 0
exit_prompt_msg db 'Press any key to exit', 0

; -------------------------------
; Timer ISR Handler (INT 8) - SIRF TREES KI SCROLLING KE LIYE
; -------------------------------
new_int8:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
    
    push cs
    pop ds
    
    ; Check if game is active and not paused
    cmp byte [game_active], 0
    je call_old_int8
    cmp byte [game_paused], 1
    je call_old_int8
    
    ; Increment tree scroll counter
    inc word [tree_scroll_counter]
    
    ; Check if it's time to scroll trees
    mov ax, [tree_scroll_counter]
    cmp ax, [tree_scroll_speed]
    jl call_old_int8
    
    ; Reset tree scroll counter
    mov word [tree_scroll_counter], 0
    
    ; SIRF TREES KI POSITIONS UPDATE KARO - SCREEN SCROLL NAHI
    call UpdateTreePositions
    
call_old_int8:
    ; Call original INT 8 handler
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [cs:old_int8]

; -------------------------------
; Install Timer ISR Handler (INT 8)
; -------------------------------
InstallInt8Handler:
    push ax
    push es
    push ds
    
    ; Get original INT 8 vector
    mov ax, 0
    mov es, ax
    mov ax, [es:8*4]
    mov [old_int8], ax
    mov ax, [es:8*4+2]
    mov [old_int8+2], ax
    
    ; Set new INT 8 vector
    mov ax, 0
    mov es, ax
    mov word [es:8*4], new_int8
    mov word [es:8*4+2], cs
    
    pop ds
    pop es
    pop ax
    ret

; -------------------------------
; Restore Timer ISR Handler (INT 8)
; -------------------------------
RestoreInt8Handler:
    push ax
    push es
    
    ; Restore original INT 8 vector
    mov ax, 0
    mov es, ax
    mov ax, [old_int8]
    mov [es:8*4], ax
    mov ax, [old_int8+2]
    mov [es:8*4+2], ax
    
    pop es
    pop ax
    ret

; -------------------------------
; Custom INT 9 Handler
; -------------------------------
new_int9:
    push ax
    push es
    
    ; Read from keyboard port
    in al, 0x60
    
    ; Check if ESC key (scan code 0x01) is pressed
    cmp al, 0x01
    jne skip_esc
    
    ; Set ESC pressed flag
    mov byte [cs:esc_pressed], 1
    
skip_esc:
    ; Call original INT 9 handler
    pushf
    call far [cs:old_int9]
    
    pop es
    pop ax
    iret

; -------------------------------
; Install INT 9 Handler
; -------------------------------
InstallInt9Handler:
    push ax
    push es
    push ds
    
    ; Get original INT 9 vector
    mov ax, 0
    mov es, ax
    mov ax, [es:9*4]
    mov [old_int9], ax
    mov ax, [es:9*4+2]
    mov [old_int9+2], ax
    
    ; Set new INT 9 vector
    mov ax, 0
    mov es, ax
    mov word [es:9*4], new_int9
    mov word [es:9*4+2], cs
    
    pop ds
    pop es
    pop ax
    ret

; -------------------------------
; Restore INT 9 Handler
; -------------------------------
RestoreInt9Handler:
    push ax
    push es
    
    ; Restore original INT 9 vector
    mov ax, 0
    mov es, ax
    mov ax, [old_int9]
    mov [es:9*4], ax
    mov ax, [old_int9+2]
    mov [es:9*4+2], ax
    
    pop es
    pop ax
    ret

; -------------------------------
; Exit Confirmation Screen
; -------------------------------
ExitConfirmationScreen:
    pusha
    
    ; Set game as paused
    mov byte [game_paused], 1
    
    ; Draw confirmation dialog
    call DrawExitConfirmation
    
    ; Wait for Y or N key
wait_for_yn:
    ; Check for key press using INT 16h
    mov ah, 0x01
    int 0x16
    jz wait_for_yn
    
    ; Get the key
    mov ah, 0x00
    int 0x16
    
    ; Check if Y is pressed
    cmp al, 'Y'
    je exit_confirmed
    cmp al, 'y'
    je exit_confirmed
    
    ; Check if N is pressed
    cmp al, 'N'
    je resume_game
    cmp al, 'n'
    je resume_game
    
    ; If neither Y nor N, continue waiting
    jmp wait_for_yn
    
exit_confirmed:
    ; Show final score
    call ShowFinalScore
    
    ; Restore original interrupt handlers
    call RestoreInt8Handler
    call RestoreInt9Handler
    
    ; Exit program
    mov ax, 0x4C00
    int 0x21
    
resume_game:
    ; Reset ESC pressed flag
    mov byte [esc_pressed], 0
    
    ; Set game as not paused
    mov byte [game_paused], 0
    
    ; Redraw the game screen
    call ClearScreen
    call DrawLanes
    call DrawGrass
    call DrawTrees
    call DrawFlowers
    call DrawCar
    call UpdateScoreDisplay
    
    popa
    ret

; -------------------------------
; Draw Exit Confirmation Dialog
; -------------------------------
DrawExitConfirmation:
    pusha
    
    ; Draw dialog box background
    mov ax, 0xb800
    mov es, ax
    
    ; Calculate center position
    mov di, (10 * 80 + 20) * 2  ; Row 10, column 20
    mov bx, 10  ; 10 rows
    
draw_dialog_row:
    push bx
    push di
    mov cx, 40  ; 40 columns
    
draw_dialog_col:
    mov word [es:di], 0x7020  ; White on black background
    add di, 2
    loop draw_dialog_col
    
    pop di
    add di, 160  ; Next row
    pop bx
    dec bx
    jnz draw_dialog_row
    
    ; Draw confirmation message
    mov si, exit_confirm_msg
    mov di, (12 * 80 + 22) * 2  ; Row 12, column 22
    mov ah, 0x0F  ; White on black
    
draw_confirm_msg:
    lodsb
    cmp al, 0
    je draw_yes_no_msg
    mov [es:di], ax
    add di, 2
    jmp draw_confirm_msg
    
draw_yes_no_msg:
    ; Draw Y/N message
    mov si, yes_no_msg
    mov di, (14 * 80 + 25) * 2  ; Row 14, column 25
    mov ah, 0x0F  ; White on black
    
draw_yn_msg:
    lodsb
    cmp al, 0
    je dialog_done
    mov [es:di], ax
    add di, 2
    jmp draw_yn_msg
    
dialog_done:
    popa
    ret

; -------------------------------
; Show Final Score
; -------------------------------
; -------------------------------
; Show Final Score
; -------------------------------
ShowFinalScore:
    pusha
    
    ; Clear screen
    call ClearScreen
    
    ; Draw "GAME OVER" message
    mov ax, 0xb800
    mov es, ax
    
    mov si, gameover_msg1
    mov di, (8 * 80 + 33) * 2  ; Row 8, column 33
    mov ah, 0x0E  ; Yellow on black
    
draw_game_over_msg:
    lodsb
    cmp al, 0
    je draw_final_score
    mov [es:di], ax
    add di, 2
    jmp draw_game_over_msg
    
draw_final_score:
    ; Draw score
    mov si, score_msg
    mov di, (11 * 80 + 33) * 2  ; Row 11, column 33
    mov ah, 0x0F  ; White on black
    
draw_final_score_msg:
    lodsb
    cmp al, 0
    je draw_exit_prompt
    mov [es:di], ax
    add di, 2
    jmp draw_final_score_msg

draw_exit_prompt:
    ; Draw "Press any key to exit" message
    mov si, exit_prompt_msg
    mov di, (14 * 80 + 28) * 2  ; Row 14, column 28
    mov ah, 0x0A  ; Green on black
    
draw_exit_prompt_loop:
    lodsb
    cmp al, 0
    je final_score_done
    mov [es:di], ax
    add di, 2
    jmp draw_exit_prompt_loop
    
final_score_done:
    ; Wait for any key before exiting
    mov ah, 0x00
    int 0x16
    
    popa
    ret

; -------------------------------
; Clear Screen
; -------------------------------
ClearScreen:
    mov ax,0xb800
    mov es,ax
    xor di,di
    mov cx,2000
    mov ax,0720h   
    rep stosw
    ret

; -------------------------------
; Update Score Display - FIXED VERSION
; -------------------------------
UpdateScoreDisplay:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Set ES to video memory
    mov ax, 0xb800
    mov es, ax
    
    ; Convert score to string
    mov ax, [score]
    mov bx, 10
    mov si, score_msg + 10  ; Point to last digit position
    
    ; Convert 4 digits
    mov cx, 4
convert_loop:
    xor dx, dx
    div bx                  ; DX:AX / 10, AX = quotient, DX = remainder
    add dl, '0'            ; Convert to ASCII
    mov [si], dl
    dec si
    loop convert_loop
    
    ; Draw score at top right of screen
    mov si, score_msg
    mov di, (1 * 80 + 65) * 2  ; Row 1, column 65
    mov ah, 0x0F           ; White on black
    mov cx, 11             ; "SCORE: 0000" is 11 characters
    
draw_score_display:
    lodsb
    mov [es:di], ax
    add di, 2
    loop draw_score_display
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------
; Random Number Generator
; -------------------------------
GenerateRandom:
    push ax
    push dx
    
    mov ax, [random_seed]
    mov dx, 8121
    mul dx
    add ax, 28411
    mov [random_seed], ax
    
    pop dx
    pop ax
    ret

; -------------------------------
; Bonus Random Number Generator
; -------------------------------
GenerateBonusRandom:
    push ax
    push dx
    
    mov ax, [bonus_seed]
    mov dx, 7569  ; Different multiplier for more randomness
    mul dx
    add ax, 39367 ; Different addend for more randomness
    mov [bonus_seed], ax
    
    pop dx
    pop ax
    ret

; -------------------------------
; Generate Random Obstacle Cars
; -------------------------------
GenerateObstacleCars:
    push ax
    push bx
    push cx
    push si
    
    ; Generate random number
    call GenerateRandom
    mov ax, [random_seed]
    and ax, 7  ; Get value between 0-7
    
    ; Only create new car with 15% probability (when random = 0 or 1)
    cmp ax, 1
    jg no_new_car
    
    ; Find empty slot for new car
    mov si, obstacle_cars
    mov cx, 5
find_empty_slot:
    cmp word [si], 0
    je found_empty_slot
    add si, 2
    loop find_empty_slot
    jmp no_new_car
    
found_empty_slot:
    ; Generate random position between 15 and 64
    call GenerateRandom
    mov ax, [random_seed]
    and ax, 0x3F  ; 0-63
    cmp ax, 49
    jle car_position_ok
    sub ax, 14    ; If >49, reduce to 0-49 range
    
car_position_ok:
    ; Add 15 to get position in 15-64 range
    add ax, 15
    
    ; Store car in empty slot
    mov [si], ax
    
no_new_car:
    pop si
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------
; Generate Random Bonus Objects
; -------------------------------
GenerateBonusObjects:
    push ax
    push bx
    push cx
    push si
    
    ; Increment bonus counter
    inc word [bonus_counter]
    
    ; Only generate bonus after certain number of scrolls (e.g., every 10 scrolls)
    mov ax, [bonus_counter]
    cmp ax, 10
    jl no_new_bonus
    mov word [bonus_counter], 0  ; Reset counter
    
    ; Generate random number for probability (0-9)
    call GenerateBonusRandom
    mov ax, [bonus_seed]
    and ax, 9  ; Get value between 0-9
    
    ; Only create new bonus with 30% probability (when random = 0, 1, or 2)
    cmp ax, 2
    jg no_new_bonus
    
    ; Find empty slot for new bonus
    mov si, bonus_objects
    mov cx, 5
find_empty_bonus_slot:
    cmp word [si], 0
    je found_empty_bonus_slot
    add si, 2
    loop find_empty_bonus_slot
    jmp no_new_bonus
    
found_empty_bonus_slot:
    ; Generate random position between 15 and 64
    call GenerateBonusRandom
    mov ax, [bonus_seed]
    and ax, 0x3F  ; 0-63
    cmp ax, 49
    jle position_ok
    sub ax, 14    ; If >49, reduce to 0-49 range
    
position_ok:
    ; Add 15 to get position in 15-64 range
    add ax, 15
    
    ; Store bonus in empty slot
    mov [si], ax
    
no_new_bonus:
    pop si
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------
; Update Bonus Objects Position
; -------------------------------
UpdateBonusObjects:
    push si
    push cx
    push ax
    
    mov si, bonus_objects
    mov cx, 5
    
update_bonus_loop:
    mov ax, [si]
    cmp ax, 0
    je next_bonus
    
    ; Clear old bonus position
    call ClearBonusObject
    
    ; Update position (move down)
    add ax, 160  ; Move to next row
    
    ; If bonus goes beyond screen, remove it
    cmp ax, 3840  ; 25 rows * 80 columns
    jl keep_bonus
    mov word [si], 0  ; Remove bonus
    jmp next_bonus
    
keep_bonus:
    mov [si], ax
    
next_bonus:
    add si, 2
    loop update_bonus_loop
    
    pop ax
    pop cx
    pop si
    ret

; -------------------------------
; Clear Bonus Object
; -------------------------------
ClearBonusObject:
    push ax
    push di
    push cx
    push es
    
    mov ax, 0xb800
    mov es, ax
    
    mov ax, [si]  ; Get bonus position
    mov di, ax
    shl di, 1     ; Convert to video memory offset
    
    ; Clear 1x1 bonus area
    mov word [es:di], 0x0720  ; Space with black background
    
    pop es
    pop cx
    pop di
    pop ax
    ret

; -------------------------------
; Draw Bonus Objects
; -------------------------------
DrawBonusObjects:
    push si
    push cx
    push ax
    push di
    push es
    
    mov ax, 0xb800
    mov es, ax
    
    mov si, bonus_objects
    mov cx, 5
    
draw_bonus_loop:
    mov ax, [si]
    cmp ax, 0
    je skip_bonus
    
    ; Calculate video memory position
    mov di, ax
    shl di, 1
    
    ; Draw bonus object (yellow star)
    mov word [es:di], 0x2E2A ; Yellow star on green background
    
skip_bonus:
    add si, 2
    loop draw_bonus_loop
    
    pop es
    pop di
    pop ax
    pop cx
    pop si
    ret

; -------------------------------
; Check Collision with Bonus Objects - FIXED VERSION (5 POINTS PER BONUS)
; -------------------------------
CheckBonusCollision:
    push si
    push cx
    push ax
    push bx
    push dx
    push di
    
    mov bx, [car_position]
    
    ; Check collision with each bonus object
    mov si, bonus_objects
    mov cx, 5
    
check_bonus_collision_loop:
    mov ax, [si]
    cmp ax, 0
    je next_bonus_check
    
    ; Calculate row and column from position
    mov dx, ax
    mov ax, dx
    mov dl, 80
    div dl              ; AL = row, AH = column
    mov dh, ah          ; DH = bonus column
    mov dl, al          ; DL = bonus row
    
    ; Check if bonus is in rows 22-24 (where player car is)
    cmp dl, 22
    jb next_bonus_check
    cmp dl, 24
    ja next_bonus_check
    
    ; Check column collision (player car spans 5 columns)
    mov al, dh          ; AL = bonus column
    mov ah, 0
    sub ax, bx          ; Difference between bonus and player
    
    ; If bonus is within 2 columns of player
    cmp ax, -2
    jl next_bonus_check
    cmp ax, 2
    jg next_bonus_check
    
    ; Collision detected!
    ; Increase score by 5
    add word [score], 5
    call UpdateScoreDisplay  ; Update score immediately
    
    ; Clear the bonus object from screen immediately
    push ax
    mov ax, [si]
    mov di, ax
    shl di, 1     ; Convert to video memory offset
    mov ax, 0xb800
    mov es, ax
    mov word [es:di], 0x0720  ; Clear with space
    pop ax
    
    ; Remove the bonus from array
    mov word [si], 0
    
next_bonus_check:
    add si, 2
    loop check_bonus_collision_loop
    
    pop di
    pop dx
    pop bx
    pop ax
    pop cx
    pop si
    ret

; -------------------------------
; Update Obstacle Cars Position
; -------------------------------
UpdateObstacleCars:
    push si
    push cx
    push ax
    
    mov si, obstacle_cars
    mov cx, 5
    
update_obstacle_loop:
    mov ax, [si]
    cmp ax, 0
    je next_obstacle
    
    ; Clear old car position
    call ClearObstacleCar
    
    ; Update position (move down)
    add ax, 160  ; Move to next row
    
    ; If car goes beyond screen, remove it
    cmp ax, 3840  ; 25 rows * 80 columns
    jl keep_obstacle
    mov word [si], 0  ; Remove car
    jmp next_obstacle
    
keep_obstacle:
    mov [si], ax
    
next_obstacle:
    add si, 2
    loop update_obstacle_loop
    
    pop ax
    pop cx
    pop si
    ret

; -------------------------------
; Clear Obstacle Car
; -------------------------------
ClearObstacleCar:
    push ax
    push di
    push cx
    push es
    
    mov ax, 0xb800
    mov es, ax
    
    mov ax, [si]  ; Get car position
    mov di, ax
    shl di, 1     ; Convert to video memory offset
    
    ; Clear 3x3 car area (increased from 3x2)
    mov cx, 3
clear_obstacle_row:
    push cx
    push di
    
    mov cx, 3       ; Increased from 2 to 3 columns
clear_obstacle_col:
    mov word [es:di], 0x0720  ; Space with black background
    add di, 2
    loop clear_obstacle_col
    
    pop di
    add di, 160  ; Next row
    pop cx
    loop clear_obstacle_row
    
    pop es
    pop cx
    pop di
    pop ax
    ret

; -------------------------------
; Draw Obstacle Cars
; -------------------------------
DrawObstacleCars:
    push si
    push cx
    push ax
    push di
    push es
    
    mov ax, 0xb800
    mov es, ax
    
    mov si, obstacle_cars
    mov cx, 5
    
draw_obstacle_loop:
    mov ax, [si]
    cmp ax, 0
    je skip_obstacle
    
    ; Calculate video memory position
    mov di, ax
    shl di, 1
    
    ; Draw improved obstacle car (3x3 size)
    ; Top row - car roof
    mov word [es:di], 0x4C5F      ; Top left (red background, white roof)
    mov word [es:di+2], 0x4C5F    ; Top middle
    mov word [es:di+4], 0x4C5F    ; Top right
    
    ; Middle row - car body
    mov word [es:di+160], 0x4EDB  ; Middle left (red background, white car body)
    mov word [es:di+162], 0x4EDB  ; Middle middle
    mov word [es:di+164], 0x4EDB  ; Middle right
    
    ; Bottom row - car wheels
    mov word [es:di+320], 0x4E2F  ; Bottom left (red background, white wheel)
    mov word [es:di+322], 0x4E20  ; Bottom middle (red background, black space)
    mov word [es:di+324], 0x4E2F  ; Bottom right (red background, white wheel)
    
skip_obstacle:
    add si, 2
    loop draw_obstacle_loop
    
    pop es
    pop di
    pop ax
    pop cx
    pop si
    ret

; -------------------------------
; Check Collision with Obstacle Cars - FIXED VERSION
; -------------------------------
CheckObstacleCollision:
    push si
    push cx
    push ax
    push bx
    push dx
    
    mov bx, [car_position]
    
    ; Check collision with each obstacle car
    mov si, obstacle_cars
    mov cx, 5
    
check_collision_loop:
    mov ax, [si]
    cmp ax, 0
    je next_collision_check
    
    ; Calculate row and column from position
    mov dx, ax
    mov ax, dx
    mov dl, 80
    div dl              ; AL = row, AH = column
    mov dh, ah          ; DH = obstacle column
    mov dl, al          ; DL = obstacle row
    
    ; Check if obstacle is in rows 22-24 (where player car is)
    cmp dl, 22
    jb next_collision_check
    cmp dl, 24
    ja next_collision_check
    
    ; Check column collision (player car spans 5 columns)
    mov al, dh          ; AL = obstacle column
    mov ah, 0
    sub ax, bx          ; Difference between obstacle and player
    
    ; If obstacle is within 3 columns of player
    cmp ax, -3
    jl next_collision_check
    cmp ax, 3
    jg next_collision_check
    
    ; Collision detected!
    mov byte [game_active], 0
    jmp collision_done
    
next_collision_check:
    add si, 2
    loop check_collision_loop
    
collision_done:
    pop dx
    pop bx
    pop ax
    pop cx
    pop si
    ret

; -------------------------------
; Welcome Screen
; -------------------------------
DrawWelcomeScreen:
    call ClearScreen
    
    ; Set colorful background
    mov di, 0
    mov cx, 2000
    mov ax, 0x3F20  
welcome_draw_bg:
    mov [es:di], ax
    add di, 2
    loop welcome_draw_bg
    
    ; Draw game title - CAR RACING GAME
    mov si, welcome_msg1
    mov di, (5 * 80 + 30) * 2  ; Row 5, column 30
    mov ah, 0x35          
welcome_draw_title:
    lodsb
    cmp al, 0
    je welcome_draw_developed
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_title
    
welcome_draw_developed:
    ; Developed By:
    mov si, welcome_msg2
    mov di, (8 * 80 + 33) * 2  ; Row 8, column 33
    mov ah, 0x3E          
welcome_draw_dev:
    lodsb
    cmp al, 0
    je welcome_draw_name1
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_dev
    
welcome_draw_name1:
    ; Ajwa (24L-0950)
    mov si, welcome_msg3
    mov di, (10 * 80 + 32) * 2  ; Row 10, column 32
    mov ah, 0x36          
welcome_draw_name1_loop:
    lodsb
    cmp al, 0
    je welcome_draw_name2
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_name1_loop
    
welcome_draw_name2:
    ; Zainab (24L-0916)
    mov si, welcome_msg4
    mov di, (12 * 80 + 32) * 2  ; Row 12, column 32
    mov ah, 0x3A          
welcome_draw_name2_loop:
    lodsb
    cmp al, 0
    je welcome_draw_semester
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_name2_loop
    
welcome_draw_semester:
    ; Fall 2025
    mov si, welcome_msg5
    mov di, (14 * 80 + 35) * 2  ; Row 14, column 35
    mov ah, 0x3E          
welcome_draw_semester_loop:
    lodsb
    cmp al, 0
    je welcome_draw_start_msg
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_semester_loop
    
welcome_draw_start_msg:
    ; Press ANY KEY to Start
    mov si, welcome_msg6
    mov di, (17 * 80 + 28) * 2  ; Row 17, column 28
    mov ah, 0x3E          
welcome_draw_msg6:
    lodsb
    cmp al, 0
    je welcome_draw_controls
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_msg6
    
welcome_draw_controls:
    ; Use LEFT/RIGHT ARROWS to Move
    mov si, welcome_msg7
    mov di, (19 * 80 + 25) * 2  ; Row 19, column 25
    mov ah, 0x34        
welcome_draw_controls_loop:
    lodsb
    cmp al, 0
    je welcome_draw_exit_msg
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_controls_loop
    
welcome_draw_exit_msg:
    ; Press ESC to Exit
    mov si, welcome_msg8
    mov di, (21 * 80 + 30) * 2  ; Row 21, column 30
    mov ah, 0x36        
welcome_draw_exit_loop:
    lodsb
    cmp al, 0
    je welcome_draw_border
    mov [es:di], ax
    add di, 2
    jmp welcome_draw_exit_loop
    
welcome_draw_border:
    ; Draw decorative border
    mov di, (3 * 80 + 20) * 2   ; Top border
    mov cx, 40
    mov ax, 0x3ECD         
welcome_draw_top_border:
    mov [es:di], ax
    add di, 2
    loop welcome_draw_top_border
    
    mov di, (23 * 80 + 20) * 2  ; Bottom border
    mov cx, 40
welcome_draw_bottom_border:
    mov [es:di], ax
    add di, 2
    loop welcome_draw_bottom_border
    
    ; Left and right borders
    mov bx, 4
welcome_draw_side_borders:
    ; Left border
    mov ax, bx
    mov dx, 80
    mul dx
    add ax, 20
    shl ax, 1
    mov di, ax
    mov word [es:di], 0x3EBA
    
    ; Right border
    mov ax, bx
    mov dx, 80
    mul dx
    add ax, 59
    shl ax, 1
    mov di, ax
    mov word [es:di], 0x3EBA
    
    inc bx
    cmp bx, 23
    jl welcome_draw_side_borders
    
    ; Wait for any key press
    mov ah, 0x00
    int 0x16
    ret

; -------------------------------
; Game Over Screen
; -------------------------------
DrawGameOverScreen:
    call ClearScreen
    
    ; Set red background
    mov di, 0
    mov cx, 2000
    mov ax, 0x5F20  ; Red background, white text
draw_gameover_bg:
    mov [es:di], ax
    add di, 2
    loop draw_gameover_bg
    
    ; Update score display for game over screen
    call UpdateScoreDisplay
    
    ; Draw GAME OVER
    mov si, gameover_msg1
    mov di, (8*80 + 33)*2  ; Row 8, column 33
    mov ah, 0x5E           ; Yellow on red
draw_gameover:
    lodsb
    cmp al, 0
    je draw_score
    mov [es:di], ax
    add di, 2
    jmp draw_gameover
    
draw_score:
    ; Draw score
    mov si, score_msg
    mov di, (11*80 + 33)*2  ; Row 11, column 33
    mov ah, 0x5F           ; White on red
draw_score_loop:
    lodsb
    cmp al, 0
    je draw_restart
    mov [es:di], ax
    add di, 2
    jmp draw_score_loop
    
draw_restart:
    ; Press R to Restart
    mov si, gameover_msg2
    mov di, (14*80 + 30)*2  ; Row 14, column 30
    mov ah, 0x5A           ; Green on red
draw_restart_loop:
    lodsb
    cmp al, 0
    je draw_exit_option
    mov [es:di], ax
    add di, 2
    jmp draw_restart_loop
    
draw_exit_option:
    ; Press ESC to Exit
    mov si, gameover_msg3
    mov di, (16*80 + 32)*2  ; Row 16, column 32
    mov ah, 0x5C           ; Red on red (different shade)
draw_exit_loop:
    lodsb
    cmp al, 0
    je gameover_input
    mov [es:di], ax
    add di, 2
    jmp draw_exit_loop
    
gameover_input:
    ; Wait for R or ESC key
gameover_wait:
    mov ah, 00h
    int 16h
    
    cmp al, 'r'        ; Restart game
    je restart_game
    cmp al, 'R'        ; Restart game (uppercase)
    je restart_game
    cmp ah, 01h        ; ESC key
    je near exit_program
    jmp gameover_wait
    
restart_game:
    ; Reset game state
    mov word [car_position], 37
    mov word [old_car_position], 37
    mov byte [game_active], 1
    mov word [score], 0
    
    ; Reset tree positions
    mov word [tree_positions], 2
    mov word [tree_positions+2], 6
    mov word [tree_positions+4], 10
    mov word [tree_positions+6], 14
    mov word [tree_positions+8], 18
    mov word [tree_positions+10], 22
    
    ; Clear obstacle cars
    mov word [obstacle_cars], 0
    mov word [obstacle_cars+2], 0
    mov word [obstacle_cars+4], 0
    mov word [obstacle_cars+6], 0
    mov word [obstacle_cars+8], 0
    
    ; Clear bonus objects
    mov word [bonus_objects], 0
    mov word [bonus_objects+2], 0
    mov word [bonus_objects+4], 0
    mov word [bonus_objects+6], 0
    mov word [bonus_objects+8], 0
    
    ; Reset bonus counter
    mov word [bonus_counter], 0
    
    ; Reset random seeds for better randomness on restart
    mov ax, [random_seed]
    add ax, 12345
    mov [random_seed], ax
    
    mov ax, [bonus_seed]
    add ax, 54321
    mov [bonus_seed], ax
    
    ret

; -------------------------------
; Check Collision
; -------------------------------
CheckCollision:
    push ax
    push bx
    push cx
    push di
    push si
    
    mov bx, [car_position]
    
    ; Check collision with road boundaries
    cmp bx, 20
    jl collision_detected
    cmp bx, 55
    jg collision_detected
    
    ; Check collision with obstacle cars
    call CheckObstacleCollision
    cmp byte [game_active], 0
    je collision_detected
    
    ; Check collision with bonus objects
    call CheckBonusCollision
    
    jmp no_collision
    
collision_detected:
    mov byte [game_active], 0
    
no_collision:
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------
; Draw Road Lanes
; -------------------------------
DrawLanes:
    mov bx,0
startlane:
    mov ax,bx
    mov dx,80
    mul dx
    add ax,15
    shl ax,1
    mov di,ax
    mov word [es:di],0EBAh
    inc bx
    cmp bx,25
    jne startlane

    mov bx,0
lane1:
    mov ax,bx
    mov dx,80
    mul dx
    add ax,31
    shl ax,1
    mov di,ax
    mov word [es:di],0D7Ch
    inc bx
    cmp bx,25
    jne lane1

    mov bx,0
lane2:
    mov ax,bx
    mov dx,80
    mul dx
    add ax,47
    shl ax,1
    mov di,ax
    mov word [es:di],0D7Ch
    inc bx
    cmp bx,25
    jne lane2

    mov bx,0
endlane:
    mov ax,bx
    mov dx,80
    mul dx
    add ax,64
    shl ax,1
    mov di,ax
    mov word [es:di],0EBAh
    inc bx
    cmp bx,25
    jne endlane
    ret

; -------------------------------
; Draw Grass
; -------------------------------
DrawGrass:
    mov bx,0
grass_left:
    mov ax,bx
    mov dx,80
    mul dx
    mov cx,0
left_fill:
    cmp cx,15
    je done_left
    mov di,ax
    add di,cx
    shl di,1
    mov word [es:di],0A020h
    inc cx
    jmp left_fill
done_left:
    inc bx
    cmp bx,25
    jne grass_left

    mov bx,0
grass_right:
    mov ax,bx
    mov dx,80
    mul dx
    mov cx,65
right_fill:
    cmp cx,80
    je done_right
    mov di,ax
    add di,cx
    shl di,1
    mov word [es:di],0A020h
    inc cx
    jmp right_fill
done_right:
    inc bx
    cmp bx,25
    jne grass_right
    ret

; -------------------------------
; Draw Trees with Wrap-Around
; -------------------------------
DrawTrees:
    push bx
    push si
    push di
    
    ; Draw trees at fixed positions that wrap around
    mov si, tree_positions
    mov cx, 6  ; 6 trees total
    
draw_tree_loop:
    mov bx, [si]  ; Get tree row position
    
    ; Left side tree
    mov ax,bx
    mov dx,80
    mul dx
    add ax,6
    shl ax,1
    mov di,ax
    mov word [es:di],0x2A1E
    add di,160
    sub di,2
    mov word [es:di],0x2A1E
    add di,2
    mov word [es:di],0x2A1E
    add di,2
    mov word [es:di],0x2A1E
    add di,158
    mov word [es:di],0x6E20
    
    ; Right side tree
    mov ax,bx
    mov dx,80
    mul dx
    add ax,70
    shl ax,1
    mov di,ax
    mov word [es:di],0x2A1E
    add di,160
    sub di,2
    mov word [es:di],0x2A1E
    add di,2
    mov word [es:di],0x2A1E
    add di,2
    mov word [es:di],0x2A1E
    add di,158
    mov word [es:di],0x6E20
    
    add si, 2  ; Next tree position
    loop draw_tree_loop
    
    pop di
    pop si
    pop bx
    ret

; -------------------------------
; Update Tree Positions (Wrap-Around) 
; -------------------------------
UpdateTreePositions:
    push bx
    push si
    push cx
    
    mov si, tree_positions
    mov cx, 6  ; 6 trees
    
update_tree_loop:
    mov bx, [si]  ; Get current tree row
    
    ; Move tree down by 1 row
    inc bx
    
    ; If tree goes beyond bottom, wrap to top
    cmp bx, 25
    jl no_wrap_needed
    mov bx, 0      ; Wrap to top row
    
no_wrap_needed:
    mov [si], bx   ; Update tree position
    add si, 2      ; Next tree
    loop update_tree_loop
    
    pop cx
    pop si
    pop bx
    ret

; -------------------------------
; Draw Flowers with Wrap-Around
; -------------------------------
DrawFlowers:
    mov bx,4
draw_flowers:
    mov ax,bx
    mov dx,80
    mul dx
    add ax,10
    shl ax,1
    mov di,ax
    mov word [es:di],0x5C2A

    mov ax,bx
    mov dx,80
    mul dx
    add ax,75
    shl ax,1
    mov di,ax
    mov word [es:di],0x4E2A

    add bx,3
    cmp bx,23
    jl draw_flowers
    ret

; -------------------------------
; Clear Car Area
; -------------------------------
ClearCarArea:
    push es
    push di
    push cx
    push bx
    push ax
    
    mov ax,0xb800
    mov es,ax

    ; Clear OLD car position (not current one)
    mov bx, [old_car_position]
    
    ; Row 22 - Clear 5 columns width
    mov ax, 22
    mov dx, 80
    mul dx
    add ax, bx
    dec ax          ; Start from old_car_position-1
    shl ax, 1
    mov di, ax
    mov cx, 5       ; Clear 5 columns
clear_row22_old:
    mov word [es:di], 0x0720  ; Space with black background
    add di, 2
    loop clear_row22_old
    
    ; Row 23 - Clear 5 columns width  
    mov ax, 23
    mov dx, 80
    mul dx
    add ax, bx
    dec ax          ; Start from old_car_position-1
    shl ax, 1
    mov di, ax
    mov cx, 5       ; Clear 5 columns
clear_row23_old:
    mov word [es:di], 0x0720  ; Space with black background
    add di, 2
    loop clear_row23_old
    
    ; Row 24 - Clear 5 columns width
    mov ax, 24
    mov dx, 80
    mul dx
    add ax, bx
    dec ax          ; Start from old_car_position-1
    shl ax, 1
    mov di, ax
    mov cx, 5       ; Clear 5 columns
clear_row24_old:
    mov word [es:di], 0x0720  ; Space with black background
    add di, 2
    loop clear_row24_old

    ; Update old position to current position for next frame
    mov ax, [car_position]
    mov [old_car_position], ax

    pop ax
    pop bx
    pop cx
    pop di
    pop es
    ret

; -------------------------------
; Draw Player Car
; -------------------------------
DrawCar:
    push es
    push di
    push ax
    push bx
    push dx
    
    mov ax,0xb800
    mov es,ax

    ; Calculate car position in video memory
    mov bx, [car_position]
    
    ; Car at row 23, columns based on car_position
    mov ax, 23
    mov dx, 80
    mul dx
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; Draw car body
    mov word [es:di-2], 0x7511    ; Left part
    mov word [es:di], 0x73DB      ; Middle part
    mov word [es:di+2], 0x73DB  
    mov word [es:di+4], 0x73DB    ; Middle part
    mov word [es:di+6], 0x7510    ; Right part

    ; Row below (row 24)
    add di, 160
    mov word [es:di-2], 0x7511    ; Left part
    mov word [es:di], 0x73DB      ; Middle part
    mov word [es:di+2], 0x73DB  
    mov word [es:di+4], 0x73DB    ; Middle part
    mov word [es:di+6], 0x7510    ; Right part

    pop dx
    pop bx
    pop ax
    pop di
    pop es
    ret

; -------------------------------
; Check Keyboard Input - MODIFIED
; -------------------------------
CheckInput:
    ; Check if ESC was pressed (using our INT 9 handler)
    cmp byte [esc_pressed], 1
    jne check_normal_keys
    
    ; Reset ESC flag
    mov byte [esc_pressed], 0
    
    ; Show exit confirmation
    call ExitConfirmationScreen
    jmp no_input
    
check_normal_keys:
    ; Check for normal keyboard input
    mov ah, 01h       ;check for interrupt
    int 16h
    jz no_input        
    
    mov ah, 00h       ;check from buffer
    int 16h
    
    cmp ah, 4Bh   ;left
    je move_left
    
    cmp ah, 4Dh
    je move_right   ;right
    
    jmp no_input

move_left:
    mov bx, [car_position]
    cmp bx, 17          ;left capacity
    jle no_input      
    sub bx, 5         
    mov [car_position], bx
    jmp no_input

move_right:
    mov bx, [car_position]
    cmp bx, 58      ;right capacity
    jge no_input      
    add bx, 5         
    mov [car_position], bx

no_input:
    ret

; -------------------------------
; Delay (Slowed Down)
; -------------------------------
delay:
    push cx
    mov cx, 25       ; Increased from 15 to 25 to slow down game
delay_loop1:
    push cx
    mov cx, 0x2FFF   ; Keep at 0x2FFF for moderate slowdown
delay_loop2:
    loop delay_loop2
    pop cx
    loop delay_loop1
    pop cx
    ret

; -------------------------------
; Smart Scroll with Object Wrap-Around 
; -------------------------------
scroll_wrap:
    pusha
    mov ax,0xb800
    mov es,ax

    ; 1. Save top row
    mov si,0         ; Start from top row
    mov di,buffer
    mov cx,80
save_top:
    mov ax,[es:si]
    mov [di],ax
    add si,2
    add di,2
    loop save_top

    ; 2. Scroll all up by 1 row
    mov si,160       ; Start from row 1
    mov di,0         ; Destination row 0
    mov cx,(24*80)   ; Scroll 24 rows
scroll_loop:
    mov ax,[es:si]
    mov [es:di],ax
    add si,2
    add di,2
    loop scroll_loop

    ; 3. Copy saved top row to last row
    mov si,buffer
    mov di,24*80*2   ; Last row (row 24)
    mov cx,80
copy_bottom:
    mov ax,[si]
    mov [es:di],ax
    add si,2
    add di,2
    loop copy_bottom

    ; 4. Update tree positions for wrap-around - YEH AB TIMER ISR MEIN HOGI
    ; call UpdateTreePositions - REMOVED FROM HERE

    popa
    ret

; -------------------------------
; Main Program - MODIFIED
; -------------------------------
start:



    ; Install custom interrupt handlers
    call InstallInt8Handler  ; Timer ISR for TREE scrolling only
    call InstallInt9Handler  ; Keyboard ISR
    
    mov ax,0xb800
    mov es,ax

    ; Show welcome screen first
    call DrawWelcomeScreen
    
    ; Initialize game state
    mov word [car_position], 37
    mov word [old_car_position], 37
    mov byte [game_active], 1
    mov word [score], 0
    mov word [bonus_counter], 0
    mov word [tree_scroll_counter], 0
    mov byte [esc_pressed], 0
    mov byte [game_paused], 0

    call ClearScreen
    call DrawLanes
    call DrawGrass
    call DrawTrees
    call DrawFlowers
    call DrawCar
    call UpdateScoreDisplay  ; Initialize score display

game_loop:
    cmp byte [game_active], 0
    je show_game_over
    
    ; Check if game is paused
    cmp byte [game_paused], 1
    je game_loop  ; If paused, just loop without updating
    
    ; REMOVED: inc word [score] - Score no longer increases automatically
    
    call CheckInput      
    call CheckCollision   ; Check for collisions
    
    ; Generate and update random obstacle cars
    call GenerateObstacleCars
    call UpdateObstacleCars
    
    ; Generate and update bonus objects
    call GenerateBonusObjects
    call UpdateBonusObjects
  
    call scroll_wrap     ; APKA ORIGINAL SCREEN SCROLLING - YAHIN RAHEGA
    call ClearCarArea   
    call DrawLanes      
    call DrawGrass
    call DrawTrees       ; TREES AB TIMER ISR SE UPDATE HONGE
    call DrawFlowers
    call DrawObstacleCars  ; Draw obstacle cars
    call DrawBonusObjects  ; Draw bonus objects
    call UpdateScoreDisplay ; Update score display (in case bonus was collected)
    call DrawCar         
    
    call delay           
    
    jmp game_loop

show_game_over:
    ; Restore original interrupt handlers before showing game over screen
    call RestoreInt8Handler
    call RestoreInt9Handler
    
    call DrawGameOverScreen
    jmp start  ; Restart the game

exit_program:
    ; Restore original interrupt handlers before exiting
    call RestoreInt8Handler
    call RestoreInt9Handler
    
    mov ax,4C00h
    int 21h