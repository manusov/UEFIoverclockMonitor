;--- Performance pattern, AVX Copy 128-bit ---
; INPUT:   None
; OUTPUT:  R8  = Delta TSC, clocks
;          R9  = Delta IA32_MPERF, clocks
;          R10 = Delta IA32_APERF, clocks 
;          R11 = Total target instructions (or r-w groups) executed
;---

Performance_Copy_128:
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
mov r11,50000000*16384/16/2
mov eax,50000000
.L1:
mov rbx,DataBuffer
lea rdx,[rbx+16384/2]
mov rcx,16384/16/16/2
mov ebp,16*16 
.L0:
vmovapd xmm0, [rbx+16*00]
vmovapd xmm1, [rbx+16*01]
vmovapd xmm2, [rbx+16*02]
vmovapd xmm3, [rbx+16*03]
vmovapd xmm4, [rbx+16*04]
vmovapd xmm5, [rbx+16*05]
vmovapd xmm6, [rbx+16*06]
vmovapd xmm7, [rbx+16*07]
vmovapd xmm8, [rbx+16*08]
vmovapd xmm9, [rbx+16*09]
vmovapd xmm10,[rbx+16*10]
vmovapd xmm11,[rbx+16*11]
vmovapd xmm12,[rbx+16*12]
vmovapd xmm13,[rbx+16*13]
vmovapd xmm14,[rbx+16*14]
vmovapd xmm15,[rbx+16*15]
vmovapd [rdx+16*00],xmm0
vmovapd [rdx+16*01],xmm1
vmovapd [rdx+16*02],xmm2
vmovapd [rdx+16*03],xmm3
vmovapd [rdx+16*04],xmm4
vmovapd [rdx+16*05],xmm5
vmovapd [rdx+16*06],xmm6
vmovapd [rdx+16*07],xmm7
vmovapd [rdx+16*08],xmm8
vmovapd [rdx+16*09],xmm9
vmovapd [rdx+16*10],xmm10
vmovapd [rdx+16*11],xmm11
vmovapd [rdx+16*12],xmm12
vmovapd [rdx+16*13],xmm13
vmovapd [rdx+16*14],xmm14
vmovapd [rdx+16*15],xmm15
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

