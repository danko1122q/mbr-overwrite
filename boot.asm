; boot.asm - MBR Bootloader (512 bytes)
; Loads Stage 2 from disk and transfers control
[BITS 16]
[ORG 0x7C00]

start:
    ; Clear interrupts and setup segments
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack grows downward from bootloader
    sti
    
    mov [BOOT_DRIVE], dl ; Save boot drive number from BIOS

    ; Clear screen
    mov ax, 0x0003
    int 0x10

    ; Display loading message
    mov si, load_msg
    call print

    ; Load Stage 2 to 0x1000:0x0000 (physical address 0x10000)
    mov ax, 0x1000
    mov es, ax
    xor bx, bx          ; ES:BX = 0x1000:0x0000

    mov dl, [BOOT_DRIVE] ; Drive number
    mov ah, 0x02        ; Read sectors function
    mov al, 10          ; Number of sectors to read (5KB for stage2)
    mov ch, 0           ; Cylinder 0
    mov dh, 0           ; Head 0
    mov cl, 2           ; Start from sector 2 (sector 1 is MBR)
    int 0x13
    jc disk_error       ; Jump if carry flag set (error)

    ; Verify read
    cmp al, 10
    jne disk_error

    ; Display success message
    mov si, success_msg
    call print

    ; Transfer control to Stage 2
    jmp 0x1000:0x0000

disk_error:
    mov si, err_msg
    call print
    
    ; Wait for keypress before halting
    mov ah, 0x00
    int 0x16
    
    cli
    hlt
    jmp $

; Print string function using BIOS teletype
; Input: SI = pointer to null-terminated string
print:
    pusha
    mov ah, 0x0E        ; BIOS teletype function
    mov bh, 0x00        ; Page 0
    mov bl, 0x07        ; Light gray color
.loop:
    lodsb               ; Load byte at DS:SI into AL, increment SI
    test al, al         ; Check for null terminator
    jz .done
    int 0x10            ; Print character
    jmp .loop
.done:
    popa
    ret

; Data section
load_msg:     db 'Loading Stage 2...', 13, 10, 0
success_msg:  db 'Success! Jumping to Stage 2...', 13, 10, 0
err_msg:      db 'DISK READ ERROR! Press any key...', 13, 10, 0
BOOT_DRIVE:   db 0

; Boot signature padding
times 510-($-$$) db 0
dw 0xAA55               ; Boot signature
