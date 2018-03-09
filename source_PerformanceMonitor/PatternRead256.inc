;--- Performance pattern, AVX Read 256-bit ---
; INPUT:   None
; OUTPUT:  R8  = Delta TSC, clocks
;          R9  = Delta IA32_MPERF, clocks
;          R10 = Delta IA32_APERF, clocks 
;          R11 = Total target instructions (or r-w groups) executed
;---

Performance_Read_256:
;--- Get counters start values ---
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
;--- Target performance pattern ---
mov r11,50000000*16384/32
mov eax,50000000
.L1:
mov rbx,DataBuffer
mov rcx,16384/16/32
mov edx,16*32 
.L0:
vmovapd ymm0, [rbx+32*00]
vmovapd ymm1, [rbx+32*01]
vmovapd ymm2, [rbx+32*02]
vmovapd ymm3, [rbx+32*03]
vmovapd ymm4, [rbx+32*04]
vmovapd ymm5, [rbx+32*05]
vmovapd ymm6, [rbx+32*06]
vmovapd ymm7, [rbx+32*07]
vmovapd ymm8, [rbx+32*08]
vmovapd ymm9, [rbx+32*09]
vmovapd ymm10,[rbx+32*10]
vmovapd ymm11,[rbx+32*11]
vmovapd ymm12,[rbx+32*12]
vmovapd ymm13,[rbx+32*13]
vmovapd ymm14,[rbx+32*14]
vmovapd ymm15,[rbx+32*15]
add rbx,rdx
dec ecx
jnz .L0
dec eax
jnz .L1
;--- Get counters end values ---
mov ecx,000000E7h     ; Select IA32_MPERF MSR
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
;--- Exit ---
ret

