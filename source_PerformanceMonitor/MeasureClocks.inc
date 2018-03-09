;--- Measure CPU core clock frequencies -----------------------------
; Input:   None
; Output:  CF  = Flag: 0(NC)=Operation Passed, 1(C)=Operation Failed
;          Next parameters valid if CF=0 only
;          R8  = TSC clock frequency, Hz 
;          R9  = IA32_MPERF clock frequency, Hz 
;          R10 = IA32_APERF clock frequency, Hz 
;---
FrequenciesMeasure:
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
mov ecx,000000E7h     ; Select IA32_MPERF MSR
xor eax,eax           ; EAX = 0
cdq                   ; EDX = 0
wrmsr                 ; IA32_MPERF MSR = 0
inc ecx               ; Select IA32_APERF MSR , index ECX = 000000E8h
wrmsr                 ; IA32_APERF MSR = 0
dec ecx
rdtsc
mov esi,eax           ; ESI = Current TSC , low 32
mov edi,edx           ; EDI = Current TSC , high 32
;--- Measurement, wait 1 full second ---
@@:
call ReadRtcSeconds
cmp bl,al             ; BL = Previous seconds, AL = Old seconds 
je @b
;--- Get counters end values ---
rdmsr                 ; Read IA32_MPERF MSR , index ECX = 000000E7h
shl rdx,32
lea r9,[rax+rdx]      ; R9 = Delta IA32_MPERF , 64-bit
inc ecx               ; Select IA32_APERF MSR , index ECX = 000000E8h
rdmsr                 ; Read IA32_APERF MSR , index ECX = 000000E8h
shl rdx,32
lea r10,[rax+rdx]     ; R10 = Delta IA32_APERF , 64-bit
rdtsc
sub eax,esi
sbb edx,edi
shl rdx,32
lea r8,[rax+rdx]      ; R8 = Delta TSC, 64-bit , here RAX [63-32]=0
;--- Check results validity ---
test r8,r8            ; Check TSC frequency
jz .Error             ; Go error if result frequency = 0   
js .Error             ; Go error if frequency value bit 63 set "1"
test r9,r9            ; Check IA32_MPERF frequency
jz .Error
js .Error
test r10,r10          ; Check IA32_APERF frequency
jz .Error
js .Error
;--- Exit points ---
clc                   ; CF=0(NC) means no errors
jmp @f
.Error:
stc                   ; CF=1(C) means error
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
mov al,0Ah          ; Index=0Ah, control/status reg. 0Ah
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

