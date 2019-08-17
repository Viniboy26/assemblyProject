IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "player.inc"

;; MACROS

; Indexes of character information in "playerdata" array
CHARXPOS	EQU 1	; character begin x-position
CHARYPOS	EQU 2	; character begin y-position
CHARLIVES	EQU 3 	; number of lives character has
CHARDIR		EQU 4	; character's direction
CHARSHOOT	EQU	5	; boolean, test if charater is shooting


; -------------------------------------------------------------------
CODESEG

; PROC handlePlayer
	; USES eax, ebx, ecx, edx
	
	;; Test if character remains in screen boundary
	; call testBoarders, offset character
	; call collisionWithRoom
	
	;; Set eax, ecx and edx equal to 0
	; xor eax, eax
	; xor ecx, ecx
	; xor edx, edx
	
	; mov ebx, offset playerdata	; pointer to player data
	; mov ax, [ebx]				; assign x-position to ax
	
	; add ebx, 2					; go to next element
	; mov dx, [ebx]				; assign y-position to dx
	
	;; Draw the character
	; call	drawSprite, eax, edx, offset character, offset screenBuffer
	
	; add ebx, 2					; go to next element
	; mov cx, [ebx]				; assign lives to cx
	; cmp cx, 0
	; jg @@stillAlive									; if lives > 0, the player is still alive, gamestarted does not need to be set to 0
	; call selectOption, offset gamestarted, FALSE	; if lives = 0, set gamestarted to 0 which will return us to the menu
	; jmp @@return									; after setting gamestarted to 0 return out of the function
	
	; @@stillAlive:
	; call 	drawNSprites, 2, 2, ecx, 2, offset heart ; draw remaining lives	
	
	; @@return:
		; ret	
; ENDP handlePlayer

PROC getPlayerData
	ARG		@@index:dword	RETURNS	edx
	USES	ebx, ecx
	
	mov ebx, offset playerlen
	mov ecx, [@@index]
	
	@@getToIndex:
		add ebx, 2			; go to next element
		loop @@getToIndex	; loop until the correct index is reached
	
	xor edx, edx
	mov dx, [ebx]
	ret
ENDP getPlayerData

PROC setPlayerData
	ARG		@@index:dword, @@newvalue:word
	USES	ebx, ecx
	
	mov ebx, offset playerlen
	mov ecx, [@@index]
	
	@@getToIndex:
		add ebx, 2			; go to next element
		loop @@getToIndex	; loop until the correct index is reached
	
	xor ecx, ecx
	mov cx, [@@newvalue]
	mov [ebx], cx
	ret
ENDP setPlayerData

; Decrease player's health by 1
PROC decreaseHealth
	USES edx
	
	call getPlayerData, CHARLIVES
	dec edx
	call setPlayerData, CHARLIVES, edx
	ret
ENDP decreaseHealth

DATASEG
	playerlen		dw	5
					;	x-pos, y-pos, lives		direction	shooting?
	playerdata		dw	 150, 	120, 	6,		1,			0

STACK

END