;--- Subroutine for print 32-bit Decimal Number ---
; Input:  EAX = Number value
;         BL  = Template size, chars. 0=No template
;         RDI = Destination Pointer (flat)
; Output: RDI = Modified by string write = next position
;---
DecimalPrint32:
cld
push rax rbx rcx rdx
mov bh,80h-10
add bh,bl
mov ecx,1000000000
.MainCycle:
xor edx,edx
div ecx         ; Produce current digit
and al,0Fh
test bh,bh
js .FirstZero
cmp ecx,1
je .FirstZero
cmp al,0        ; Not actual left zero ?
jz .SkipZero
.FirstZero:
mov bh,80h      ; Flag = 1
or al,30h
stosb           ; Store char
.SkipZero:
push rdx
xor edx,edx
mov eax,ecx
mov ecx,10
div ecx
mov ecx,eax
pop rax
inc bh
test ecx,ecx
jnz .MainCycle
pop rdx rcx rbx rax
ret

;--- Bulld string for CPU clock frequency, 1 digit after decimal point ---
; Input:   RAX = Frequency, Hz
;          RDI = Pointer for build system information text strings
;          Use flat 64-bit addressing
; Output:  RDI = Modified if string build, otherwise preserved
;          RAX corrupted
;---
FrequencyPrint:
push rbx rdx 
mov rbx,1000000           ; Divisor for result unit = 1 MHz
xor edx,edx               ; RDX = 0, means dividend[127-64] = 0
div rbx                   ; RAX = Clock frequency in units = 1 MHz
cmp rax,100000            ; Validity limit = 100 GHz
jae .Error                ; Go if invalid frequency
mov bl,0                  ; BL = Template mode, 0 means no template
call DecimalPrint32       ; Print integer part X at X.Y MHz
mov al,'.'
stosb                     ; Print decimal point
xchg rax,rdx              ; RAX = Previous quotient
mov ebx,100000            ; Divisor for result unit = 0.1 MHz 
xor edx,edx               ; RDX = 0, means dividend[127-64] = 0
div rbx                   ; RAX = Clock freq. floating part in units = 0.1 MHz 
mov bl,0                  ; BL = Template mode, 0 means no template
call DecimalPrint32       ; Print floating part Y at X.Y MHz
;--- Exit points ---
jmp @f
.Error:
mov al,'?'
stosb
@@:
pop rdx rbx
ret

;--- Bulld string for clocks per instruction, 3 digits after decimal point ---
; Input:   RAX = Delta clock counter, units = clocks
;          RDX = Instructions counter, units = instruction
;          RDI = Pointer for build system information text strings
;          Use flat 64-bit addressing
; Output:  RDI = Modified if string build, otherwise preserved
;          RAX corrupted
;---
ClocksPrint:
push rbx rcx rdx rbp
test rdx,rdx
jz .Error
mov rcx,rax
mov rbp,rdx
xor edx,edx
div rbp         ; RDX:RAX = clocks , RBP = Instructions  
mov bl,0
call DecimalPrint32
mov al,'.'
stosb
imul rax,rdx,1000
xor edx,edx
div rbp         ; RDX:RAX = quotient clocks*1000 , RBP = Instructions
mov bl,3
call DecimalPrint32
;--- Exit points ---
jmp @f
.Error:
mov al,'?'
stosb
@@:
pop rbp rdx rcx rbx
ret

