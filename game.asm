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
    mov rcx, [rel playerA_len]
    dec rcx
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
.shift_a:
    test rcx, rcx
    jz .shift_a_done
    mov eax, [r8 + rcx*4 - 4]
    mov [r8 + rcx*4], eax
    mov eax, [r9 + rcx*4 - 4]
    mov [r9 + rcx*4], eax
    dec rcx
    jmp .shift_a
.shift_a_done:
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
    dec dword [rel playerA_y]
    jmp .a_wrap
.a_down:
    inc dword [rel playerA_y]
    jmp .a_wrap
.a_left:
    dec dword [rel playerA_x]
    jmp .a_wrap
.a_right:
    inc dword [rel playerA_x]
    jmp .a_wrap
.a_wrap:
    mov eax, [rel playerA_x]
    cmp eax, 0
    jge .a_w_r
    mov dword [rel playerA_x], MAX_X_M1 - 1
    jmp .a_w_y
.a_w_r:
    cmp eax, MAX_X_M1
    jl .a_w_y
    mov dword [rel playerA_x], 1
.a_w_y:
    mov eax, [rel playerA_y]
    cmp eax, 0
    jge .a_w_b
    mov dword [rel playerA_y], MAX_Y_M1 - 1
    jmp .update_b_respawn
.a_w_b:
    cmp eax, MAX_Y_M1
    jl .update_b_respawn
    mov dword [rel playerA_y], 1

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
    mov rcx, [rel playerB_len]
    dec rcx
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
.shift_b:
    test rcx, rcx
    jz .shift_b_done
    mov eax, [r8 + rcx*4 - 4]
    mov [r8 + rcx*4], eax
    mov eax, [r9 + rcx*4 - 4]
    mov [r9 + rcx*4], eax
    dec rcx
    jmp .shift_b
.shift_b_done:
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
    dec dword [rel playerB_y]
    jmp .b_wrap
.b_down:
    inc dword [rel playerB_y]
    jmp .b_wrap
.b_left:
    dec dword [rel playerB_x]
    jmp .b_wrap
.b_right:
    inc dword [rel playerB_x]
    jmp .b_wrap
.b_wrap:
    mov eax, [rel playerB_x]
    cmp eax, 0
    jge .b_w_r
    mov dword [rel playerB_x], MAX_X_M1 - 1
    jmp .b_w_y
.b_w_r:
    cmp eax, MAX_X_M1
    jl .b_w_y
    mov dword [rel playerB_x], 1
.b_w_y:
    mov eax, [rel playerB_y]
    cmp eax, 0
    jge .b_w_b
    mov dword [rel playerB_y], MAX_Y_M1 - 1
    jmp .collision_checks
.b_w_b:
    cmp eax, MAX_Y_M1
    jl .collision_checks
    mov dword [rel playerB_y], 1

.collision_checks:
    cmp byte [rel playerA_alive], 0
    je .body_coll_checks
    cmp byte [rel playerB_alive], 0
    je .body_coll_checks
    mov eax, [rel playerA_x]
    cmp eax, [rel playerB_x]
    jne .body_coll_checks
    mov eax, [rel playerA_y]
    cmp eax, [rel playerB_y]
    jne .body_coll_checks
    mov rax, [rel playerA_len]
    cmp rax, [rel playerB_len]
    je .both_die
    jl .a_dies_h
    call b_die_logic
    jmp .eat_checks
.both_die:
    call a_die_logic
    call b_die_logic
    jmp .eat_checks
.a_dies_h:
    call a_die_logic
    jmp .eat_checks

.body_coll_checks:
    cmp byte [rel playerA_alive], 0
    je .skip_self_a
    mov r14, 1
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
.self_a:
    cmp r14, [rel playerA_len]
    jge .hit_b_a
    mov eax, [r8]
    cmp eax, [r8 + r14*4]
    jne .n_sa
    mov eax, [r9]
    cmp eax, [r9 + r14*4]
    je .a_dies_b
.n_sa:
    inc r14
    jmp .self_a
.a_dies_b:
    call a_die_logic
    jmp .skip_self_a
.hit_b_a:
    cmp byte [rel playerB_alive], 0
    je .skip_self_a
    mov r14, 0
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
.ha_loop:
    cmp r14, [rel playerB_len]
    jge .skip_self_a
    mov eax, [rel playerA_x]
    cmp eax, [r8 + r14*4]
    jne .next_ha
    mov eax, [rel playerA_y]
    cmp eax, [r9 + r14*4]
    je .a_dies_b
.next_ha:
    inc r14
    jmp .ha_loop

.skip_self_a:
    cmp byte [rel playerB_alive], 0
    je .eat_checks
    mov r14, 1
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
.self_b:
    cmp r14, [rel playerB_len]
    jge .hit_a_b
    mov eax, [r8]
    cmp eax, [r8 + r14*4]
    jne .n_sb
    mov eax, [r9]
    cmp eax, [r9 + r14*4]
    je .b_dies_b
.n_sb:
    inc r14
    jmp .self_b
.b_dies_b:
    call b_die_logic
    jmp .eat_checks
.hit_a_b:
    cmp byte [rel playerA_alive], 0
    je .eat_checks
    mov r14, 0
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
.hb_loop:
    cmp r14, [rel playerA_len]
    jge .eat_checks
    mov eax, [rel playerB_x]
    cmp eax, [r8 + r14*4]
    jne .n_hb
    mov eax, [rel playerB_y]
    cmp eax, [r9 + r14*4]
    je .b_dies_b
.n_hb:
    inc r14
    jmp .hb_loop

.eat_checks:
    cmp byte [rel playerA_alive], 0
    je .eat_b
    mov eax, [rel playerA_x]
    cmp eax, [rel apple_x]
    jne .eat_ca_a
    mov eax, [rel playerA_y]
    cmp eax, [rel apple_y]
    jne .eat_ca_a
    ; inc qword [rel playerA_score] (Commented)
    inc qword [rel playerA_len]
    call spawn_apple
    jmp .eat_b
.eat_ca_a:
    mov r14, 0
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
.eca_a:
    cmp r14, [rel num_corpse_apples]
    jge .eat_b
    mov eax, [rel playerA_x]
    cmp eax, [r8 + r14*4]
    jne .n_eca_a
    mov eax, [rel playerA_y]
    cmp eax, [r9 + r14*4]
    jne .n_eca_a
    ; inc qword [rel playerA_score] (Commented)
    inc qword [rel playerA_len]
    mov dword [r8 + r14*4], -1
    jmp .eat_b
.n_eca_a:
    inc r14
    jmp .eca_a

.eat_b:
    cmp byte [rel playerB_alive], 0
    je .ud
    mov eax, [rel playerB_x]
    cmp eax, [rel apple_x]
    jne .eat_ca_b
    mov eax, [rel playerB_y]
    cmp eax, [rel apple_y]
    jne .eat_ca_b
    ; inc qword [rel playerB_score] (Commented)
    inc qword [rel playerB_len]
    call spawn_apple
    jmp .ud
.eat_ca_b:
    mov r14, 0
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
.eca_b:
    cmp r14, [rel num_corpse_apples]
    jge .ud
    mov eax, [rel playerB_x]
    cmp eax, [r8 + r14*4]
    jne .n_eca_b
    mov eax, [rel playerB_y]
    cmp eax, [r9 + r14*4]
    jne .n_eca_b
    ; inc qword [rel playerB_score] (Commented)
    inc qword [rel playerB_len]
    mov dword [r8 + r14*4], -1
    jmp .ud
.n_eca_b:
    inc r14
    jmp .eca_b

.ud:
    add rsp, 40
    ret

a_die_logic:
    dec qword [rel playerA_lives]
    mov r14, 0
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
    mov r15, [rel num_corpse_apples]
    lea r11, [rel corpse_apples_x]
    lea r10, [rel corpse_apples_y]
.adl:
    cmp r14, [rel playerA_len]
    jge .adld
    cmp r15, 800
    jge .adld
    mov eax, [r8 + r14*4]
    mov [r11 + r15*4], eax
    mov eax, [r9 + r14*4]
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
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
    mov r15, [rel num_corpse_apples]
    lea r11, [rel corpse_apples_x]
    lea r10, [rel corpse_apples_y]
.bdl:
    cmp r14, [rel playerB_len]
    jge .bdld
    cmp r15, 800
    jge .bdld
    mov eax, [r8 + r14*4]
    mov [r11 + r15*4], eax
    mov eax, [r9 + r14*4]
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

render_game:
    sub rsp, 40
    lea rcx, [rel ansi_home]
    call printf
    lea rcx, [rel fmt_ui]
    mov rdx, [rel playerA_lives]
    mov r8, [rel playerB_lives]
    call printf
    
    mov r12, 0 ; Y
.ly:
    mov r13, 0 ; X
.lx:
    cmp r12, 0
    je .dw
    cmp r12, MAX_Y-1
    je .dw
    cmp r13, 0
    je .dw
    cmp r13, MAX_X-1
    je .dw

    ; Respawn A
    cmp byte [rel playerA_alive], 0
    jne .rend_a
    cmp qword [rel playerA_lives], 0
    jle .rend_a
    mov eax, [rel playerA_start_x]
    cmp r13d, eax
    jne .rend_a
    mov eax, [rel playerA_start_y]
    cmp r12d, eax
    jne .rend_a
    lea rcx, [rel ansi_cyan]
    call printf
    lea rcx, [rel fmt_respawn]
    mov rdx, [rel playerA_respawn_timer]
    add rdx, 9
    mov rax, rdx
    xor rdx, rdx
    mov rbx, 10
    div rbx
    mov rdx, rax
    call printf
    add r13, 2
    jmp .nx
.rend_a:
    cmp byte [rel playerA_alive], 0
    je .rend_b
    mov r14, 0
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
.la:
    cmp r14, [rel playerA_len]
    jge .rend_b
    cmp r13d, [r8 + r14*4]
    jne .na
    cmp r12d, [r9 + r14*4]
    jne .na
    lea rcx, [rel ansi_cyan]
    call printf
    lea rcx, [rel fmt_str]
    lea rdx, [rel char_snake_a]
    call printf
    jmp .nx
.na:
    inc r14
    jmp .la
.rend_b:
    ; Respawn B
    cmp byte [rel playerB_alive], 0
    jne .rend_b_snake
    cmp qword [rel playerB_lives], 0
    jle .rend_b_snake
    mov eax, [rel playerB_start_x]
    cmp r13d, eax
    jne .rend_b_snake
    mov eax, [rel playerB_start_y]
    cmp r12d, eax
    jne .rend_b_snake
    lea rcx, [rel ansi_magenta]
    call printf
    lea rcx, [rel fmt_respawn]
    mov rdx, [rel playerB_respawn_timer]
    add rdx, 9
    mov rax, rdx
    xor rdx, rdx
    mov rbx, 10
    div rbx
    mov rdx, rax
    call printf
    add r13, 2
    jmp .nx
.rend_b_snake:
    cmp byte [rel playerB_alive], 0
    je .rend_apple
    mov r14, 0
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
.lb:
    cmp r14, [rel playerB_len]
    jge .rend_apple
    cmp r13d, [r8 + r14*4]
    jne .nb
    cmp r12d, [r9 + r14*4]
    jne .nb
    lea rcx, [rel ansi_magenta]
    call printf
    lea rcx, [rel fmt_str]
    lea rdx, [rel char_snake_b]
    call printf
    jmp .nx
.nb:
    inc r14
    jmp .lb
.rend_apple:
    cmp r13d, [rel apple_x]
    jne .cca
    cmp r12d, [rel apple_y]
    jne .cca
    jmp .da
.cca:
    mov r14, 0
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
.rca_loop:
    cmp r14, [rel num_corpse_apples]
    jge .de
    cmp r13d, [r8 + r14*4]
    jne .next_rca
    cmp r12d, [r9 + r14*4]
    je .da
.next_rca:
    inc r14
    jmp .rca_loop
.da:
    lea rcx, [rel ansi_yellow]
    call printf
    lea rcx, [rel fmt_str]
    lea rdx, [rel char_apple]
    call printf
    jmp .nx
.dw:
    lea rcx, [rel ansi_white]
    call printf
    lea rcx, [rel fmt_str]
    lea rdx, [rel char_wall]
    call printf
    jmp .nx
.de:
    lea rcx, [rel fmt_str]
    lea rdx, [rel char_empty]
    call printf
.nx:
    lea rcx, [rel ansi_reset]
    call printf
    inc r13
    cmp r13, MAX_X
    jl .lx
    lea rcx, [rel newline]
    call printf
    inc r12
    cmp r12, MAX_Y
    jl .ly
    add rsp, 40
    ret
