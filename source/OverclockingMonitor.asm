;-----------------------------------------------------------------------------;
;                   Overclocking monitor information utility                  ;
;                    (C) IC Book Labs. v0.1 from 07.03.2018                   ;
;-----------------------------------------------------------------------------;

; Notes.
; TSC = Time Stamp Counter
; IA32_MPERF , maximum (non-turbo) performance , MSR # 000000E7h
; IA32_APERF , actual (turbo) performance , MSR # 000000E8h

format pe64 dll efi
entry main
section '.text' code executable readable
main:

;--- Save registers and UEFI application input parameters ---
push rbx rcx rdx rsi rdi rbp
push r8 r9 r10 r11 r12 r13 r14 r15
mov r15,VariablesPool
mov [r15+00],rcx                  ; Store UEFI application handle
mov [r15+08],rdx                  ; Store UEFI system table address
cld

;--- Detect Hardware Coordination Feedback Capability (HCFC) feature ---
xor eax,eax                       ; Select CPUID function 0
cpuid
cmp eax,6
jb ApplicationError1              ; Go error if CPUID function 6 not supported
mov eax,6                         ; Select CPUID function 6
cpuid
test cl,0001b
jz ApplicationError1              ; Go error if HCFC not detected 

;--- Measure clocks, check for measurement errors ---
; Return periods [femtoseconds]: R8=TSC , R9=IA32_MPERF , R10 = IA32_APERF
call ClocksMeasure
jc ApplicationError2              ; Go error if measurement failed

;--- Built ASCII strings for TSC, IA32_MPERF, IA32_APERF ---
mov rdi,AsciiBuffer  ; RDI = Pointer to destination buffer for built ASCII text
push rdi
mov rsi,StringFrequencies
;--- Built text for TSC ---
@@:                  ; Copy string before TSC frequency
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
xchg rax,r8          ; RAX = TSC period, femtoseconds, XCHG for compact code
call ClockPrint      ; Built ASCII string for TSC frequency
;--- Built text for IA32_MPERF ---
@@:                  ; Copy string before IA32_MPERF frequency
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
xchg rax,r9          ; RAX = IA32_MPERF period, femtoseconds
call ClockPrint      ; Built ASCII string for IA32_MPERF frequency
;--- Built text for IA32_APERF --- 
@@:                  ; Copy string before IA32_APERF frequency
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
xchg rax,r10         ; RAX = IA32_APERF period, femtoseconds
call ClockPrint      ; Built ASCII string for IA32_APERF frequency
;--- Close text block ---
mov al,0
stosb                ; Write terminator byte
pop rsi              ; Restore buffer address for visual it
call StringWrite

;--- Exit point if no errors ---
ExitProgram:
mov rsi,NameMsg
call StringWrite                  ; Write copyright string
jmp ApplicationExit

;--- Exit point if error --- 
ApplicationError1:                ; Message if HCFC not available 
mov rsi,ErrorMsg1
jmp ErrorWrite
ApplicationError2:                ; Message if measurement error 
mov rsi,ErrorMsg2
ErrorWrite:
call StringWrite

;--- Exit to UEFI with restore registers ---
ApplicationExit:
pop r15 r14 r13 r12 r11 r10 r9 r8
pop rbp rdi rsi rdx rcx rbx
xor rax,rax                       ; RAX=EFI_STATUS=0
ret                               ; Simple form of termination

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

;--- Bullt information string for CPU clock ---
; Input:   RAX = Period, femtoseconds
;          RDI = Pointer for built system information text strings
;          Use flat 64-bit addressing
; Output:  RDI = Modified if string built, otherwise preserved
;---
ClockPrint:
push rbx rdx 
imul rbx,rax,1000         ; RBX=Psec/clk
test rbx,rbx
jz @f                     ; Go if divide by zero
mov rax,1000000000000000	; Femtoseconds per Second
cqo                       ; D[127-64] = 0
div rbx                   ; RAX=Frequency, KHz
cqo
mov ebx,1000
div rbx                   ; EAX=Frequency, MHz
mov	bl,0                  ; BL=Template mode
call DecimalPrint32       ; Integer part
mov al,'.'
stosb
xchg rax,rdx
cqo
mov ebx,100               ; Quotient after /1000 make /100 = one digit.
div rbx
mov bl,0
call DecimalPrint32       ; Float part
pop rdx rbx
ret

;--- Measure CPU core clock frequencies -----------------------------
; Input:   None
; Output:  CF  = Flag: 0(NC)=Operation Passed, 1(C)=Operation Failed
;          Next parameters valid if CF=0 only
;          R8  = TSC period, femtoseconds
;          R9  = IA32_MPERF period, femtoseconds
;          R10 = IA32_APERF period, femtoseconds
;---
ClocksMeasure:
push rbx rcx rdx rsi rdi 
;--- Synchronization with current seconds change ---
call ReadRtcSeconds
mov bl,al
@@:
call ReadRtcSeconds
cmp bl,al
je @b
mov bl,al
;--- Get and initializing counters start values ---
mov ecx,000000E7h         ; Select IA32_MPERF MSR
xor eax,eax               ; EAX = 0
cdq                       ; EDX = 0
wrmsr                     ; IA32_MPERF MSR = 0
inc ecx                   ; Select IA32_APERF MSR , index ECX = 000000E8h
wrmsr                     ; IA32_APERF MSR = 0
dec ecx
rdtsc
mov esi,eax               ; ESI = Current TSC , low 32
mov edi,edx               ; EDI = Current TSC , high 32
;--- Measurement, wait 1 full second ---
@@:
call ReadRtcSeconds
cmp bl,al                 ; BL = Previous seconds, AL = Old seconds 
je @b
;--- Get counters end values ---
rdmsr                     ; Read IA32_MPERF MSR , index ECX = 000000E7h
shl rdx,32
lea r9,[rax+rdx]          ; R9 = Delta IA32_MPERF , 64-bit
inc ecx                   ; Select IA32_APERF MSR , index ECX = 000000E8h
rdmsr                     ; Read IA32_APERF MSR , index ECX = 000000E8h
shl rdx,32
lea r10,[rax+rdx]         ; R10 = Delta IA32_APERF , 64-bit
rdtsc
sub eax,esi
sbb edx,edi
shl rdx,32
lea rsi,[rax+rdx]         ; RSI = Delta TSC, 64-bit , here RAX [127-64]=0
;--- Calculation with measurement result for TSC ---		
mov rbx,1000000000000000  ; Femtoseconds per Second
mov rax,rbx
cqo                       ; Dividend D[127-64] = 0
test rsi,rsi
stc                       ; CF=1(C) means error
jz @f                     ; Go error if divisor = 0
div rsi                   ; RAX = Femtoseconds per TSC
xchg r8,rax               ; R8 = Femtoseconds per TSC , XCHG for compact code 
;--- Calculation with measurement result for IA32_MPERF ---
mov rax,rbx               ; Femtoseconds per Second
cqo                       ; Dividend D[127-64] = 0
test r9,r9
stc                       ; CF=1(C) means error
jz @f                     ; Go error if divisor = 0
div r9                    ; RAX = Femtoseconds per TSC
xchg r9,rax               ; R9 = Femtoseconds per IA32_MPERF 
;--- Calculation with measurement result for IA32_APERF ---
xchg rax,rbx              ; Femtoseconds per Second
cqo                       ; Dividend D[127-64] = 0
test r10,r10
stc                       ; CF=1(C) means error
jz @f                     ; Go error if divisor = 0
div r10                   ; RAX = Femtoseconds per TSC
xchg r10,rax              ; R10 = Femtoseconds per IA32_APERF 
;--- Exit points ---
clc                       ; CF=0(NC) means no errors
@@:
pop rdi rsi rdx rcx rbx
ret

;--- Subroutine for read seconds from RTC, wait for UIP=0 ---
; UIP=Update In Progress flag, it must be 0 for valid read time
; Input:   None
; Output:  AL = RTC seconds counter
;---
ReadRtcSeconds:
cli
;--- Wait for UIP=0 ---
@@:
mov	al,0Ah          ; Index=0Ah, control/status reg. 0Ah
out 70h,al
in al,71h           ; Read register 0Ah
test al,80h         ; Index=0Ah, Bit=7, UIP bit
jnz @b
;--- Read seconds ---
mov al,00h          ; Index=00h, seconds register
out 70h,al
in al,71h           ; Read seconds register
;--- Exit ---
sti
ret

;--- Data ---
section '.data' data readable writeable

NameMsg:
DB  0Dh,0Ah
DB  'Overclocking monitor. (C)IC Book Labs 07.03.2018.'
DB  0Dh,0Ah,0 
ErrorMsg1:
DB  0Dh,0Ah
DB  'Hardware coordination feedback capability not detected.'
DB  0Dh,0Ah,0
ErrorMsg2:
DB  0Dh,0Ah
DB  'Clock measurement error.',0
DB  0Dh,0Ah,0
StringFrequencies:
DB  0Dh,0Ah
DB  'CPU frequencies [MHz]:'
DB  0Dh,0Ah
DB  'TSC        = ' , 0
DB  0Dh,0Ah
DB  'IA32_MPERF = ' , 0
DB  0Dh,0Ah
DB  'IA32_APERF = ' , 0

;--- This structures don't reserve space in the file, because "?" ---
VariablesPool:
EfiHandle      DQ  ?              ; UEFI firmware parameter - Application Handle
EfiTable       DQ  ?              ; UEFI firmware parameter - Sys.Table
AsciiBuffer    DB  2048 DUP (?)   ; ASCII buffer
UnicodeBuffer  DB  4096 DUP (?)   ; UNICODE buffer, for Text Output Protocol

;--- Relocation elements ---
section '.reloc' fixups data discardable

;--- End ---

