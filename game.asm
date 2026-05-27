; Snake Game in x86-64 Assembly (NASM Syntax)
; Lightweight Refactor based on @project.md
bits 64
default rel

global main
extern printf, Sleep, GetAsyncKeyState, rand, srand, time, system

section .data
    ; Screen Dimensions
    MAX_X equ 40
    MAX_Y equ 20
    
    ; ANSI Escape Sequences
    ansi_home     db 27, "[H", 0
    ansi_hide     db 27, "[?25l", 0
    ansi_show     db 27, "[?25h", 0
    ansi_reset    db 27, "[0m", 0
    ansi_cyan     db 27, "[36m", 0
    ansi_magenta  db 27, "[35m", 0
    ansi_yellow   db 27, "[33m", 0
    ansi_white    db 27, "[37m", 0

    fmt_ui        db "  [Player A: O]    vs    [Player B: X]  ", 10, 0
    fmt_str       db "%s", 0
    msg_a_win     db 10, "GAME OVER: Player A wins!", 10, 0
    msg_b_win     db 10, "GAME OVER: Player B wins!", 10, 0
    msg_draw      db 10, "GAME OVER: It's a DRAW!", 10, 0
    cmd_pause     db "pause > nul", 0

    ; Player Structure Offsets
    O_X_PTR    equ 0  ; X array pointer (8 bytes)
    O_Y_PTR    equ 8  ; Y array pointer (8 bytes)
    O_DIR      equ 16 ; direction (4 bytes)
    O_LEN      equ 20 ; length (4 bytes)

    ; Player A Data
    playerA_x   times 800 dd 0
    playerA_y   times 800 dd 0
    playerA_obj dq playerA_x, playerA_y
                dd 3   ; Initial Dir: Right
                dd 3   ; Initial Len

    ; Player B Data
    playerB_x   times 800 dd 0
    playerB_y   times 800 dd 0
    playerB_obj dq playerB_x, playerB_y
                dd 2   ; Initial Dir: Left
                dd 3   ; Initial Len

    apple_x     dd 15
    apple_y     dd 12
    game_over   db 0
    winner      db 0   ; 1: A, 2: B, 3: Draw

    grid        times 800 db 0 ; MAX_X * MAX_Y
    buffer      times 4096 db 0

section .text

main:
    sub rsp, 40
    xor rcx, rcx
    call time
    mov rcx, rax
    call srand
    
    ; Initialize Positions
    mov dword [rel playerA_x], 10
    mov dword [rel playerA_y], 10
    mov dword [rel playerB_x], 30
    mov dword [rel playerB_y], 10
    
    lea rcx, [rel ansi_hide]
    call printf

.game_loop:
    call handle_input
    
    lea rcx, [rel playerA_obj]
    call move_player
    lea rcx, [rel playerB_obj]
    call move_player
    
    call update_game_state
    call render_game
    
    mov rcx, 100
    call Sleep
    
    cmp byte [rel game_over], 0
    je .game_loop

    ; Result Output
    lea rcx, [rel ansi_show]
    call printf
    
    movzx rax, byte [rel winner]
    cmp rax, 1
    je .a_wins
    cmp rax, 2
    je .b_wins
    lea rcx, [rel msg_draw]
    jmp .print_done
.a_wins:
    lea rcx, [rel msg_a_win]
    jmp .print_done
.b_wins:
    lea rcx, [rel msg_b_win]
.print_done:
    call printf
    
    lea rcx, [rel cmd_pause]
    call system
    add rsp, 40
    ret

move_player:
    mov r8, [rcx + O_X_PTR]
    mov r9, [rcx + O_Y_PTR]
    mov eax, [rcx + O_DIR]
    mov r10d, [rcx + O_LEN]

    ; Shift Body
    mov rdx, r10
.shift_loop:
    dec rdx
    jz .move_head
    mov r11d, [r8 + rdx*4 - 4]
    mov [r8 + rdx*4], r11d
    mov r11d, [r9 + rdx*4 - 4]
    mov [r9 + rdx*4], r11d
    jmp .shift_loop

.move_head:
    mov r11d, [r8]
    mov r12d, [r9]
    cmp eax, 0 ; Up
    je .up
    cmp eax, 1 ; Down
    je .down
    cmp eax, 2 ; Left
    je .left
    inc r11d   ; Right
    jmp .wrap
.up:    dec r12d
        jmp .wrap
.down:  inc r12d
        jmp .wrap
.left:  dec r11d

.wrap:
    ; Wrapping logic
    cmp r11d, 0
    jge .w1
    mov r11d, MAX_X - 1
.w1:
    cmp r11d, MAX_X
    jl .w2
    mov r11d, 0
.w2:
    cmp r12d, 0
    jge .w3
    mov r12d, MAX_Y - 1
.w3:
    cmp r12d, MAX_Y
    jl .done
    mov r12d, 0
.done:
    mov [r8], r11d
    mov [r9], r12d
    ret

handle_input:
    sub rsp, 40
    ; Player A: WASD (W:0x57, S:0x53, A:0x41, D:0x44)
    mov rcx, 0x57 ; W
    call GetAsyncKeyState
    test ax, ax
    jz .s_a
    cmp dword [rel playerA_obj + O_DIR], 1
    je .s_a
    mov dword [rel playerA_obj + O_DIR], 0
.s_a:
    mov rcx, 0x53 ; S
    call GetAsyncKeyState
    test ax, ax
    jz .a_a
    cmp dword [rel playerA_obj + O_DIR], 0
    je .a_a
    mov dword [rel playerA_obj + O_DIR], 1
.a_a:
    mov rcx, 0x41 ; A
    call GetAsyncKeyState
    test ax, ax
    jz .d_a
    cmp dword [rel playerA_obj + O_DIR], 3
    je .d_a
    mov dword [rel playerA_obj + O_DIR], 2
.d_a:
    mov rcx, 0x44 ; D
    call GetAsyncKeyState
    test ax, ax
    jz .playerB
    cmp dword [rel playerA_obj + O_DIR], 2
    je .playerB
    mov dword [rel playerA_obj + O_DIR], 3

.playerB:
    ; Player B: Arrows (Up:0x26, Down:0x28, Left:0x25, Right:0x27)
    mov rcx, 0x26
    call GetAsyncKeyState
    test ax, ax
    jz .s_b
    cmp dword [rel playerB_obj + O_DIR], 1
    je .s_b
    mov dword [rel playerB_obj + O_DIR], 0
.s_b:
    mov rcx, 0x28
    call GetAsyncKeyState
    test ax, ax
    jz .a_b
    cmp dword [rel playerB_obj + O_DIR], 0
    je .a_b
    mov dword [rel playerB_obj + O_DIR], 1
.a_b:
    mov rcx, 0x25
    call GetAsyncKeyState
    test ax, ax
    jz .d_b
    cmp dword [rel playerB_obj + O_DIR], 3
    je .d_b
    mov dword [rel playerB_obj + O_DIR], 2
.d_b:
    mov rcx, 0x27
    call GetAsyncKeyState
    test ax, ax
    jz .input_done
    cmp dword [rel playerB_obj + O_DIR], 2
    je .input_done
    mov dword [rel playerB_obj + O_DIR], 3

.input_done:
    add rsp, 40
    ret

update_game_state:
    sub rsp, 40
    ; 1. Update Grid
    lea rdi, [rel grid]
    mov rcx, 800
    xor al, al
    rep stosb
    
    ; Walls
    lea r8, [rel grid]
    mov rcx, MAX_X
.w_loop:
    dec rcx
    mov byte [r8 + rcx], 1
    mov byte [r8 + (MAX_Y-1)*MAX_X + rcx], 1
    test rcx, rcx
    jnz .w_loop
    mov rcx, MAX_Y
.w_v_loop:
    dec rcx
    mov rax, rcx
    imul rax, MAX_X
    mov byte [r8 + rax], 1
    mov byte [r8 + rax + MAX_X - 1], 1
    test rcx, rcx
    jnz .w_v_loop

    ; Apple
    mov eax, [rel apple_y]
    imul eax, MAX_X
    add eax, [rel apple_x]
    lea r8, [rel grid]
    mov byte [r8 + rax], 2

    ; Player A to grid (4)
    mov r8, [rel playerA_obj + O_X_PTR]
    mov r9, [rel playerA_obj + O_Y_PTR]
    mov ecx, [rel playerA_obj + O_LEN]
    xor rdx, rdx
.a_grid:
    mov eax, [r9 + rdx*4]
    imul eax, MAX_X
    add eax, [r8 + rdx*4]
    lea r10, [rel grid]
    mov byte [r10 + rax], 4
    inc rdx
    cmp edx, ecx
    jl .a_grid

    ; Player B to grid (5)
    mov r8, [rel playerB_obj + O_X_PTR]
    mov r9, [rel playerB_obj + O_Y_PTR]
    mov ecx, [rel playerB_obj + O_LEN]
    xor rdx, rdx
.b_grid:
    mov eax, [r9 + rdx*4]
    imul eax, MAX_X
    add eax, [r8 + rdx*4]
    lea r10, [rel grid]
    mov byte [r10 + rax], 5
    inc rdx
    cmp edx, ecx
    jl .b_grid

    ; 2. Check Collisions
    ; Player A head
    mov eax, [rel playerA_y]
    imul eax, MAX_X
    add eax, [rel playerA_x]
    lea r8, [rel grid]
    movzx r10, byte [r8 + rax]
    ; It will see itself (4), so we need to check if it's something ELSE or collision with self body
    ; Simplified: check against a PRE-SNAKE grid for cleaner logic, but let's just check the move result.
    ; Actually, the grid already has both snakes. 
    ; If head of A is on a cell that was ALREADY occupied?
    ; Let's re-run collision check more carefully.
    
    ; Apple consumption A
    mov eax, [rel playerA_x]
    cmp eax, [rel apple_x]
    jne .check_b_apple
    mov eax, [rel playerA_y]
    cmp eax, [rel apple_y]
    jne .check_b_apple
    inc dword [rel playerA_obj + O_LEN]
    call spawn_apple
.check_b_apple:
    mov eax, [rel playerB_x]
    cmp eax, [rel apple_x]
    jne .check_collisions
    mov eax, [rel playerB_y]
    cmp eax, [rel apple_y]
    jne .check_collisions
    inc dword [rel playerB_obj + O_LEN]
    call spawn_apple

.check_collisions:
    ; Check A head against walls and OTHER snake, and OWN body
    ; A head vs Wall
    mov r8d, [rel playerA_x]
    mov r9d, [rel playerA_y]
    cmp r8d, 0
    je .a_coll
    cmp r8d, MAX_X - 1
    je .a_coll
    cmp r9d, 0
    je .a_coll
    cmp r9d, MAX_Y - 1
    je .a_coll
    
    ; A head vs B body
    mov r10, [rel playerB_obj + O_X_PTR]
    mov r11, [rel playerB_obj + O_Y_PTR]
    mov ecx, [rel playerB_obj + O_LEN]
    xor rdx, rdx
.a_vs_b:
    cmp r8d, [r10 + rdx*4]
    jne .a_next_b
    cmp r9d, [r11 + rdx*4]
    je .a_coll
.a_next_b:
    inc rdx
    cmp edx, ecx
    jl .a_vs_b

    ; A head vs A body (start from index 1)
    mov r10, [rel playerA_obj + O_X_PTR]
    mov r11, [rel playerA_obj + O_Y_PTR]
    mov ecx, [rel playerA_obj + O_LEN]
    mov rdx, 1
.a_vs_a:
    cmp edx, ecx
    jge .check_b_coll
    cmp r8d, [r10 + rdx*4]
    jne .a_next_a
    cmp r9d, [r11 + rdx*4]
    je .a_coll
.a_next_a:
    inc rdx
    jmp .a_vs_a

.a_coll:
    mov byte [rel game_over], 1
    mov byte [rel winner], 2 ; B wins
    jmp .check_draw

.check_b_coll:
    mov r8d, [rel playerB_x]
    mov r9d, [rel playerB_y]
    cmp r8d, 0
    je .b_coll
    cmp r8d, MAX_X - 1
    je .b_coll
    cmp r9d, 0
    je .b_coll
    cmp r9d, MAX_Y - 1
    je .b_coll

    ; B head vs A body
    mov r10, [rel playerA_obj + O_X_PTR]
    mov r11, [rel playerA_obj + O_Y_PTR]
    mov ecx, [rel playerA_obj + O_LEN]
    xor rdx, rdx
.b_vs_a:
    cmp r8d, [r10 + rdx*4]
    jne .b_next_a
    cmp r9d, [r11 + rdx*4]
    je .b_coll
.b_next_a:
    inc rdx
    cmp edx, ecx
    jl .b_vs_a

    ; B head vs B body
    mov r10, [rel playerB_obj + O_X_PTR]
    mov r11, [rel playerB_obj + O_Y_PTR]
    mov ecx, [rel playerB_obj + O_LEN]
    mov rdx, 1
.b_vs_b:
    cmp edx, ecx
    jge .done
    cmp r8d, [r10 + rdx*4]
    jne .b_next_b
    cmp r9d, [r11 + rdx*4]
    je .b_coll
.b_next_b:
    inc rdx
    jmp .b_vs_b

.b_coll:
    cmp byte [rel game_over], 1
    je .set_draw
    mov byte [rel game_over], 1
    mov byte [rel winner], 1 ; A wins
    jmp .done

.set_draw:
    mov byte [rel winner], 3
    jmp .done

.check_draw:
    ; If A already collided, check B as well in the same frame
    jmp .check_b_coll

.done:
    add rsp, 40
    ret

spawn_apple:
    sub rsp, 40
.retry:
    call rand
    xor rdx, rdx
    mov rcx, MAX_X - 2
    div rcx
    add rdx, 1
    mov [rel apple_x], edx
    call rand
    xor rdx, rdx
    mov rcx, MAX_Y - 2
    div rcx
    add rdx, 1
    mov [rel apple_y], edx
    
    ; Don't spawn on walls or snakes (simplified: check grid)
    mov eax, [rel apple_y]
    imul eax, MAX_X
    add eax, [rel apple_x]
    lea r8, [rel grid]
    cmp byte [r8 + rax], 0
    jne .retry
    
    add rsp, 40
    ret

render_game:
    sub rsp, 40
    lea rcx, [rel ansi_home]
    call printf
    lea rcx, [rel fmt_ui]
    call printf
    
    lea rdi, [rel buffer]
    xor r12, r12 ; Y
.ry:
    xor r13, r13 ; X
.rx:
    mov rax, r12
    imul rax, MAX_X
    add rax, r13
    lea r8, [rel grid]
    movzx r14, byte [r8 + rax]
    
    cmp r14, 0
    je .empty
    cmp r14, 1
    je .wall
    cmp r14, 2
    je .apple
    cmp r14, 4
    je .snakeA
    cmp r14, 5
    je .snakeB
    jmp .next
.empty:
    mov byte [rdi], ' '
    inc rdi
    jmp .next
.wall:
    lea rsi, [rel ansi_white]
    call .append
    mov byte [rdi], '#'
    inc rdi
    jmp .next
.apple:
    lea rsi, [rel ansi_yellow]
    call .append
    mov byte [rdi], '@'
    inc rdi
    jmp .next
.snakeA:
    lea rsi, [rel ansi_cyan]
    call .append
    mov byte [rdi], 'O'
    inc rdi
    jmp .next
.snakeB:
    lea rsi, [rel ansi_magenta]
    call .append
    mov byte [rdi], 'X'
    inc rdi
    jmp .next

.next:
    inc r13
    cmp r13, MAX_X
    jl .rx
    mov byte [rdi], 10
    inc rdi
    inc r12
    cmp r12, MAX_Y
    jl .ry
    
    lea rsi, [rel ansi_reset]
    call .append
    mov byte [rdi], 0
    
    lea rcx, [rel fmt_str]
    lea rdx, [rel buffer]
    call printf
    add rsp, 40
    ret

.append:
.al:
    mov al, [rsi]
    test al, al
    jz .ad
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .al
.ad:
    ret
