;--- Performance pattern, AVX Copy 256-bit ---
; INPUT:   None
; OUTPUT:  R8  = Delta TSC, clocks
;          R9  = Delta IA32_MPERF, clocks
;          R10 = Delta IA32_APERF, clocks 
;          R11 = Total target instructions (or r-w groups) executed
;---

Performance_Copy_256:
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
mov r11,50000000*16384/32/2
mov eax,50000000
.L1:
mov rbx,DataBuffer
lea rdx,[rbx+16384/2]
mov rcx,16384/16/32/2
mov ebp,16*32 
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
vmovapd [rdx+32*00],ymm0
vmovapd [rdx+32*01],ymm1
vmovapd [rdx+32*02],ymm2
vmovapd [rdx+32*03],ymm3
vmovapd [rdx+32*04],ymm4
vmovapd [rdx+32*05],ymm5
vmovapd [rdx+32*06],ymm6
vmovapd [rdx+32*07],ymm7
vmovapd [rdx+32*08],ymm8
vmovapd [rdx+32*09],ymm9
vmovapd [rdx+32*10],ymm10
vmovapd [rdx+32*11],ymm11
vmovapd [rdx+32*12],ymm12
vmovapd [rdx+32*13],ymm13
vmovapd [rdx+32*14],ymm14
vmovapd [rdx+32*15],ymm15
add rbx,rbp
add rdx,rbp
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

