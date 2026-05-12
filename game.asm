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

    fmt_score     db "Player A (WASD): %d  |  Player B (Arrows): %d   ", 10, 0
    fmt_str       db "%s", 0
    newline       db 10, 0

    msg_a_win     db 10, "GAME OVER: Player A wins! (Score: %d vs %d)", 10, 0
    msg_b_win     db 10, "GAME OVER: Player B wins! (Score: %d vs %d)", 10, 0
    msg_draw      db 10, "GAME OVER: It's a DRAW! (Score: %d)", 10, 0

    ; Corpse Logic
    num_corpse_apples dq 0
    corpse_apples_x times 800 dd -1
    corpse_apples_y times 800 dd -1

    ; Player A
    playerA_x     times 200 dd 0
    playerA_y     times 200 dd 0
    playerA_len   dq 3
    playerA_dir   dd 3 ; 0:Up, 1:Down, 2:Left, 3:Right
    playerA_score dq 0
    playerA_alive db 1

    ; Player B
    playerB_x     times 200 dd 0
    playerB_y     times 200 dd 0
    playerB_len   dq 3
    playerB_dir   dd 2
    playerB_score dq 0
    playerB_alive db 1

    ; Apple
    apple_x       dd 15
    apple_y       dd 10

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

    ; Initialize srand
    xor rcx, rcx
    call time
    mov rcx, rax
    call srand

    ; Initial positions
    mov dword [rel playerA_x], 10
    mov dword [rel playerA_y], 10
    mov dword [rel playerA_x+4], 9
    mov dword [rel playerA_y+4], 10
    mov dword [rel playerA_x+8], 8
    mov dword [rel playerA_y+8], 10

    mov dword [rel playerB_x], 30
    mov dword [rel playerB_y], 10
    mov dword [rel playerB_x+4], 31
    mov dword [rel playerB_y+4], 10
    mov dword [rel playerB_x+8], 32
    mov dword [rel playerB_y+8], 10

    ; Hide cursor
    lea rcx, [rel ansi_hide]
    call printf

game_loop:
    call handle_input
    call update_game
    call render_game
    
    mov rcx, 100
    call Sleep

    mov rcx, VK_Q
    call GetAsyncKeyState
    test ax, ax
    jnz exit_game

    mov al, [rel playerA_alive]
    or al, [rel playerB_alive]
    jnz game_loop

exit_game:
    lea rcx, [rel ansi_show]
    call printf
    
    lea rcx, [rel newline]
    call printf

    mov rax, [rel playerA_score]
    mov rbx, [rel playerB_score]
    cmp rax, rbx
    jg .a_wins
    jl .b_wins
    
    lea rcx, [rel msg_draw]
    mov rdx, rax
    call printf
    jmp .exit_done

.a_wins:
    lea rcx, [rel msg_a_win]
    mov rdx, rax
    mov r8, rbx
    call printf
    jmp .exit_done

.b_wins:
    lea rcx, [rel msg_b_win]
    mov rdx, rbx
    mov r8, rax
    call printf

.exit_done:
    lea rcx, [rel cmd_pause]
    call system
    add rsp, 40
    ret

handle_input:
    sub rsp, 40
    ; Player A
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
    ; Player B
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
    
    ; Update Player A
    cmp byte [rel playerA_alive], 0
    je .update_b
    
    ; Shift body A
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
    ; Move head A
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
.a_up:    dec dword [rel playerA_y]
          jmp .a_wrap
.a_down:  inc dword [rel playerA_y]
          jmp .a_wrap
.a_left:  dec dword [rel playerA_x]
          jmp .a_wrap
.a_right: inc dword [rel playerA_x]
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
    jmp .a_wrap_done
.a_w_b:
    cmp eax, MAX_Y_M1
    jl .a_wrap_done
    mov dword [rel playerA_y], 1
.a_wrap_done:

    ; Check self collision A
    mov r14, 1
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
.self_a_loop:
    cmp r14, [rel playerA_len]
    jge .check_b_coll_a
    mov eax, [r8]
    cmp eax, [r8 + r14*4]
    jne .next_sa
    mov eax, [r9]
    cmp eax, [r9 + r14*4]
    je .a_die
.next_sa:
    inc r14
    jmp .self_a_loop

.check_b_coll_a:
    cmp byte [rel playerB_alive], 0
    je .check_apple_a
    mov r14, 0
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
.ha_loop:
    cmp r14, [rel playerB_len]
    jge .check_apple_a
    mov eax, [rel playerA_x]
    cmp eax, [r8 + r14*4]
    jne .next_ha
    mov eax, [rel playerA_y]
    cmp eax, [r9 + r14*4]
    je .a_die
.next_ha:
    inc r14
    jmp .ha_loop

.a_die:
    mov r14, 0
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
    mov r15, [rel num_corpse_apples]
    lea r11, [rel corpse_apples_x]
    lea r10, [rel corpse_apples_y]
.ad_loop:
    cmp r14, [rel playerA_len]
    jge .ad_done
    cmp r15, 800
    jge .ad_done
    mov eax, [r8 + r14*4]
    mov [r11 + r15*4], eax
    mov eax, [r9 + r14*4]
    mov [r10 + r15*4], eax
    inc r14
    inc r15
    jmp .ad_loop
.ad_done:
    mov [rel num_corpse_apples], r15
    mov byte [rel playerA_alive], 0
    jmp .update_b

.check_apple_a:
    mov eax, [rel playerA_x]
    cmp eax, [rel apple_x]
    jne .check_ca_a
    mov eax, [rel playerA_y]
    cmp eax, [rel apple_y]
    jne .check_ca_a
    inc qword [rel playerA_score]
    inc qword [rel playerA_len]
    call spawn_apple
    jmp .update_b
.check_ca_a:
    mov r14, 0
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
.eca_a_loop:
    cmp r14, [rel num_corpse_apples]
    jge .update_b
    mov eax, [rel playerA_x]
    cmp eax, [r8 + r14*4]
    jne .next_eca_a
    mov eax, [rel playerA_y]
    cmp eax, [r9 + r14*4]
    jne .next_eca_a
    inc qword [rel playerA_score]
    inc qword [rel playerA_len]
    mov dword [r8 + r14*4], -1
    mov dword [r9 + r14*4], -1
    jmp .update_b
.next_eca_a:
    inc r14
    jmp .eca_a_loop

.update_b:
    cmp byte [rel playerB_alive], 0
    je .update_done
    
    ; Shift body B
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
    ; Move head B
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
.b_up:    dec dword [rel playerB_y]
          jmp .b_wrap
.b_down:  inc dword [rel playerB_y]
          jmp .b_wrap
.b_left:  dec dword [rel playerB_x]
          jmp .b_wrap
.b_right: inc dword [rel playerB_x]
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
    jmp .b_wrap_done
.b_w_b:
    cmp eax, MAX_Y_M1
    jl .b_wrap_done
    mov dword [rel playerB_y], 1
.b_wrap_done:

    ; Check self collision B
    mov r14, 1
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
.self_b_loop:
    cmp r14, [rel playerB_len]
    jge .check_a_coll_b
    mov eax, [r8]
    cmp eax, [r8 + r14*4]
    jne .next_sb
    mov eax, [r9]
    cmp eax, [r9 + r14*4]
    je .b_die
.next_sb:
    inc r14
    jmp .self_b_loop

.check_a_coll_b:
    cmp byte [rel playerA_alive], 0
    je .check_apple_b
    mov r14, 0
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
.hb_loop:
    cmp r14, [rel playerA_len]
    jge .check_apple_b
    mov eax, [rel playerB_x]
    cmp eax, [r8 + r14*4]
    jne .next_hb
    mov eax, [rel playerB_y]
    cmp eax, [r9 + r14*4]
    je .b_die
.next_hb:
    inc r14
    jmp .hb_loop

.b_die:
    mov r14, 0
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
    mov r15, [rel num_corpse_apples]
    lea r11, [rel corpse_apples_x]
    lea r10, [rel corpse_apples_y]
.bd_loop:
    cmp r14, [rel playerB_len]
    jge .bd_done
    cmp r15, 800
    jge .bd_done
    mov eax, [r8 + r14*4]
    mov [r11 + r15*4], eax
    mov eax, [r9 + r14*4]
    mov [r10 + r15*4], eax
    inc r14
    inc r15
    jmp .bd_loop
.bd_done:
    mov [rel num_corpse_apples], r15
    mov byte [rel playerB_alive], 0
    jmp .update_done

.check_apple_b:
    mov eax, [rel playerB_x]
    cmp eax, [rel apple_x]
    jne .check_ca_b
    mov eax, [rel playerB_y]
    cmp eax, [rel apple_y]
    jne .check_ca_b
    inc qword [rel playerB_score]
    inc qword [rel playerB_len]
    call spawn_apple
    jmp .update_done
.check_ca_b:
    mov r14, 0
    lea r8, [rel corpse_apples_x]
    lea r9, [rel corpse_apples_y]
.eca_b_loop:
    cmp r14, [rel num_corpse_apples]
    jge .update_done
    mov eax, [rel playerB_x]
    cmp eax, [r8 + r14*4]
    jne .next_eca_b
    mov eax, [rel playerB_y]
    cmp eax, [r9 + r14*4]
    jne .next_eca_b
    inc qword [rel playerB_score]
    inc qword [rel playerB_len]
    mov dword [r8 + r14*4], -1
    mov dword [r9 + r14*4], -1
    jmp .update_done
.next_eca_b:
    inc r14
    jmp .eca_b_loop

.update_done:
    add rsp, 40
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
    lea rcx, [rel fmt_score]
    mov rdx, [rel playerA_score]
    mov r8, [rel playerB_score]
    call printf
    
    mov r12, 0 ; Y
.ly:
    mov r13, 0 ; X
.lx:
    ; Wall
    cmp r12, 0
    je .dw
    cmp r12, MAX_Y-1
    je .dw
    cmp r13, 0
    je .dw
    cmp r13, MAX_X-1
    je .dw

    ; Player A
    cmp byte [rel playerA_alive], 0
    je .cb
    mov r14, 0
    lea r8, [rel playerA_x]
    lea r9, [rel playerA_y]
.la:
    cmp r14, [rel playerA_len]
    jge .cb
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

.cb:
    ; Player B
    cmp byte [rel playerB_alive], 0
    je .ca
    mov r14, 0
    lea r8, [rel playerB_x]
    lea r9, [rel playerB_y]
.lb:
    cmp r14, [rel playerB_len]
    jge .ca
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

.ca:
    ; Normal Apple
    cmp r13d, [rel apple_x]
    jne .cca
    cmp r12d, [rel apple_y]
    jne .cca
    jmp .da
.cca:
    ; Corpse Apples
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
