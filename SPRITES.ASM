IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen width
SCRHEIGHT EQU 200	; screen height

include "sprites.inc"

CODESEG

PROC drawSprite
	ARG		@@xpos:word, @@ypos:word, @@index:word, @@sprite:dword
	USES 	eax,ebx,ecx,edx,edi,esi,ebp
	
	; Get the top left corner of the sprite's index
	movzx eax, [@@ypos]
	mov edx, SCRWIDTH
	mul edx
	add	ax, [@@xpos]
	
	; Get the adress of the top left corner
	mov edi, VMEMADR
	add edi, eax				; the position where the sprite needs to be drawn is now stored in edi
	
	xor eax,eax
	xor ecx,ecx
	mov ebx, [@@sprite]		; store the sprite in ebx
	mov al, [ebx]			; store the number of cols in al (eax)
	mov cl, [ebx + 2]		; store the number of rows in cl (ecx)
	add ebx, 4				; go to the actual list (not the first 2 arguments)
		
	mov esi, eax ; we store the width of the sprite for later uses
	mov ebp, ecx ; we store the height of the sprite for later uses
	
	push eax				; save eax to multiply
	push edx				; save edx to multiply
	;movzx edx, [@@index]    ; store the index in edx
	;@@goToIndex:
	;	add ebx, eax		; go to this index in the sprite array (ebx)
	;	sub edx, 1
	;	cmp edx, 1
	;	jg @@goToIndex
	pop edx					; restore edx
	pop eax					; restore eax

	; ecx, 1				; this is needed cause else it doesn't draw the last col
	@@rowLoop:
		push ecx
		@@colLoop:
			push eax
			;sub eax, 1
			mov al, [ebx]
			mov [edi], al
			pop eax
			sub eax, 1		; lower the eax register by 1
			cmp eax, 0		; test if eax is 0, if so, go out of the loop, else, continue the loop
			jle @@break
			add ebx, 1
			add edi, 1		; move the position of the pixel by one
			jmp @@colLoop
		@@break:
		mov eax, esi		; reset eax to the width of the sprite
		add ebx, 1			; go to the next row of the sprite
		add edi, SCRWIDTH	; go to the next line in the memory adress
		sub edi, esi		; go to the left side of the sprite
		;sub edi, 1
		add edi,1
		pop ecx
		loop @@rowLoop
		
	ret
ENDP drawSprite

DATASEG
	
STACK 100h

END