;--- Performance pattern, AVX Write 128-bit ---
; INPUT:   None
; OUTPUT:  R8  = Delta TSC, clocks
;          R9  = Delta IA32_MPERF, clocks
;          R10 = Delta IA32_APERF, clocks 
;          R11 = Total target instructions (or r-w groups) executed
;---

Performance_Write_128:
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
mov r11,50000000*16384/16
mov eax,50000000
.L1:
mov rbx,DataBuffer
mov rcx,16384/16/16
mov edx,16*16 
.L0:
vmovapd [rbx+16*00],xmm0
vmovapd [rbx+16*01],xmm1
vmovapd [rbx+16*02],xmm2
vmovapd [rbx+16*03],xmm3
vmovapd [rbx+16*04],xmm4
vmovapd [rbx+16*05],xmm5
vmovapd [rbx+16*06],xmm6
vmovapd [rbx+16*07],xmm7
vmovapd [rbx+16*08],xmm8
vmovapd [rbx+16*09],xmm9
vmovapd [rbx+16*10],xmm10
vmovapd [rbx+16*11],xmm11
vmovapd [rbx+16*12],xmm12
vmovapd [rbx+16*13],xmm13
vmovapd [rbx+16*14],xmm14
vmovapd [rbx+16*15],xmm15
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

