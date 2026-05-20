bits 64
default rel

global main
extern printf, Sleep, GetAsyncKeyState, rand, srand, time, system, _getch

section .data
    ; Screen Dimensions
    MAX_X equ 40
    MAX_Y equ 20
    MAX_X_M1 equ 39
    MAX_Y_M1 equ 19
    
    ; Commands
    cmd_pause     db "pause", 0
    
    ; ANSI Escape Sequences
    ansi_home     db 27, "[H", 0
    ansi_hide     db 27, "[?25l", 0
    ansi_show     db 27, "[?25h", 0
    ansi_reset    db 27, "[0m", 0
    ansi_blue     db 27, "[34m", 0
    ansi_red      db 27, "[31m", 0
    ansi_cyan     db 27, "[36m", 0
    ansi_magenta  db 27, "[35m", 0
    ansi_yellow   db 27, "[33m", 0
    ansi_white    db 27, "[37m", 0

    ; Symbols
    char_wall     db "#", 0
    char_snake_a  db "O", 0
    char_snake_b  db "X", 0
    char_apple    db "@", 0
    char_empty    db " ", 0

    fmt_ui        db "Player A Lives: %d  |  Player B Lives: %d       ", 10, 0
    fmt_str       db "%s", 0
    fmt_respawn   db "(%d)", 0
    newline       db 10, 0

    msg_a_win     db 10, "GAME OVER: Player A wins! (B lost all lives)", 10, 0
    msg_b_win     db 10, "GAME OVER: Player B wins! (A lost all lives)", 10, 0
    msg_draw      db 10, "GAME OVER: It's a DRAW!", 10, 0

    ; Corpse Logic
    num_corpse_apples dq 0
    corpse_apples_x times 800 dd -1
    corpse_apples_y times 800 dd -1

    ; Player A
    playerA_x     times 200 dd 0
    playerA_y     times 200 dd 0
    playerA_head  dq 0
    playerA_len   dq 3
    playerA_dir   dd 3 ; 0:Up, 1:Down, 2:Left, 3:Right
    playerA_score dq 0 ; (Commented out logically)
    playerA_lives dq 3
    playerA_alive db 1
    playerA_respawn_timer dq 0
    playerA_start_x dd 10
    playerA_start_y dd 10

    ; Player B
    playerB_x     times 200 dd 0
    playerB_y     times 200 dd 0
    playerB_head  dq 0
    playerB_len   dq 3
    playerB_dir   dd 2
    playerB_score dq 0 ; (Commented out logically)
    playerB_lives dq 3
    playerB_alive db 1
    playerB_respawn_timer dq 0
    playerB_start_x dd 30
    playerB_start_y dd 10

    ; Apple
    apple_x       dd 15
    apple_y       dd 12

    ; Grid for optimization
    grid          times 800 db 0 ; MAX_X * MAX_Y
    frame_buffer  times 16384 db 0

    ; Key codes
    VK_UP    equ 0x26
    VK_DOWN  equ 0x28
    VK_LEFT  equ 0x25
    VK_RIGHT equ 0x27
    VK_W     equ 0x57
    VK_A     equ 0x41
    VK_S     equ 0x53
    VK_D     equ 0x44
    VK_Q     equ 0x51

section .text

main:
    sub rsp, 40
    xor rcx, rcx
    call time
    mov rcx, rax
    call srand
    call reset_player_a
    call reset_player_b
    lea rcx, [rel ansi_hide]
    call printf

game_loop:
    call handle_input
    call update_game
    call update_grid
    call render_game
    mov rcx, 100
    call Sleep

    ; Exit on Q
    mov rcx, VK_Q
    call GetAsyncKeyState
    test ax, ax
    jnz exit_game

    ; Game Over Check: If any life reaches 0
    cmp qword [rel playerA_lives], 0
    jle exit_game
    cmp qword [rel playerB_lives], 0
    jle exit_game

    jmp game_loop

exit_game:
    lea rcx, [rel ansi_show]
    call printf
    lea rcx, [rel newline]
    call printf

    mov rax, [rel playerA_lives]
    mov rbx, [rel playerB_lives]
    
    cmp rax, rbx
    jg .a_wins
    jl .b_wins
    
    ; Both 0 or equal (Draw if Q pressed)
    lea rcx, [rel msg_draw]
    call printf
    jmp .exit_done

.a_wins:
    lea rcx, [rel msg_a_win]
    call printf
    jmp .exit_done

.b_wins:
    lea rcx, [rel msg_b_win]
    call printf

.exit_done:
    lea rcx, [rel cmd_pause]
    call system
    add rsp, 40
    ret

reset_player_a:
    mov byte [rel playerA_alive], 1
    mov qword [rel playerA_len], 3
    mov dword [rel playerA_dir], 3
    mov qword [rel playerA_head], 0
    mov eax, [rel playerA_start_x]
    mov dword [rel playerA_x], eax
    sub eax, 1
    mov dword [rel playerA_x+4], eax
    sub eax, 1
    mov dword [rel playerA_x+8], eax
    mov eax, [rel playerA_start_y]
    mov dword [rel playerA_y], eax
    mov dword [rel playerA_y+4], eax
    mov dword [rel playerA_y+8], eax
    ret

reset_player_b:
    mov byte [rel playerB_alive], 1
    mov qword [rel playerB_len], 3
    mov dword [rel playerB_dir], 2
    mov qword [rel playerB_head], 0
    mov eax, [rel playerB_start_x]
    mov dword [rel playerB_x], eax
    add eax, 1
    mov dword [rel playerB_x+4], eax
    add eax, 1
    mov dword [rel playerB_x+8], eax
    mov eax, [rel playerB_start_y]
    mov dword [rel playerB_y], eax
    mov dword [rel playerB_y+4], eax
    mov dword [rel playerB_y+8], eax
    ret

handle_input:
    sub rsp, 40
    mov rcx, VK_W
    call GetAsyncKeyState
    test ax, ax
    jz .check_s
    cmp dword [rel playerA_dir], 1
    je .check_s
    mov dword [rel playerA_dir], 0
.check_s:
    mov rcx, VK_S
    call GetAsyncKeyState
    test ax, ax
    jz .check_a
    cmp dword [rel playerA_dir], 0
    je .check_a
    mov dword [rel playerA_dir], 1
.check_a:
    mov rcx, VK_A
    call GetAsyncKeyState
    test ax, ax
    jz .check_d
    cmp dword [rel playerA_dir], 3
    je .check_d
    mov dword [rel playerA_dir], 2
.check_d:
    mov rcx, VK_D
    call GetAsyncKeyState
    test ax, ax
    jz .playerB
    cmp dword [rel playerA_dir], 2
    je .playerB
    mov dword [rel playerA_dir], 3
.playerB:
    mov rcx, VK_UP
    call GetAsyncKeyState
    test ax, ax
    jz .check_down
    cmp dword [rel playerB_dir], 1
    je .check_down
    mov dword [rel playerB_dir], 0
.check_down:
    mov rcx, VK_DOWN
    call GetAsyncKeyState
    test ax, ax
    jz .check_left
    cmp dword [rel playerB_dir], 0
    je .check_left
    mov dword [rel playerB_dir], 1
.check_left:
    mov rcx, VK_LEFT
    call GetAsyncKeyState
    test ax, ax
    jz .check_right
    cmp dword [rel playerB_dir], 3
    je .check_right
    mov dword [rel playerB_dir], 2
.check_right:
    mov rcx, VK_RIGHT
    call GetAsyncKeyState
    test ax, ax
    jz .input_done
    cmp dword [rel playerB_dir], 2
    je .input_done
    mov dword [rel playerB_dir], 3
.input_done:
    add rsp, 40
    ret

update_game:
    sub rsp, 40
    
    ; 1. Respawn Logic A
    cmp byte [rel playerA_alive], 0
    jne .move_a
    cmp qword [rel playerA_lives], 0
    jle .update_b_respawn
    dec qword [rel playerA_respawn_timer]
    jnz .update_b_respawn
    call reset_player_a
    jmp .update_b_respawn
.move_a:
    ; Update head index
    mov rax, [rel playerA_head]
    mov rbx, rax ; Save old head index
    dec rax
    jge .a_h_ok
    mov rax, 199
.a_h_ok:
    mov [rel playerA_head], rax
    
    lea r8, [rel playerA_x]
    mov ecx, [r8 + rbx*4]
    lea r9, [rel playerA_y]
    mov edx, [r9 + rbx*4]

    mov eax, [rel playerA_dir]
    cmp eax, 0
    je .a_up
    cmp eax, 1
    je .a_down
    cmp eax, 2
    je .a_left
    cmp eax, 3
    je .a_right
    jmp .a_wrap
.a_up:
    dec edx
    jmp .a_wrap
.a_down:
    inc edx
    jmp .a_wrap
.a_left:
    dec ecx
    jmp .a_wrap
.a_right:
    inc ecx
    jmp .a_wrap
.a_wrap:
    ; Wrap X
    cmp ecx, 0
    jge .a_w_r
    mov ecx, MAX_X_M1 - 1
    jmp .a_w_y
.a_w_r:
    cmp ecx, MAX_X_M1
    jl .a_w_y
    mov ecx, 1
.a_w_y:
    ; Wrap Y
    cmp edx, 0
    jge .a_w_b
    mov edx, MAX_Y_M1 - 1
    jmp .a_store
.a_w_b:
    cmp edx, MAX_Y_M1
    jl .a_store
    mov edx, 1
.a_store:
    mov rdi, [rel playerA_head]
    lea r8, [rel playerA_x]
    mov [r8 + rdi*4], ecx
    lea r9, [rel playerA_y]
    mov [r9 + rdi*4], edx

.update_b_respawn:
    ; 1. Respawn Logic B
    cmp byte [rel playerB_alive], 0
    jne .move_b
    cmp qword [rel playerB_lives], 0
    jle .collision_checks
    dec qword [rel playerB_respawn_timer]
    jnz .collision_checks
    call reset_player_b
    jmp .collision_checks
.move_b:
    ; Update head index
    mov rax, [rel playerB_head]
    mov rbx, rax ; Save old head index
    dec rax
    jge .b_h_ok
    mov rax, 199
.b_h_ok:
    mov [rel playerB_head], rax
    
    lea r8, [rel playerB_x]
    mov ecx, [r8 + rbx*4]
    lea r9, [rel playerB_y]
    mov edx, [r9 + rbx*4]

    mov eax, [rel playerB_dir]
    cmp eax, 0
    je .b_up
    cmp eax, 1
    je .b_down
    cmp eax, 2
    je .b_left
    cmp eax, 3
    je .b_right
    jmp .b_wrap
.b_up:
    dec edx
    jmp .b_wrap
.b_down:
    inc edx
    jmp .b_wrap
.b_left:
    dec ecx
    jmp .b_wrap
.b_right:
    inc ecx
    jmp .b_wrap
.b_wrap:
    ; Wrap X
    cmp ecx, 0
    jge .b_w_r
    mov ecx, MAX_X_M1 - 1
    jmp .b_w_y
.b_w_r:
    cmp ecx, MAX_X_M1
    jl .b_w_y
    mov ecx, 1
.b_w_y:
    ; Wrap Y
    cmp edx, 0
    jge .b_w_b
    mov edx, MAX_Y_M1 - 1
    jmp .b_store
.b_w_b:
    cmp edx, MAX_Y_M1
    jl .b_store
    mov edx, 1
.b_store:
    mov rdi, [rel playerB_head]
    lea r8, [rel playerB_x]
    mov [r8 + rdi*4], ecx
    lea r9, [rel playerB_y]
    mov [r9 + rdi*4], edx

.collision_checks:
    ; A against Grid
    cmp byte [rel playerA_alive], 0
    je .coll_b
    mov rdi, [rel playerA_head]
    lea r8, [rel playerA_y]
    mov eax, [r8 + rdi*4]
    imul eax, MAX_X
    lea r9, [rel playerA_x]
    add eax, [r9 + rdi*4]
    lea r8, [rel grid]
    movzx r15, byte [r8 + rax]
    
    cmp r15, 1 ; Wall
    je .a_dies_coll
    cmp r15, 4 ; Self
    je .a_dies_coll
    cmp r15, 5 ; Other
    je .a_dies_coll
    jmp .coll_b
.a_dies_coll:
    call a_die_logic

.coll_b:
    ; B against Grid
    cmp byte [rel playerB_alive], 0
    je .eat_checks
    mov rdi, [rel playerB_head]
    lea r8, [rel playerB_y]
    mov eax, [r8 + rdi*4]
    imul eax, MAX_X
    lea r9, [rel playerB_x]
    add eax, [r9 + rdi*4]
    lea r8, [rel grid]
    movzx r15, byte [r8 + rax]
    
    cmp r15, 1 ; Wall
    je .b_dies_coll
    cmp r15, 4 ; Other
    je .b_dies_coll
    cmp r15, 5 ; Self
    je .b_dies_coll
    jmp .eat_checks
.b_dies_coll:
    call b_die_logic

.eat_checks:
    cmp byte [rel playerA_alive], 0
    je .eat_b
    mov eax, [rel playerA_y]
    imul eax, MAX_X
    add eax, [rel playerA_x]
    lea r8, [rel grid]
    movzx r15, byte [r8 + rax]
    
    cmp r15, 2 ; Apple
    jne .check_ca_a
    inc qword [rel playerA_len]
    call spawn_apple
    jmp .eat_b
.check_ca_a:
    cmp r15, 3 ; Corpse Apple
    jne .eat_b
    ; Eat it, but must find which one to mark -1
    inc qword [rel playerA_len]
    mov r14, 0
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
.eca_a_find:
    cmp r14, [rel num_corpse_apples]
    jge .eat_b
    mov eax, [rel playerA_x]
    ; Wait, we need the head position. playerA_x[head]
    mov rdi, [rel playerA_head]
    lea r10, [rel playerA_x]
    mov eax, [r10 + rdi*4]
    cmp eax, [r8 + r14*4]
    jne .n_eca_a
    lea r11, [rel playerA_y]
    mov eax, [r11 + rdi*4]
    cmp eax, [r9 + r14*4]
    jne .n_eca_a
    mov dword [r8 + r14*4], -1
    jmp .eat_b
.n_eca_a:
    inc r14
    jmp .eca_a_find

.eat_b:
    cmp byte [rel playerB_alive], 0
    je .ud
    mov eax, [rel playerB_y]
    imul eax, MAX_X
    add eax, [rel playerB_x]
    lea r8, [rel grid]
    movzx r15, byte [r8 + rax]

    cmp r15, 2 ; Apple
    jne .check_ca_b
    inc qword [rel playerB_len]
    call spawn_apple
    jmp .ud
.check_ca_b:
    cmp r15, 3 ; Corpse Apple
    jne .ud
    inc qword [rel playerB_len]
    mov r14, 0
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
.eca_b_find:
    cmp r14, [rel num_corpse_apples]
    jge .ud
    mov rdi, [rel playerB_head]
    lea r10, [rel playerB_x]
    mov eax, [r10 + rdi*4]
    cmp eax, [r8 + r14*4]
    jne .n_eca_b
    lea r11, [rel playerB_y]
    mov eax, [r11 + rdi*4]
    cmp eax, [r9 + r14*4]
    jne .n_eca_b
    mov dword [r8 + r14*4], -1
    jmp .ud
.n_eca_b:
    inc r14
    jmp .eca_b_find

.ud:
    add rsp, 40
    ret

a_die_logic:
    dec qword [rel playerA_lives]
    mov r14, 0
    mov r15, [rel num_corpse_apples]
.adl:
    cmp r14, [rel playerA_len]
    jge .adld
    cmp r15, 800
    jge .adld
    mov rax, [rel playerA_head]
    add rax, r14
    cmp rax, 200
    jl .a_idx_ok
    sub rax, 200
.a_idx_ok:
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
    lea r11, [rel corpse_apples_x]
    lea r10, [rel corpse_apples_y]
    mov eax, [r8 + rax*4]
    mov [r11 + r15*4], eax
    mov eax, [r9 + rax*4]
    mov [r10 + r15*4], eax
    inc r14
    inc r15
    jmp .adl
.adld:
    mov [rel num_corpse_apples], r15
    mov byte [rel playerA_alive], 0
    mov qword [rel playerA_respawn_timer], 50
    ret

b_die_logic:
    dec qword [rel playerB_lives]
    mov r14, 0
    mov r15, [rel num_corpse_apples]
.bdl:
    cmp r14, [rel playerB_len]
    jge .bdld
    cmp r15, 800
    jge .bdld
    mov rax, [rel playerB_head]
    add rax, r14
    cmp rax, 200
    jl .b_idx_ok
    sub rax, 200
.b_idx_ok:
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
    lea r11, [rel corpse_apples_x]
    lea r10, [rel corpse_apples_y]
    mov eax, [r8 + rax*4]
    mov [r11 + r15*4], eax
    mov eax, [r9 + rax*4]
    mov [r10 + r15*4], eax
    inc r14
    inc r15
    jmp .bdl
.bdld:
    mov [rel num_corpse_apples], r15
    mov byte [rel playerB_alive], 0
    mov qword [rel playerB_respawn_timer], 50
    ret

spawn_apple:
    sub rsp, 40
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
    add rsp, 40
    ret

update_grid:
    sub rsp, 40
    lea rdi, [rel grid]
    mov rcx, 800
    xor al, al
    cld
    rep stosb

    ; 1. Walls
    lea r8, [rel grid]
    mov rcx, MAX_X
.wall_h:
    dec rcx
    mov byte [r8 + rcx], 1
    mov byte [r8 + (MAX_Y-1)*MAX_X + rcx], 1
    test rcx, rcx
    jnz .wall_h
    mov rcx, MAX_Y
.wall_v:
    dec rcx
    mov rax, rcx
    imul rax, MAX_X
    mov byte [r8 + rax], 1
    mov byte [r8 + rax + MAX_X - 1], 1
    test rcx, rcx
    jnz .wall_v

    ; 2. Apple
    mov eax, [rel apple_y]
    imul eax, MAX_X
    add eax, [rel apple_x]
    lea r8, [rel grid]
    mov byte [r8 + rax], 2

    ; 3. Corpse Apples
    mov r14, 0
.ca_loop:
    cmp r14, [rel num_corpse_apples]
    jge .snake_a
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
    mov eax, [r9 + r14*4]
    cmp eax, -1
    je .next_ca
    imul eax, MAX_X
    add eax, [r8 + r14*4]
    lea r10, [rel grid]
    mov byte [r10 + rax], 3
.next_ca:
    inc r14
    jmp .ca_loop

    ; 4. Snake A
.snake_a:
    cmp byte [rel playerA_alive], 0
    je .respawn_a
    mov r14, 0
.la:
    cmp r14, [rel playerA_len]
    jge .snake_b
    mov rax, [rel playerA_head]
    add rax, r14
    cmp rax, 200
    jl .a_idx_ok
    sub rax, 200
.a_idx_ok:
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
    mov edx, [r9 + rax*4]
    imul edx, MAX_X
    add edx, [r8 + rax*4]
    lea r10, [rel grid]
    mov byte [r10 + rdx], 4
    inc r14
    jmp .la

.respawn_a:
    cmp qword [rel playerA_lives], 0
    jle .snake_b
    mov eax, [rel playerA_start_y]
    imul eax, MAX_X
    add eax, [rel playerA_start_x]
    lea r8, [rel grid]
    mov byte [r8 + rax], 6

    ; 5. Snake B
.snake_b:
    cmp byte [rel playerB_alive], 0
    je .respawn_b
    mov r14, 0
.lb:
    cmp r14, [rel playerB_len]
    jge .grid_done
    mov rax, [rel playerB_head]
    add rax, r14
    cmp rax, 200
    jl .b_idx_ok
    sub rax, 200
.b_idx_ok:
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
    mov edx, [r9 + rax*4]
    imul edx, MAX_X
    add edx, [r8 + rax*4]
    lea r10, [rel grid]
    mov byte [r10 + rdx], 5
    inc r14
    jmp .lb

.respawn_b:
    cmp qword [rel playerB_lives], 0
    jle .grid_done
    mov eax, [rel playerB_start_y]
    imul eax, MAX_X
    add eax, [rel playerB_start_x]
    lea r8, [rel grid]
    mov byte [r8 + rax], 7

.grid_done:
    add rsp, 40
    ret

render_game:
    sub rsp, 40
    lea rcx, [rel ansi_home]
    call printf
    lea rcx, [rel fmt_ui]
    mov rdx, [rel playerA_lives]
    mov r8, [rel playerB_lives]
    call printf
    
    lea rdi, [rel frame_buffer]
    mov r14, -1 ; Current color state (-1: none, 0: reset, 1: white, 2: yellow, 3: cyan, 4: magenta)

    mov r12, 0 ; Y
.ly:
    mov r13, 0 ; X
.lx:
    mov rax, r12
    imul rax, MAX_X
    add rax, r13
    lea r8, [rel grid]
    movzx r15, byte [r8 + rax]
    
    ; Determine required color
    mov r8, 0 ; Default: reset
    cmp r15, 0
    je .apply_color
    cmp r15, 1
    je .set_white
    cmp r15, 2
    je .set_yellow
    cmp r15, 3
    je .set_yellow
    cmp r15, 4
    je .set_cyan
    cmp r15, 5
    je .set_magenta
    cmp r15, 6
    je .set_cyan
    cmp r15, 7
    je .set_magenta
    jmp .apply_color

.set_white:
    mov r8, 1
    jmp .apply_color
.set_yellow:
    mov r8, 2
    jmp .apply_color
.set_cyan:
    mov r8, 3
    jmp .apply_color
.set_magenta:
    mov r8, 4
    jmp .apply_color

.apply_color:
    cmp r8, r14
    je .color_ok
    mov r14, r8
    ; Add ANSI code
    cmp r8, 0
    je .write_reset
    cmp r8, 1
    je .write_white
    cmp r8, 2
    je .write_yellow
    cmp r8, 3
    je .write_cyan
    cmp r8, 4
    je .write_magenta
    jmp .color_ok

.write_reset:
    lea rsi, [rel ansi_reset]
    call .append_str
    jmp .color_ok
.write_white:
    lea rsi, [rel ansi_white]
    call .append_str
    jmp .color_ok
.write_yellow:
    lea rsi, [rel ansi_yellow]
    call .append_str
    jmp .color_ok
.write_cyan:
    lea rsi, [rel ansi_cyan]
    call .append_str
    jmp .color_ok
.write_magenta:
    lea rsi, [rel ansi_magenta]
    call .append_str
    jmp .color_ok

.color_ok:
    ; Add Character
    cmp r15, 0
    je .char_empty
    cmp r15, 1
    je .char_wall
    cmp r15, 2
    je .char_apple
    cmp r15, 3
    je .char_apple
    cmp r15, 4
    je .char_snake_a
    cmp r15, 5
    je .char_snake_b
    cmp r15, 6
    je .char_resp_a
    cmp r15, 7
    je .char_resp_b
    jmp .next_pixel

.char_empty:
    mov byte [rdi], " "
    inc rdi
    jmp .next_pixel
.char_wall:
    mov byte [rdi], "#"
    inc rdi
    jmp .next_pixel
.char_apple:
    mov byte [rdi], "@"
    inc rdi
    jmp .next_pixel
.char_snake_a:
    mov byte [rdi], "O"
    inc rdi
    jmp .next_pixel
.char_snake_b:
    mov byte [rdi], "X"
    inc rdi
    jmp .next_pixel

.char_resp_a:
    mov rdx, [rel playerA_respawn_timer]
    add rdx, 9
    mov rax, rdx
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov byte [rdi], "("
    mov byte [rdi+1], al
    mov byte [rdi+2], ")"
    add rdi, 3
    add r13, 2 ; Respawn is 3 chars
    jmp .next_pixel

.char_resp_b:
    mov rdx, [rel playerB_respawn_timer]
    add rdx, 9
    mov rax, rdx
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov byte [rdi], "("
    mov byte [rdi+1], al
    mov byte [rdi+2], ")"
    add rdi, 3
    add r13, 2 ; Respawn is 3 chars
    jmp .next_pixel

.next_pixel:
    inc r13
    cmp r13, MAX_X
    jl .lx
    
    mov byte [rdi], 10 ; Newline
    inc rdi
    inc r12
    cmp r12, MAX_Y
    jl .ly

    mov byte [rdi], 0 ; Null terminator
    lea rcx, [rel fmt_str]
    lea rdx, [rel frame_buffer]
    call printf
    
    add rsp, 40
    ret

.append_str:
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
