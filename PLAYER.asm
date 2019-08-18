IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "player.inc"

;; MACROS

; Booleans
TRUE		EQU	1
FALSE		EQU 0

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
CHARDMG		EQU	6	; character's damage towards enemies
CHARARMOR	EQU	7	; character's

; Amount of bytes to skip in a vector to get to either the next element or the next piece of information of an element
; vectors are arrays that are made out of an arbitrary number of elements each containing 6 pieces of information as Double Words
NEXTELEMENT	EQU 12	; get to next element of a vector
NEXTINFO	EQU 2	; get to next piece of information of an element

; Indexes of gamedata information in "projectiles" and "enemies" array
ELEMALIVE		EQU	1
ELEMXPOS		EQU	2
ELEMYPOS		EQU 3
ELEMDIR			EQU	4
ELEMCOLLISION	EQU	5
ELEMLIVES		EQU	6


; -------------------------------------------------------------------
CODESEG

;;;; 32-bit Keyboard Functionality (code from given KEYB.ASM file)

; Installs the custom keyboard handler
PROC __keyb_installKeyboardHandler
    push	ebp
    mov		ebp, esp

	push	eax
	push	ebx
	push	ecx
	push	edx
	push	edi
	push	ds
	push	es
		
	; clear state buffer and the two state bytes
	cld
	mov		ecx, (128 / 2) + 1
	mov		edi, offset __keyb_keyboardState
	xor		eax, eax
	rep		stosw
	
	; store current handler
	push	es			
	mov		eax, 3509h			; get current interrupt handler 09h
	int		21h					; in ES:EBX
	mov		[originalKeyboardHandlerS], es	; store SELECTOR
	mov		[originalKeyboardHandlerO], ebx	; store OFFSET
	pop		es
		
	; set new handler
	push	ds
	mov		ax, cs
	mov		ds, ax
	mov		edx, offset keyboardHandler			; new OFFSET
	mov		eax, 2509h							; set custom interrupt handler 09h
	int		21h									; uses DS:EDX
	pop		ds
	
	pop		es
	pop		ds
	pop		edi
	pop		edx
	pop		ecx
	pop		ebx
	pop		eax	
    
    mov		esp, ebp
    pop		ebp
    ret
ENDP __keyb_installKeyboardHandler

; Restores the original keyboard handler
PROC __keyb_uninstallKeyboardHandler
    push	ebp
    mov		ebp, esp

	push	eax
	push	edx
	push	ds
		
	mov		edx, [originalKeyboardHandlerO]		; retrieve OFFSET
	mov		ds, [originalKeyboardHandlerS]		; retrieve SELECTOR
	mov		eax, 2509h							; set original interrupt handler 09h
	int		21h									; uses DS:EDX
	
	pop		ds
	pop		edx
	pop		eax
	
    mov		esp, ebp
    pop		ebp
    ret
ENDP __keyb_uninstallKeyboardHandler

; Keyboard handler (Interrupt function, DO NOT CALL MANUALLY!)
PROC keyboardHandler
	KEY_BUFFER	EQU 60h			; the port of the keyboard buffer
	KEY_CONTROL	EQU 61h			; the port of the keyboard controller
	PIC_PORT	EQU 20h			; the port of the peripheral

	push	eax
	push	ebx
	push	esi
	push	ds
	
	; setup DS for access to data variables
	mov		ax, _DATA
	mov		ds, ax
	
	; handle the keyboard input
	sti							; re-enable CPU interrupts
	in		al, KEY_BUFFER		; get the key that was pressed from the keyboard
	mov		bl, al				; store scan code for later use
	mov		[__keyb_rawScanCode], al	; store the key in global variable
	in		al, KEY_CONTROL		; set the control register to reflect key was read
	or		al, 82h				; set the proper bits to reset the keyboard flip flop
	out		KEY_CONTROL, al		; send the new data back to the control register
	and		al, 7fh				; mask off high bit
	out		KEY_CONTROL, al		; complete the reset
	mov		al, 20h				; reset command
	out		PIC_PORT, al		; tell PIC to re-enable interrupts

	; process the retrieved scan code and update __keyboardState and __keysActive
	; scan codes of 128 or larger are key release codes
	mov		al, bl				; put scan code in al
	shl		ax, 1				; bit 7 is now bit 0 in ah
	not		ah
	and		ah, 1				; ah now contains 0 if key released, and 1 if key pressed
	shr		al, 1				; al now contains the actual scan code ([0;127])
	xor		ebx, ebx	
	mov		bl, al				; bl now contains the actual scan code ([0;127])
	lea		esi, [__keyb_keyboardState + ebx]	; load address of key relative to __keyboardState in ebx
	mov		al, [esi]			; load the keyboard state of the scan code in al
	; al = tracked state (0 or 1) of pressed key (the value in memory)
	; ah = physical state (0 or 1) of pressed key
	neg		al
	add		al, ah				; al contains -1, 0 or +1 (-1 on key release, 0 on no change and +1 on key press)
	add		[__keyb_keysActive], al	; update __keysActive counter
	mov		al, ah
	mov		[esi], al			; update tracked state
	
	pop		ds
	pop		esi
	pop		ebx
	pop		eax
	
	iretd
ENDP keyboardHandler

;;;;--------------------------------------------------------

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
	call setPlayerData, CHARXPOS, 	BASEXPOS
	call setPlayerData, CHARYPOS, 	BASEYPOS
	call setPlayerData, CHARLIVES, 	BASELIVES
	call setPlayerData, CHARDIR, 	BASEDIR
	call setPlayerData, CHARSHOOT, 	BASESHOOT
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

;;;;--------------------------------------------------------

;; Projectile management

; Shoots a projectile
PROC shootProjectile
	USES	eax, ebx, ecx, edx
	
	; test if the player is already shooting, if so, don't shoot again
	call getPlayerData, CHARSHOOT
	cmp dx, TRUE
	je @@return
	
	mov ebx, offset projectiles
	xor ecx, ecx
	mov cx, [ebx]	; amount of projectiles
	
	; find the first available projectile in projectiles array (i.e. alive = false)
	@@findProjectile:
		call vectorref, offset projectiles, ecx, ELEMALIVE
		cmp edx, FALSE
		je @@projectileFound	; if the projectile is "dead" it means it is available
		loop @@findProjectile	; if not available, continue search
		
	jmp @@return	; if we didn't find any available projectile, return without doing anything
		
	@@projectileFound:
	; get current player's position and direction to give it to the projectile
	xor eax, eax
	call getPlayerData, CHARXPOS ; stores the player's x-position in dx
	mov ax, dx
	xor ebx, ebx
	call getPlayerData, CHARYPOS ; stores the player's y-position in dx
	mov bx, dx
	call getPlayerData, CHARDIR	; stores the player's direction in dx
	; change the values of the projectile
	call vectorset, offset projectiles, ecx, ELEMALIVE, TRUE
	call vectorset, offset projectiles, ecx, ELEMXPOS, eax
	call vectorset, offset projectiles, ecx, ELEMYPOS, ebx
	call vectorset, offset projectiles, ecx, ELEMDIR, edx
	
	@@return:
		ret
ENDP shootProjectile

; Deletes a projectile
PROC deleteProjectile
	ARG		@@projectile:dword
	call vectorset, offset projectiles, [@@projectile], ELEMALIVE, FALSE
	ret
ENDP deleteProjectile

; Delete all projectiles
PROC deleteAllProjectiles
	USES	ebx, ecx, edx
	
	mov ebx, offset projectiles
	xor ecx, ecx
	mov cx, [ebx]	; amount of projectiles
	
	; find every living projectile and delete them
	@@findProjectile:
		call vectorref, offset projectiles, ecx, ELEMALIVE
		cmp edx, FALSE
		je @@next	; projectile is already dead
		call deleteProjectile, ecx
		@@next:
		loop @@findProjectile
		
	@@return:
		ret
ENDP deleteAllProjectiles

;;;;--------------------------------------------------------

;; Enemy management

; Decrease the health of an enemy
PROC decreaseEnemyHealth
	ARG		@@enemy:dword
	USES	eax, edx
	
	call getPlayerData, CHARDMG
	mov eax, edx
	call vectorref, offset enemies, [@@enemy], ELEMALIVE
	sub edx, eax
	call vectorset, offset enemies, [@@enemy], ELEMALIVE, edx
	ret
ENDP decreaseEnemyHealth

; Kill an enemy
PROC killEnemy
	ARG		@@enemy:dword
	call vectorset, offset enemies, [@@enemy], ELEMALIVE, FALSE
	ret
ENDP killEnemy

; Delete all enemies
PROC deleteAllEnemies
	USES	ebx, ecx, edx
	
	mov ebx, offset enemies
	xor ecx, ecx
	mov cx, [ebx]	; amount of enemies
	
	@@killenemies:
		call killEnemy, ecx
		loop @@killenemies
		
	@@return:
		ret
ENDP deleteAllEnemies

PROC followChar
	ARG 	@@enemy:dword, @@xpos: dword, @@ypos: dword
	USES 	edx
	
	call vectorref, offset enemies, [@@enemy], ELEMXPOS
	
	cmp edx, [@@xpos]
	jl @@increasexpos ; Increase it's position if it's lesser 
	jg @@decreasexpos ; Decrease it's position if it's greater
	
	jmp @@ypostest
	
	@@increasexpos:
		inc edx
		call vectorset, [@@enemy], ELEMXPOS, edx
		jmp @@ypostest
	
	@@decreasexpos:
		dec edx
		call vectorset, [@@enemy], ELEMXPOS, edx
		jmp @@ypostest
	
	@@ypostest:
		call vectorref, offset enemies, [@@enemy], ELEMYPOS
		cmp edx, [@@ypos]
		jl @@increaseypos
		jg @@decreaseypos
	
		jmp @@return
	
	@@increaseypos:
		inc edx
		call vectorset, [@@enemy], ELEMYPOS, edx
		jmp @@return
	
	@@decreaseypos:
		dec edx
		call vectorset, [@@enemy], ELEMYPOS, edx
		jmp @@return
	
	@@return:
		ret		
ENDP followChar

PROC enemiesFollow
	USES	eax, ebx, ecx, edx
	
	mov ebx, offset enemies
	xor ecx, ecx
	mov cx, [ebx]
	
	@@loopEnemy:
		xor eax, eax
		call getPlayerData, CHARXPOS
		mov ax, dx
		call getPlayerData, CHARYPOS
		call followChar, ecx, eax, edx
		loop @@loopEnemy
	ret
ENDP enemiesFollow

;;;;--------------------------------------------------------

DATASEG
	originalKeyboardHandlerS	dw ?			; SELECTOR of original keyboard handler
	originalKeyboardHandlerO	dd ?			; OFFSET of original keyboard handler

	__keyb_keyboardState		db 128 dup(?)	; state for all 128 keys
	__keyb_rawScanCode			db ?			; scan code of last pressed key
	__keyb_keysActive			db ?			; number of actively pressed keys
	
	playerlen		dw	5
					;	x-pos, y-pos, lives		direction	shooting?	damage		armor
	playerdata		dw	 150, 	120, 	6,		1,			0,			20,			0
	
	
	;; vectors:
	
	projectiles		dw 	10, 6	; amount of projectiles, amount of information per projectile
							
							; alive, x-pos, y-pos,	direction,	collision?	lives
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					dw		0,		0,		0,		0,			1,			1
					
	enemies			dw	2,	6	; amount of enemies, amount of information per enemy
	
							; alive, x-pos, y-pos,	direction,	collision?	lives
					dw		1,		50,		80,		0,			1,			60
					dw		1,		220,	150,	0,			1,			60

STACK

END