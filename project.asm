IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "keyb.inc"
INCLUDE "sprites.inc"

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen width
SCRHEIGHT EQU 200	; screen height

; Indexes of character information in "gamedata" array
CHARXPOS	EQU 1	; character begin x-position
CHARYPOS	EQU 2	; character begin y-position
CHARLIVES	EQU 3 	; number of lives character has
ENEMY1XPOS	EQU	4
ENEMY1YPOS	EQU 5
CHARWIDTH	EQU 25	; character width
CHARHEIGHT	EQU 25	; character height
CHARCOLOR	EQU 40 	; character color

KEYCNT EQU 89		; number of keys to track

; -------------------------------------------------------------------
CODESEG

; Set the video mode
PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

; Fill the background
PROC fillBackground
	ARG 	@@fillcolor:byte
	USES 	eax, ecx, edi

	; Initialize video memory address.
	mov	edi, VMEMADR
	
	; copy color value across all bytes of eax
	mov al, [@@fillcolor]	; ???B
	mov ah, al				; ??BB
	mov cx, ax			
	shl eax, 16				; BB00
	mov ax, cx				; BBBB

	; Scan the whole video memory and assign the background colour.
	mov	ecx, SCRWIDTH*SCRHEIGHT/4
	rep	stosd

	ret
ENDP fillBackground

; Draw a rectangle (video mode 13h)
; 	* draws the rectangle from position (x0,y0) with
;	  positive width 'w' and height 'h', with color "col"
PROC drawRectangle
	ARG 	@@x0:word, @@y0:word, @@w:word, @@h:word, @@col: byte
	USES 	eax, ecx, edx, edi ; note: MUL uses edx!

	; Compute the index of the rectangle's top left corner
	movzx eax, [@@y0]
	mov edx, SCRWIDTH
	mul edx
	add	ax, [@@x0]

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	; Plot the top horizontal edge.
	movzx edx, [@@w]	; store width in edx for later reuse
	movzx ecx, [@@h]
	@@horloop:
		push ecx
		mov	ecx, edx
		mov	al,[@@col]
		rep stosb
		add edi, SCRWIDTH	; set edi to the next line
		sub edi, edx		; subtract the width so edi is on the left	
		pop ecx
		loop @@horloop	
		
	ret
ENDP drawRectangle

;;;;---------------------------------------------------------------------------------------------------

;; Game data management

; Get the element on the specified index from the gamedata array
PROC getGamedataElement
	ARG		@@index:dword	RETURNS	edx
	USES	ebx, ecx
	
	mov ebx, offset gamelen
	mov ecx, [@@index]
	
@@getToIndex:
	add ebx, 4 	; go to next element
	loop @@getToIndex ; loop until the correct index is reached
	
	mov edx, [ebx]
	ret	
ENDP getGamedataElement

; Set an element from gamedata to a different value
PROC setGamedataElement
	ARG		@@index:dword, @@newvalue:dword
	USES	ebx, ecx
	
	mov ebx, offset gamelen
	mov ecx, [@@index]
	
@@getToIndex:
	add ebx, 4	; go to next element
	loop @@getToIndex ; loop until the correct index is reached
	
	xchg ecx, [@@newvalue]
	mov [ebx], ecx
	ret
ENDP setGamedataElement

; Decrease character's health by 1
PROC decreaseHealth
	USES edx
	
	call getGamedataElement, CHARLIVES
	dec edx
	call setGamedataElement, CHARLIVES, edx
	ret
ENDP decreaseHealth

;;;;---------------------------------------------------------------------------------------------------

;; Movement methods

; Move the character's x- or y-position left/right or up/down
PROC moveCharacter
	ARG		@@POS:dword, @@direction:byte ; direction determines if we increase or decrease edx
	USES	edx
	
	call getGamedataElement, [@@POS]
	cmp [@@direction], 0
	jg @@increase
	jmp @@decrease
	
@@increase:
	add edx, 3
	jmp @@return
	
@@decrease:
	sub edx, 3
	
@@return:
	call setGamedataElement, [@@POS], edx
	ret
ENDP moveCharacter

; Move to the right
PROC moveRight
	call moveCharacter, CHARXPOS, 1
	ret
ENDP moveRight

; Move to the left
PROC moveLeft
	call moveCharacter, CHARXPOS, 0
	ret
ENDP moveLeft

; Move up
PROC moveUp
	call moveCharacter, CHARYPOS, 0
	ret
ENDP moveUp

; Move down
PROC moveDown
	call moveCharacter, CHARYPOS, 1
	ret
ENDP moveDown

PROC testBoarders
	USES edx, eax;, ebx
	
	call getGamedataElement, CHARXPOS
	cmp	edx, 0
	jle	@@setToLeftScreen
	;mov ebx, offset character 
	add edx, CHARWIDTH
	cmp edx, SCRWIDTH
	jge @@setToRightScreen
	
	jmp @@testYPOS
	
@@setToLeftScreen:
	call setGamedataElement, CHARXPOS, 0
	jmp @@testYPOS
	
@@setToRightScreen:
	mov eax, SCRWIDTH
	sub eax, CHARWIDTH
	call setGamedataElement, CHARXPOS, eax
	jmp @@testYPOS
	
@@testYPOS:
	call getGamedataElement, CHARYPOS
	cmp edx, 0
	jle @@setToTopScreen
	add edx, CHARHEIGHT
	cmp edx, SCRHEIGHT
	jge @@setToBottomScreen
	
	jmp @@return
	
@@setToTopScreen:
	call setGamedataElement, CHARYPOS, 0
	jmp @@return
	
@@setToBottomScreen:
	mov eax, SCRHEIGHT
	sub eax, CHARHEIGHT
	call setGamedataElement, CHARYPOS, eax
	jmp @@return
	
@@return:
	ret
ENDP testBoarders

;;;;---------------------------------------------------------------------------------------------------

;; Keyboard management

; Determines what to do when a certain key is pressed
PROC keyboardFunction
	USES	ebx, ecx
	
	mov ecx, KEYCNT	; amount of keys to process
	movzx ebx, [byte ptr offset keybscancodes + ecx - 1] ; get scancode

	; Test to see which key has been pressed
	
	; button underneath escape
	mov bl, [offset __keyb_keyboardState + 29h]	; obtain corresponding key state
	cmp bl, 1
	je @@escapeKey
	
	; right arrow
	mov bl, [offset __keyb_keyboardState + 4Dh]	; obtain corresponding key state
	cmp bl, 1
	je @@moveRight
	
	; left arrow
	mov bl, [offset __keyb_keyboardState + 4Bh]	; obtain corresponding key state
	cmp bl, 1
	je @@moveLeft
	
	; up arrow
	mov bl, [offset __keyb_keyboardState + 48h]	; obtain corresponding key state
	cmp bl, 1
	je @@moveUp
	
	; down arrow
	mov bl, [offset __keyb_keyboardState + 50h]	; obtain corresponding key state
	cmp bl, 1
	je @@moveDown
	
	; spacebar
	mov bl, [offset __keyb_keyboardState + 39h]	; obtain corresponding key state
	cmp bl, 1
	je @@decreaseHealth
	
	; If no key has been pressed, return without doing anything
	jmp @@return
	
	; Consequences according to pressed key
	
@@escapeKey: 
	call __keyb_uninstallKeyboardHandler
	call terminateProcess
	
@@moveRight:
	call moveRight
	jmp @@return
	
@@moveLeft:
	call moveLeft
	jmp @@return
	
@@moveUp:
	call moveUp
	jmp @@return
	
@@moveDown:
	call moveDown
	jmp @@return
	
@@decreaseHealth:
	call decreaseHealth
	jmp @@return
	
@@return:
	ret
ENDP keyboardFunction

;;;;---------------------------------------------------------------------------------------------------

;; Frame management

; wait for @@framecount frames
proc wait_VBLANK
	ARG @@framecount: word
	USES eax, ecx, edx
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]
	
		@@VBlank_phase1:
		in al, dx 
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx 
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1
	
	ret 
endp wait_VBLANK

;;;;---------------------------------------------------------------------------------------------------

; Terminate the program.
PROC terminateProcess
	USES eax
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

;;;;---------------------------------------------------------------------------------------------------

PROC followChar
	ARG @@xpos: dword, @@ypos: dword
	USES edx
	
	call getGamedataElement, ENEMY1XPOS
	
	cmp edx, [@@xpos]
	jl @@increasexpos ; Increase it's position if it's lesser 
	jg @@decreasexpos ; Decrease it's position if it's greater
	
	jmp @@ypostest
	
@@increasexpos:
	inc edx
	call setGamedataElement, ENEMY1XPOS, edx
	jmp @@ypostest
	
@@decreasexpos:
	dec edx
	call setGamedataElement, ENEMY1XPOS, edx
	jmp @@ypostest
	
@@ypostest:
	call getGamedataElement, ENEMY1YPOS
	cmp edx, [@@ypos]
	jl @@increaseypos
	jg @@decreaseypos
	
	jmp @@return
	
@@increaseypos:
	inc edx
	call setGamedataElement, ENEMY1YPOS, edx
	jmp @@return
	
@@decreaseypos:
	dec edx
	call setGamedataElement, ENEMY1YPOS, edx
	jmp @@return
	
@@return:
	ret		
ENDP followChar
	

;; MAIN method

PROC main
	sti
	cld
	
	push ds
	pop	es
	
	call	setVideoMode,13h
	call	fillBackground, 0
	call __keyb_installKeyboardHandler
	
@@gameloop:
	call 	keyboardFunction
	call	fillBackground, 0
	
	; Draw Enemy
	call	getGamedataElement, ENEMY1XPOS
	mov eax, edx
	call	getGamedataElement, ENEMY1YPOS
	;call	drawRectangle, eax, edx, CHARWIDTH, CHARHEIGHT, 30
	call	drawSprite, eax, edx, 0, offset backgrounds
	
	; Draw character
	call testBoarders
	call	getGamedataElement, CHARXPOS
	mov eax, edx
	call	getGamedataElement, CHARYPOS
	;call	drawRectangle, eax, edx, CHARWIDTH, CHARHEIGHT, CHARCOLOR
	call	drawSprite, eax, edx, 0, offset character
	;call	followChar, eax, edx
	
	call	drawSprite, 20, 50, 0, offset backgrounds

	
	; Test if character is alive
	call getGamedataElement, CHARLIVES ; store the number of lives in edx
	cmp edx, 0 ; compare the number of lives to 0
	je @@gameover
	
	
	
	call 	wait_VBLANK, 1
	
	;; Jump back to the gameloop
	jmp @@gameloop
	

@@gameover:
	call __keyb_uninstallKeyboardHandler
	call terminateProcess
	
ENDP main

; -------------------------------------------------------------------
DATASEG
	keybscancodes 	db 29h, 02h, 03h, 04h, 05h, 06h, 07h, 08h, 09h, 0Ah, 0Bh, 0Ch, 0Dh, 0Eh, 	52h, 47h, 49h, 	45h, 35h, 00h, 4Ah
					db 0Fh, 10h, 11h, 12h, 13h, 14h, 15h, 16h, 17h, 18h, 19h, 1Ah, 1Bh, 		53h, 4Fh, 51h, 	47h, 48h, 49h, 		1Ch, 4Eh
					db 3Ah, 1Eh, 1Fh, 20h, 21h, 22h, 23h, 24h, 25h, 26h, 27h, 28h, 2Bh,    						4Bh, 4Ch, 4Dh
					db 2Ah, 00h, 2Ch, 2Dh, 2Eh, 2Fh, 30h, 31h, 32h, 33h, 34h, 35h, 36h,  			 48h, 		4Fh, 50h, 51h,  1Ch
					db 1Dh, 0h, 38h,  				39h,  				0h, 0h, 0h, 1Dh,  		4Bh, 50h, 4Dh,  52h, 53h
	gamelen			dd	6	; length of gamedata array
	gamedata		dd	150 ; character x-position
					dd	170 ; character y-position
					dd 	10	; number of lives
					dd	100
					dd	80
					
	background	DW 32, 25
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
	
	backgrounds	DW 32,25
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				DB 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				
	character	DW 25, 25
				DB 57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,00H,00H,00H,00H,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,57H,57H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,57H,57H,57H,57H
				DB 57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,57H,57H,57H
				DB 57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,57H,57H
				DB 57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,57H
				DB 57H,00H,57H,57H,00H,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,00H,00H,57H,57H,00H,57H
				DB 57H,00H,57H,00H,1FH,1FH,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,00H,1FH,1FH,00H,00H,00H,57H,00H,57H
				DB 57H,00H,57H,00H,1FH,1FH,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,00H,1FH,1FH,00H,00H,00H,57H,00H,57H
				DB 57H,00H,57H,00H,00H,00H,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,00H,00H,00H,00H,00H,00H,57H,00H,57H
				DB 57H,00H,57H,57H,00H,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,00H,00H,57H,57H,00H,57H
				DB 57H,57H,00H,57H,4EH,4EH,4EH,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,4EH,4EH,4EH,57H,00H,57H,57H
				DB 57H,57H,57H,00H,4EH,4EH,4EH,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,4EH,4EH,4EH,00H,57H,57H,57H
				DB 57H,57H,57H,57H,00H,00H,4EH,4EH,57H,57H,57H,57H,57H,57H,57H,57H,57H,4EH,4EH,00H,00H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,57H,57H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,57H,00H,00H,57H,00H,00H,00H,00H,00H,00H,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,00H,57H,00H,00H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,00H,00H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				DB 57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H
				
; -------------------------------------------------------------------

; -------------------------------------------------------------------
UDATASEG
	palette		db 768 dup (?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
