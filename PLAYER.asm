IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "player.inc"

;; MACROS

; Base values of player
BASEXPOS	EQU	150
BASEYPOS	EQU 120
BASELIVES	EQU	6
BASEDIR		EQU	1
BASESHOOT	EQU	0

; Indexes of character information in "playerdata" array
CHARXPOS	EQU 1	; character begin x-position
CHARYPOS	EQU 2	; character begin y-position
CHARLIVES	EQU 3 	; number of lives character has
CHARDIR		EQU 4	; character's direction
CHARSHOOT	EQU	5	; boolean, test if charater is shooting

; Amount of bytes to skip in a vector to get to either the next element or the next piece of information of an element
; vectors are arrays that are made out of an arbitrary number of elements each containing 6 pieces of information as Double Words
NEXTELEMENT	EQU 12	; get to next element of a vector
NEXTINFO	EQU 2	; get to next piece of information of an element


; -------------------------------------------------------------------
CODESEG

;;;; Player

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

; Reset Player
PROC resetPlayer
	call setPlayerData, CHARXPOS, BASEXPOS
	call setPlayerData, CHARYPOS, BASEYPOS
	call setPlayerData, CHARLIVES, BASELIVES
	call setPlayerData, CHARDIR, BASEDIR
	call setPlayerData, CHARSHOOT, BASESHOOT
	ret
ENDP resetPlayer

;;;;--------------------------------------------------------

;;;; Vectors

; Get the information from an element from an array containing game data
PROC vectorref
	ARG		@@array:dword, @@element: dword, @@information:dword	RETURNS	edx
	USES	ebx, ecx
	
	mov ebx, [@@array]
	add ebx, NEXTINFO	; skip amount of elements and information per element
	mov ecx, [@@element]
	dec ecx
	cmp ecx, 0
	je @@elementzero
	
	@@getToElement:
		add ebx, NEXTELEMENT 	; go to next element
		loop @@getToElement 	; loop until the correct element is reached
		
	@@elementzero:
	
	mov ecx, [@@information]
	
	@@getToInformation:
		add ebx, NEXTINFO		; get to next piece of information
		loop @@getToInformation	; loop until the correct information is reached
	
	xor edx, edx
	mov dx, [ebx]
	ret	
ENDP vectorref

; Set a piece of information from an element from an array to a different value
PROC vectorset
	ARG		@@array:dword, @@element:dword, @@information:dword, @@newvalue:word
	USES	ebx, ecx
	
	mov ebx, [@@array]
	add ebx, NEXTINFO	; skip amount of elements and information per element
	mov ecx, [@@element]
	dec ecx
	cmp ecx, 0
	je @@elementzero
	
	@@getToElement:
		add ebx, NEXTELEMENT 	; go to next element
		loop @@getToElement 	; loop until the correct element is reached
		
	@@elementzero:
	
	mov ecx, [@@information]
	
	@@getToInformation:
		add ebx, NEXTINFO		; get to next piece of information
		loop @@getToInformation	; loop until the correct information is reached
	
	xor ecx, ecx
	mov cx, [@@newvalue]
	mov [ebx], cx
	ret
ENDP vectorset

DATASEG
	playerlen		dw	5
					;	x-pos, y-pos, lives		direction	shooting?
	playerdata		dw	 150, 	120, 	6,		1,			0

STACK

END