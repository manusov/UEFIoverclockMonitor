;-----------------------------------------------------------------------------;
;           Overclocking and performance monitor information utility          ;
;                              (C) IC Book Labs.                              ;
;-----------------------------------------------------------------------------;

; Notes.
; TSC = Time Stamp Counter
; IA32_MPERF , maximum (non-turbo) performance , MSR # 000000E7h
; IA32_APERF , actual (turbo) performance , MSR # 000000E8h

;========== CODE SECTION ======================================================;

format pe64 dll efi
entry main
section '.text' code executable readable
main:

;--- Save registers and UEFI application input parameters ---
push rbx rcx rdx rsi rdi rbp
push r8 r9 r10 r11 r12 r13 r14 r15
mov r15,VariablesPool
mov [r15+00],rcx            ; Store UEFI application handle
mov [r15+08],rdx            ; Store UEFI system table address
mov byte [r15+32],0         ; Context restore requests = 0
cld
;--- Detect CPUID support, this check can be actual at virtual machines ---
mov ebx,21                  ; Bit number for toggleable check
pushf                       ; In the 64-bit mode, push RFLAGS
pop rax
bts eax,ebx                 ; Set EAX.21=1
push rax
popf                        ; Load RFLAGS with RFLAGS.21=1
pushf                       ; Store RFLAGS
pop rax                     ; Load RFLAGS to RAX
btr eax,ebx                 ; Check EAX.21=1, Set EAX.21=0
jnc ApplicationErrorCPUID   ; Go error branch if cannot set EFLAGS.21=1
push rax
popf                        ; Load RFLAGS with RFLAGS.21=0
pushf                       ; Store RFLAGS
pop rax                     ; Load RFLAGS to RAX
btr eax,ebx                 ; Check EAX.21=0
jc ApplicationErrorCPUID    ; Go if cannot set EFLAGS.21=0
;--- Detect Hardware Coordination Feedback Capability (HCFC) feature ---
xor eax,eax                ; Select CPUID function 0
cpuid                   
cmp eax,6
jb ApplicationErrorHCFC    ; Go error if CPUID function 6 not supported
mov eax,6                  ; Select CPUID function 6
cpuid
test cl,0001b
jz ApplicationErrorHCFC    ; Go error if HCFC not detected 
;--- Detect Advanced Vector Extension (AVX) feature and context management ---
mov eax,1                  ; Select CPUID function 1
cpuid
and ecx,010000000h         ; This mask for bits 28
jz  ApplicationErrorAVX    ; Go if AVX(ECX.28) not supported
;--- Support CR4 ---
mov rax,cr4
test ah,02h
jz  ApplicationErrorSSECN  ; Go if OSFXSR(CR4.9) not set by UEFI
mov [r15+16],rax
or eax,00040400h           ; CR4.18 , CR4.10
mov cr4,rax
or byte [r15+32],0001b     ; Set bit D0 = context restore request for CR4
;--- Detect Advanced Vector Extension (AVX) feature and context management ---
mov eax,1                  ; Select CPUID function 1
cpuid
mov eax,018000000h         ; This mask for bits 27, 28
and ecx,eax                ; ECX = Part of features bitmaps
cmp ecx,eax
jne ApplicationErrorAVX    ; Go if OSXSAVE(ECX.27) or AVX(ECX.28) not supported
;--- Set AVX context management option in the XCR0 ---
xor ecx,ecx                ; ECX = XCR register index
xgetbv                     ; Read from XCR0 to EDX:EAX
mov [r15+24],eax
mov [r15+28],edx
or al,00000110b
xor ecx,ecx
xsetbv                     ; Write to XCR0 from EDX:EAX
or byte [r15+32],0010b     ; Set bit D1 = context restore request for XCR0

;--- Measure clocks, check for measurement errors ---
; Return periods [femtoseconds]: R8=TSC , R9=IA32_MPERF , R10 = IA32_APERF
call FrequenciesMeasure
jc ApplicationErrorCLK    ; Go error if measurement failed
;--- Build ASCII strings for TSC, IA32_MPERF, IA32_APERF ---
; Note. Don't use LEA REG,[LABEL] in the UEFI, because PE64 relocation bug
mov rdi,AsciiBuffer  ; RDI = Pointer to destination buffer for build ASCII text
push rdi
mov rsi,StringFrequencies
;--- Build text for TSC ---
@@:                  ; Copy string before TSC frequency
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
xchg rax,r8          ; RAX = TSC period, femtoseconds, XCHG for compact code
call FrequencyPrint  ; Build ASCII string for TSC frequency
;--- Build text for IA32_MPERF ---
@@:                  ; Copy string before IA32_MPERF frequency
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
xchg rax,r9          ; RAX = IA32_MPERF period, femtoseconds
call FrequencyPrint  ; Build ASCII string for IA32_MPERF frequency
;--- Build text for IA32_APERF --- 
@@:                  ; Copy string before IA32_APERF frequency
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
xchg rax,r10         ; RAX = IA32_APERF period, femtoseconds
call FrequencyPrint  ; Build ASCII string for IA32_APERF frequency
;--- Close text block ---
mov al,0
stosb                ; Write terminator byte
pop rsi              ; Restore buffer address for visual it
call StringWrite

;--- Instruction performance measurement ---
; Note. Don't use LEA REG,[LABEL] in the UEFI, because PE64 relocation bug
;--- Build table up ---
mov rdi,AsciiBuffer       ; RDI = Pointer to destination buf., build ASCII text
push rdi
mov rsi,StringInstructions
@@:                  ; Copy string before IA32_APERF frequency
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
mov al,0
stosb                ; Write terminator byte
pop rsi              ; Restore buffer address for visual it
call StringWrite
;--- Clear and pre-cache buffer for performance patterns ---
mov rdi,DataBuffer
mov rsi,rdi
mov ecx,16384
mov al,0
rep stosb                 ; Pre-blank data buffer
mov ecx,16384
rep lodsb                 ; This for pre-cache even without write allocation
;--- Start build table with measurements ---
;--- Start control sequence for run performance patterns ---
mov rbx,ControlSequence   ; RBX = Pointer to sequence of operations names
OperationSequence:
mov rdi,AsciiBuffer       ; RDI = Pointer to destination buf., build ASCII text
;--- Clear text string ---
push rdi
mov ecx,80
mov al,' '
rep stosb
pop rdi
;--- Copy instruction set name ---
push rdi
mov rbp,rdi
mov rsi,rbx
@@:
lodsb
cmp al,0
je @f
stosb
jmp @b
@@:
mov rbx,rsi
;--- Call target performance pattern ---
push rbx rbp
call qword [rbx]
pop rbp rbx 
add rbx,8
;--- Print results ---
lea rdi,[rbp+2+26]        ; +2 because 0Dh,0Ah
mov rax,r8
mov rdx,r11
call ClocksPrint          ; Print TSC clocks 
lea rdi,[rbp+2+26+12]
mov rax,r9
mov rdx,r11
call ClocksPrint          ; Print IA32_MPERF clocks 
lea rdi,[rbp+2+26+12+12]
mov rax,r10
mov rdx,r11
call ClocksPrint          ; Print IA32_APERF clocks 
;--- Close text block ---
mov al,0
stosb                     ; Write terminator byte
pop rsi                   ; Restore buffer address for visual it
call StringWrite
cmp byte [rbx],0
jne OperationSequence

;--- Exit point if no errors ---
mov rsi,NameMsg
call StringWrite     ; Write copyright string
jmp ApplicationExit

;--- Exit points if errors detected --- 
ApplicationErrorCPUID:   ; Message if HCFC not available 
mov rsi,ErrorMsgCPUID
jmp ErrorWrite
ApplicationErrorHCFC:    ; Message if HCFC not available 
mov rsi,ErrorMsgHCFC
jmp ErrorWrite
ApplicationErrorAVX:     ; Message if AVX not available 
mov rsi,ErrorMsgAVX
jmp ErrorWrite
ApplicationErrorSSECN:   ; Message if SSE context not initialized by UEFI
mov rsi,ErrorMsgSSECN
jmp ErrorWrite
ApplicationErrorCLK:     ; Message if measurement error 
mov rsi,ErrorMsgCLK
ErrorWrite:
call StringWrite

;--- Application exit point ---
ApplicationExit:

;--- Restore system context ---
test byte [r15+32],0010b   ; Test bit D1 = context restore request for XCR0
jz @f                      ; Skip if XCR0 unchanged
mov eax,[r15+24]
mov edx,[r15+28]
xor ecx,ecx
xsetbv
@@:
test byte [r15+32],0001b   ; Test bit D0 = context restore request for CR4
jz @f                      ; Skip if CR4 unchanged
mov rax,[r15+16]
mov cr4,rax
@@:

;--- Exit to UEFI (Shell) with restore registers ---
pop r15 r14 r13 r12 r11 r10 r9 r8
pop rbp rdi rsi rdx rcx rbx
xor rax,rax                       ; RAX = EFI_STATUS = 0
ret                               ; Simple form of termination

;--- Connect INCLUDE modules --
include 'StringWrite.inc'       ; Console output
include 'StringBuild.inc'       ; Build strings in the text buffer
include 'MeasureClocks.inc'     ; Measure CPU counters clocks
include 'PatternRead128.inc'    ; Performance patterns
include 'PatternWrite128.inc'
include 'PatternCopy128.inc'
include 'PatternRead256.inc'
include 'PatternWrite256.inc'
include 'PatternCopy256.inc'

;========== DATA SECTION ======================================================;

section '.data' data readable writeable
;--- Text messages, used at Overclocking Monitor ---
NameMsg:
DB  0Dh,0Ah,0Dh,0Ah
DB  'Overclocking and performance monitor v0.4. (C)2018 IC Book Labs.'
DB  0Dh,0Ah,0 
ErrorMsgCPUID:
DB  0Dh,0Ah
DB  'CPUID not supported or locked.'
DB  0Dh,0Ah,0
ErrorMsgHCFC:
DB  0Dh,0Ah
DB  'Hardware coordination feedback capability not detected.'
DB  0Dh,0Ah,0
ErrorMsgAVX:
DB  0Dh,0Ah
DB  'AVX not supported or locked.'
DB  0Dh,0Ah,0
ErrorMsgSSECN:
DB  0Dh,0Ah
DB  'SSE context management not initialized by UEFI.'
DB  0Dh,0Ah,0
ErrorMsgCLK:
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
;--- Text messages, added at Performance Monitor ---
StringInstructions:
DB  0Dh,0Ah,0Dh,0Ah
DB  'Clocks per instructions.'
DB  0Dh,0Ah
DB  'Instruction               TSC         IA32_MPERF  IA32_APERF'
DB  0Dh,0Ah,0

;--- Control sequence for run performance patterns ---
ControlSequence:
DB  0Dh,0Ah 
DB  'Read-128,  VMOVAPD'
DB  0
DQ  Performance_Read_128
DB  0Dh,0Ah
DB  'Write-128, VMOVAPD'
DB  0
DQ  Performance_Write_128
DB  0Dh,0Ah
DB  'Copy-128,  VMOVAPD'
DB  0
DQ  Performance_Copy_128
DB  0Dh,0Ah 
DB  'Read-256,  VMOVAPD'
DB  0
DQ  Performance_Read_256
DB  0Dh,0Ah
DB  'Write-256, VMOVAPD'
DB  0
DQ  Performance_Write_256
DB  0Dh,0Ah
DB  'Copy-256,  VMOVAPD'
DB  0
DQ  Performance_Copy_256
DB  0

;--- This structures don't reserve space in the file, because "?" ---
VariablesPool:
EfiHandle      DQ  ?              ; UEFI firmware parameter - Application Handle
EfiTable       DQ  ?              ; UEFI firmware parameter - Sys.Table
SaveCR4        DQ  ?              ; Storage for Control Register 4 
SaveXCR0       DQ  ?              ; Storage for Extended Control Register 0
FlagsCR        DB  ?              ; D0 = CR4 restore, D1 = XCR0 restore  
;--- Buffers for text output --- 
AsciiBuffer    DB  2048 DUP (?)   ; ASCII buffer
UnicodeBuffer  DB  4096 DUP (?)   ; UNICODE buffer, for Text Output Protocol
;--- Buffers for performance patterns ---
align 32
DataBuffer     DB  16384 DUP (?)  ; Buffer for instructions performance tests

;========== RELOCATION SECTION ================================================;

section '.reloc' fixups data discardable



