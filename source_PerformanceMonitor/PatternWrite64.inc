;--- Performance pattern, x86-64 Write 64-bit ---
; INPUT:   None
; OUTPUT:  R8  = Delta TSC, clocks
;          R9  = Delta IA32_MPERF, clocks
;          R10 = Delta IA32_APERF, clocks 
;          R11 = Total target instructions (or r-w groups) executed
;---

Performance_Write_64:
;--- Clear write data ---
xor r8,r8
xor r9,r9
xor r10,r10
xor r11,r11
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
mov eax,50000000
.L1:
mov rbx,DataBuffer
mov rcx,16384/16/8
mov edx,16*8 
.L0:
mov [rbx+8*00],r8
mov [rbx+8*01],r9
mov [rbx+8*02],r10
mov [rbx+8*03],r11
mov [rbx+8*04],r8
mov [rbx+8*05],r9
mov [rbx+8*06],r10
mov [rbx+8*07],r11
mov [rbx+8*08],r8
mov [rbx+8*09],r9
mov [rbx+8*10],r10
mov [rbx+8*11],r11
mov [rbx+8*12],r8
mov [rbx+8*13],r9
mov [rbx+8*14],r10
mov [rbx+8*15],r11
add rbx,rdx
dec ecx
jnz .L0
dec eax
jnz .L1
mov r11,50000000*16384/8
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

