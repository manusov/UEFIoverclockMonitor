;--- Subroutine for print ASCII string ---
; Input:  R15 = Global variables pool base address
;         RSI = Source string address
; Output: None
;---
StringWrite:
push rax rcx rdx rdi rbp r8 r9 r10 r11
;--- Convert string from ASCII (8-bit) to UNICODE (16-bit) ---
mov rdi,UnicodeBuffer
mov rdx,rdi                       ; RDX used for next step
mov ah,0
@@:
lodsb                             ; Read 8-bit char
stosw                             ; Write 16-bit char, high byte = 0
cmp al,0                          ; Last 16-bit word must write 0000h
jne @b                            ; Cycle for string 
;--- Output UNICODE string, RDX=String address --- 
mov rbp,rsp                       ; Save RSP
mov rcx,[r15+008h]                ; RCX = EFI_SYSTEM_TABLE address
mov rcx,[rcx+040h]                ; RCX = EFI_SYSTEM_TABLE.ConOut
and rsp,0FFFFFFFFFFFFFFF0h        ; This for stack alignment
sub rsp,32                        ; This for 4 parameters shadow
call qword [rcx+008h]             ; +08h for select function, RDX = String
mov rsp,rbp                       ; Restore RSP
;--- Exit ---
pop r11 r10 r9 r8 rbp rdi rdx rcx rax
ret

