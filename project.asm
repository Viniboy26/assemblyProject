IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "keyb.inc"
INCLUDE "sprites.inc"

; compile-time constants (with macros)
VMEMADR		EQU 0A002FH	; video memory address
SCRWIDTH	EQU 320		; screen width
SCRHEIGHT	EQU 200		; screen height
GAMEWIDTH	EQU 320
GAMEHEIGHT	EQU 150
INVWIDTH	EQU 320
INVHEIGHT	EQU 50

STILL		EQU	0
LEFT		EQU 1
RIGHT		EQU 2
UP			EQU 3
DOWN		EQU 4


; Indexes of character information in "gamedata" array
CHARXPOS	EQU 1	; character begin x-position
CHARYPOS	EQU 2	; character begin y-position
CHARLIVES	EQU 3 	; number of lives character has
ENEMY1XPOS	EQU	4
ENEMY1YPOS	EQU 5
CHARWIDTH	EQU 25	; character width
CHARHEIGHT	EQU 25	; character height
CHARCOLOR	EQU 40 	; character color
GRIdwIDTH	EQU 32	; width of the grid
GRIDHEIGHT	EQU 25	; height of the grid

KEYCNT EQU 89		; number of keys to track

; Menu options
START	EQU 1
EXIT	EQU 2

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
	mov	edi, offset screenBuffer
	
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

;; Player management

PROC handlePlayer
	USES eax, ebx, ecx, edx
	
	; Test if character remains in screen boundary
	call testBoarders, offset character
	
	; Set eax, ecx and edx equal to 0
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	
	mov ebx, offset playerdata	; pointer to player data
	mov ax, [ebx]				; assign x-position to ax
	
	add ebx, 2					; go to next element
	mov dx, [ebx]				; assign y-position to dx
	
	; Draw the character
	call	drawSprite, eax, edx, offset character, offset screenBuffer
	
	add ebx, 2					; go to next element
	mov cx, [ebx]				; assign lives to cx
	cmp cx, 0
	jg @@return									; if lives > 0, return
	call selectOption, offset gamestarted, 0	; if lives = 0, set gamestarted to 0 which will return us to the menu
	
	@@return:
		ret
ENDP handlePlayer

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
	xchg cx, [@@newvalue]
	mov [ebx], cx
	ret
ENDP setPlayerData

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
	;call fillBackground, 0
	ret
ENDP decreaseHealth

;;;;---------------------------------------------------------------------------------------------------

;; Movement methods

; Move the character's x- or y-position left/right or up/down
PROC moveCharacter
	ARG		@@POS:dword, @@direction:byte
	USES 	edx
	
	xor edx, edx
	call getPlayerData, [@@POS]
	cmp [@@direction], 0
	jg @@increase	; if direction = 1 > 0, increase edx
	
	sub dx, 5		; otherwise decrease edx
	jmp @@return
	
	@@increase:
		add dx, 5
	
	@@return:
		call setPlayerData, [@@POS], edx
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
	ARG @@sprite:dword
	USES eax, ebx, ecx, edx, edi
	
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	xor edi, edi
	
	mov edi, [@@sprite]	; character
	mov cl, [edi]		; character-width  (stored in ecx)
	mov al, [edi + 2]	; character-height (stored in edx)
	
	call getPlayerData, CHARXPOS
	cmp	dx, 0
	jle	@@setToLeftScreen
	add dx, cx
	cmp dx, GAMEWIDTH
	jge @@setToRightScreen
	
	jmp @@testYPOS
	
	@@setToLeftScreen:
		call setPlayerData, CHARXPOS, 0
		jmp @@testYPOS
	
	@@setToRightScreen:
		mov ebx, GAMEWIDTH
		sub ebx, ecx
		call setPlayerData, CHARXPOS, ebx
		jmp @@testYPOS
	
	@@testYPOS:
		call getPlayerData, CHARYPOS
		cmp edx, INVHEIGHT
		jle @@setToTopScreen
		add edx, eax
		; add edx, INVHEIGHT
		cmp edx, SCRHEIGHT
		jge @@setToBottomScreen
	
		jmp @@return
	
	@@setToTopScreen:
		call setPlayerData, CHARYPOS, INVHEIGHT
		jmp @@return
	
	@@setToBottomScreen:
		mov ebx, SCRHEIGHT
		sub ebx, eax
		call setPlayerData, CHARYPOS, ebx
		jmp @@return
	
	@@return:
		ret
ENDP testBoarders

;;;;---------------------------------------------------------------------------------------------------

;; Menu management

PROC selectOption
	ARG	@@darray:dword, @@option:byte ;  option = 0 or 1, according to if we want to de- or increase the value in darray
	USES eax, ebx, ecx
	
	mov ebx, [@@darray]	; pointer to option
	mov ecx, [ebx]			; option
	
	cmp [@@option], 0
	jg @@nextOption
	jmp @@priorOption
	
	@@nextOption:
		inc ecx
		jmp @@setOption
	
	@@priorOption:
		dec ecx
	
	@@setOption:
		xchg eax, ecx
		mov [ebx], eax
	
	ret
ENDP selectOption

PROC startGame
	call selectOption, offset gamestarted, 1
	ret
ENDP startGame

;;;;---------------------------------------------------------------------------------------------------

;; Keyboard management

; Determines what to do when a certain key is pressed while in the menu
PROC keyboardDuringMenu
	USES ebx, ecx
	
	mov ecx, KEYCNT	; amount of keys to process
	movzx ebx, [byte ptr offset keybscancodes + ecx - 1] ; get scancode
	
	; Test to see which key has been pressed
	
	; enter (select option)
	mov bl, [offset __keyb_keyboardState + 1Ch]	; obtain corresponding key state
	cmp bl, 1
	je @@selectOption
	
	; up arrow
	mov bl, [offset __keyb_keyboardState + 48h]	; obtain corresponding key state
	cmp bl, 1
	je @@priorOption
	
	; down arrow
	mov bl, [offset __keyb_keyboardState + 50h]	; obtain corresponding key state
	cmp bl, 1
	je @@nextOption
	
	; If no key has been pressed, return without doing anything
	jmp @@return
	
	; Consequences according to pressed key
	
	;;-----------------------------------------------
	
	; When enter is pressed
	
	@@selectOption:
		mov bl, [offset menuoption]	; get the current menu option, then proceed to test which one it is
	
		cmp bl, START
		je @@startGame
	
		cmp bl, EXIT
		je @@exit
	
		jmp @@return
	
	@@startGame:
		call startGame
		jmp @@return
	
	@@exit:
		call __keyb_uninstallKeyboardHandler
		call terminateProcess
	
	;;-----------------------------------------------
	
	; Other keys
	
	@@priorOption:
		mov bl, [offset menuoption]
		cmp bl, START	; test to see if we remain in amount of options boundary
		je @@return		; if our current option is the first one we can't go to the prior option
		call selectOption, offset menuoption, 0
		jmp @@return
	
	@@nextOption:
		mov bl, [offset menuoption]
		cmp bl, EXIT	; test to see if we remain in amount of options boundary
		je @@return		; if our current option is the last one we can't go to the next option
		call selectOption, offset menuoption, 1
		jmp @@return
	
	@@return:
		ret
ENDP keyboardDuringMenu

; Determines what to do when a certain key is pressed during the game
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
	mov	ax,04C2FH
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

PROC drawBackground
	USES 	eax, ebx, ecx, edx, edi
	
	xor ecx,ecx
	xor ebx,ebx
	xor eax,eax
	xor edi,edi
	
	mov ebx, 50
	mov ecx, 6		; store the number of rows in ecx
	
	@@rowLoop:
		call drawNSprites, 0, ebx, 10, 0, offset background
		add ebx, 25
		loop @@rowLoop
		
	ret
ENDP drawBackground

PROC drawNSprites
	ARG		@@xpos:word, @@ypos:word, @@nSprites:word, @@gap:word, @@sprite:dword
	USES 	eax, ebx, ecx, edx, edi
	
	movzx ebx, [@@xpos]
	movzx edx, [@@ypos]
	movzx eax, [@@gap]
	
	mov edi, [@@sprite]
	
	movzx ecx, [@@nSprites]		; total sprites to print
	
	@loop:
		call drawSprite, ebx, edx, [@@sprite], offset screenBuffer
		add ebx, [edi]
		add ebx, eax
		loop @loop
		
	ret
ENDP drawNSprites

PROC drawSprites
	ARG		@@data:dword, @@sprite:dword
	USES	eax, ebx, ecx, edx, edi
	
	xor ecx, ecx
	
	
	mov edi, [@@data]	; store the data array in edi
	mov cl, [edi]		; store the number of elements in ecx
	add edi, 4
	
	xor eax,eax
	xor ebx,ebx
	@@foreach:
			push ecx
			mov cl, [edi]
			cmp cl, 0			; test if the element must be drawn
			je @@aliveBreak
			
			inc edi
			mov eax, [edi]	; the x position in eax
			inc edi
			mov ebx, [edi]	; the y position in ebx
			; draw the sprite
			call	drawSprite, eax, ebx, [@@sprite], offset screenBuffer
			
			inc edi
			mov al, [edi]	; the direction in eax
			
			jmp @@tests			
			
			@@endTests:
			inc edi
			jmp @@continue
			
			@@aliveBreak:
			add edi,4   	; we still need to add 4 to go to the next element
			@@continue:
			pop ecx
			loop @@foreach
			jmp @@return
			
	@@tests:
		cmp eax, 0
		je @@endTests
	
		cmp eax, 1	; test if it needs to go left
		je @@moveLeft
			
		cmp eax, 2	; test if it needs to go right
		je @@moveRight
			
		cmp eax, 3		; test if it needs to go up
		je @@moveUp
			
		cmp eax, 4	; test if it needs to go down
		je @@moveDown
		
		jmp @@endTests
			
		@@moveLeft:
			push edi
			sub edi, 2				; store the x position of the object in edi
			call moveObject, edi, 0	; 0 means decreasing
			pop edi
			jmp @@endTests
				
		@@moveRight:
			push edi
			sub edi, 2				; store the x position of the object in edi	
			call moveObject, edi, 1	; 1 means increase
			pop edi
			jmp @@endTests
				
		@@moveUp:
			push edi
			dec edi					; store the y position of the object in edi
			call moveObject, edi, 0	; 0 means decreasing
			pop edi
			jmp @@endTests
				
		@@moveDown:
			push edi
			dec edi					; store the y position of the object in edi
			call moveObject, edi, 1	; 1 means increasing
			pop edi
			jmp @@endTests
	
	@@return:
	ret
ENDP drawSprites



PROC moveObject
	ARG		@@data:dword, @@increase:byte
	USES	eax, ebx, ecx
	
	xor eax,eax
	xor ecx,ecx
	mov ebx, [@@data]		
	mov eax, [ebx]			; eax is the position that needs to be changed
	movzx ecx, [@@increase]	; ecx is the increasing boolean
	
	cmp ecx, 1
	je @@increaseValue
	
	cmp ecx, 0
	je @@decreaseValue
	
	jmp @@return
	
	@@increaseValue:
		add eax, 4
		mov [ebx], eax 		; replace the position with the new value
		jmp @@return
		
	@@decreaseValue:
		sub eax, 4
		mov [ebx], eax		; replace the position with the new value
		jmp @@return
		
	@@return:
	ret
ENDP moveObject

;; MAIN method

PROC main
	sti
	cld
	
	push ds
	pop	es
	
	call	setVideoMode,13h
	call	fillBackground, 0
	call __keyb_installKeyboardHandler
	
	@@menuloop:
		; Draw the menu
		call drawSprite, 0, 0, offset menu, offset screenBuffer
		call updateVideoBuffer, offset screenBuffer
		; Call the keyboard
		call	keyboardDuringMenu
		; Test to see if the game has started
		mov al, [offset gamestarted]
		cmp al, START
		je @@leavemenu ; if the game started, leave the menu
	
		jmp @@menuloop
	
		@@leavemenu:
			jmp @@gameloop ; jump to the game
	
	@@gameloop:
		call 	keyboardFunction
		call	fillBackground, 0
	
		; Draw Enemy
		call	getGamedataElement, ENEMY1XPOS
		mov eax, edx
		call	getGamedataElement, ENEMY1YPOS
		
		; Check lives left
		call 	getGamedataElement, CHARLIVES
		cmp edx, 0
		je @@returntomenu ; if lives = 0 return back to the menu
		
		call 	drawNSprites, 2, 2, edx, 2, offset heart
	
		call	drawBackground
	
		;call	drawSprite, 50, 100, offset stone, offset screenBuffer
	
		call	drawSprites, offset projectiles, offset stone
	
		; Draw character
		call handlePlayer
		; call testBoarders, offset character
		; call	getGamedataElement, CHARXPOS
		; mov eax, edx
		; call	getGamedataElement, CHARYPOS
		; call	drawSprite, eax, edx, offset character, offset screenBuffer
		; call	followChar, eax, edx
	
		call updateVideoBuffer, offset screenBuffer
		
		mov al, [gamestarted]
		cmp al, 0
		je @@returntomenu
	
		call 	wait_VBLANK, 1
	
		;; Jump back to the gameloop
		jmp @@gameloop
		
		
	@@returntomenu:
		call drawSprite, 0, 0, offset menu, offset screenBuffer
		call updateVideoBuffer, offset screenBuffer
		call setGamedataElement, CHARLIVES, 3 ; set lives to 3 again for the next game
		call selectOption, offset gamestarted, 0 ; set boolean equal to 0 again
		jmp @@menuloop	; jump back to the menu loop
	

	@@gameover:
		call __keyb_uninstallKeyboardHandler
		call terminateProcess
	
ENDP main

; -------------------------------------------------------------------
DATASEG
	gamestarted		db 0	; boolean to test if game has started

	menuoption		db 1	; holds the current menu option
	
	keybscancodes 	db 29h, 02h, 03h, 04h, 05h, 06h, 07h, 08h, 09h, 0Ah, 0Bh, 0Ch, 0Dh, 0Eh, 	52h, 47h, 49h, 	45h, 35h, 2FH, 4Ah
					db 0Fh, 10h, 11h, 12h, 13h, 14h, 15h, 16h, 17h, 18h, 19h, 1Ah, 1Bh, 		53h, 4Fh, 51h, 	47h, 48h, 49h, 		1Ch, 4Eh
					db 3Ah, 1Eh, 1Fh, 20h, 21h, 22h, 23h, 24h, 25h, 26h, 27h, 28h, 2Bh,    						4Bh, 4Ch, 4Dh
					db 2Ah, 00H, 2Ch, 2Dh, 2Eh, 2Fh, 30h, 31h, 32h, 33h, 34h, 35h, 36h,  			 48h, 		4Fh, 50h, 51h,  1Ch
					db 1Dh, 0h, 38h,  				39h,  				0h, 0h, 0h, 1Dh,  		4Bh, 50h, 4Dh,  52h, 53h
					
	playerlen		dw	3
					;	x-pos, y-pos, lives
	playerdata		dw	 150, 	170, 	3
	
	gamelen			dd	6	; length of gamedata array
	gamedata		dd	150 ; character x-position
					dd	170 ; character y-position
					dd 	3	; number of lives
					dd	100
					dd	80
					dd  0   ; number of projectiles alive
					
	projectiles		dw 10, 4
					; alive,xpos,ypos,direction
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0	
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0
					dw 0   ,0   ,0   ,0
					
	menu		dw 32, 25
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
					
	background	dw 32, 25
				db 06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,70H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,70H,70H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,70H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				db 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
	
	backgrounds	dw 32,25
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				db 02H, 03H, 08H, 07H, 02H, 04H, 04H, 04H, 54H, 04H, 05H, 04H, 64H, 04H, 04H, 04H, 54H, 04H, 45H, 04H, 04H, 04H, 05H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H
				
	character	dw 23, 25
				db 2FH,2FH,2FH,2FH,2FH,2FH,2FH,00H,00H,00H,00H,00H,00H,00H,00H,00H,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,2FH,2FH,2FH
				db 2FH,2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH,2FH
				db 2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH
				db 00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H
				db 00H,57H,57H,00H,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,00H,00H,57H,57H,00H
				db 00H,57H,00H,1FH,1FH,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,00H,1FH,1FH,00H,00H,00H,57H,00H
				db 00H,57H,00H,1FH,1FH,00H,00H,00H,57H,57H,00H,00H,00H,57H,57H,00H,1FH,1FH,00H,00H,00H,57H,00H
				db 00H,40H,00H,00H,00H,00H,00H,00H,57H,00H,00H,00H,00H,00H,57H,00H,00H,00H,00H,00H,00H,57H,00H
				db 00H,40H,40H,00H,00H,00H,00H,57H,57H,00H,1FH,1FH,1FH,00H,57H,57H,00H,00H,00H,00H,57H,57H,00H
				db 2FH,00H,40H,4EH,4EH,4EH,57H,57H,57H,00H,00H,00H,00H,00H,57H,57H,57H,4EH,4EH,4EH,57H,00H,2FH
				db 2FH,2FH,00H,4EH,4EH,4EH,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,4EH,4EH,4EH,00H,2FH,2FH
				db 2FH,2FH,2FH,00H,00H,4EH,4EH,57H,57H,57H,57H,57H,57H,57H,57H,57H,4EH,4EH,00H,00H,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,00H,00H,41H,41H,41H,41H,41H,41H,41H,41H,41H,00H,2FH,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,40H,40H,00H,00H,00H,00H,00H,00H,00H,00H,00H,40H,40H,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,57H,57H,57H,40H,40H,40H,40H,40H,40H,40H,40H,40H,57H,57H,57H,00H,2FH,2FH,2FH
				db 2FH,2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH,2FH
				db 2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH
				db 2FH,00H,57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,57H,57H,57H,00H,2FH
				db 2FH,00H,00H,40H,40H,00H,57H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,00H,40H,40H,00H,2FH,2FH
				db 2FH,2FH,2FH,00H,00H,00H,57H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,00H,00H,00H,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,2FH,00H,57H,57H,57H,57H,00H,57H,57H,57H,57H,00H,2FH,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,2FH,2FH,00H,57H,57H,57H,00H,57H,57H,57H,00H,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,00H,00H,00H,2FH,00H,00H,00H,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				
	heart		dw 10, 10
				db 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,04H,04H,2FH,2FH,04H,04H,2FH,2FH
				db 2FH,04H,04H,04H,04H,04H,04H,04H,04H,2FH
				db 2FH,04H,04H,04H,04H,04H,04H,04H,04H,2FH
				db 2FH,04H,04H,04H,04H,04H,04H,04H,04H,2FH
				db 2FH,2FH,04H,04H,04H,04H,04H,04H,2FH,2FH
				db 2FH,2FH,2FH,04H,04H,04H,04H,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,04H,04H,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				db 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				
	stone		dw 6,5
				db 2FH,00H,00H,00H,00H,2FH
				db 00H,18H,18H,18H,18H,00H
				db 00H,18H,18H,18H,18H,00H
				db 00H,18H,18H,18H,18H,00H
				db 2FH,00H,00H,00H,00H,2FH
				
; -------------------------------------------------------------------

; -------------------------------------------------------------------
UDATASEG
	palette		db 768 dup (?)
	
	screenBuffer db 64000 dup (?) 
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 12FH

END main