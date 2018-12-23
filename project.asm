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

; character speed
CHARSPEED	EQU 6

; Indexes of character information in "playerdata" array
CHARXPOS	EQU 1	; character begin x-position
CHARYPOS	EQU 2	; character begin y-position
CHARLIVES	EQU 3 	; number of lives character has
CHARDIR		EQU 4	; character's direction
ENEMY1XPOS	EQU	4
ENEMY1YPOS	EQU 5
CHARWIDTH	EQU 25	; character width
CHARHEIGHT	EQU 25	; character height
CHARCOLOR	EQU 40 	; character color
GRIdwIDTH	EQU 32	; width of the grid
GRIDHEIGHT	EQU 25	; height of the grid

; projectile speed
PROJSPEED 		EQU	7

; Indexes of projectile information in "projectiles" array
PROJALIVE		EQU	1
PROJXPOS		EQU	2
PROJYPOS		EQU 3
PROJDIRECTION	EQU	4
PROJCOLLISION	EQU	5


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
	;call collisionWithRoom
	
	; Set eax, ecx and edx equal to 0
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	
	mov ebx, offset playerdata	; pointer to player data
	mov ax, [ebx]				; assign x-position to ax
	
	add ebx, 2					; go to next element
	mov dx, [ebx]				; assign y-position to dx
	
	call collisionWithRoom
	;call collisionWithBlock, 64, 100, offset character, offset horizontalWall
	
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
;PROC getGamedataElement
;	ARG		@@index:dword	RETURNS	edx
;	USES	ebx, ecx
	
;	mov ebx, offset gamelen
;	mov ecx, [@@index]
	
;@@getToIndex:
;	add ebx, 4 	; go to next element
;	loop @@getToIndex ; loop until the correct index is reached
	
;	mov edx, [ebx]
;	ret	
;ENDP getGamedataElement

; Set an element from gamedata to a different value
;PROC setGamedataElement
;	ARG		@@index:dword, @@newvalue:dword
;	USES	ebx, ecx
	
;	mov ebx, offset gamelen
;	mov ecx, [@@index]
	
;@@getToIndex:
;	add ebx, 4	; go to next element
;	loop @@getToIndex ; loop until the correct index is reached
	
;	xchg ecx, [@@newvalue]
;	mov [ebx], ecx
;	ret
;ENDP setGamedataElement

; Decrease character's health by 1
PROC decreaseHealth
	USES edx
	
	call getPlayerData, CHARLIVES
	dec edx
	call setPlayerData, CHARLIVES, edx
	;call fillBackground, 0
	ret
ENDP decreaseHealth

;;;;---------------------------------------------------------------------------------------------------

;; Game data management

; Get the information from an element from an array containing game data
PROC vectorref
	ARG		@@array:dword, @@element: dword, @@information:dword	RETURNS	edx
	USES	ebx, ecx
	
	mov ebx, [@@array]
	add ebx, 2	; skip amount of elements
	mov ecx, [@@element]
	dec ecx
	cmp ecx, 0
	je @@elementzero
	
	@@getToElement:
		add ebx, 10 			; go to next element
		loop @@getToElement 	; loop until the correct element is reached
		
	@@elementzero:
	
	mov ecx, [@@information]
	
	@@getToInformation:
		add ebx, 2				; get to next piece of information
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
	add ebx, 2	; skip amount of elements
	mov ecx, [@@element]
	dec ecx
	cmp ecx, 0
	je @@elementzero
	
	@@getToElement:
		add ebx, 10 			; go to next element
		loop @@getToElement 	; loop until the correct element is reached
		
	@@elementzero:
	
	mov ecx, [@@information]
	
	@@getToInformation:
		add ebx, 2				; get to next piece of information
		loop @@getToInformation	; loop until the correct information is reached
	
	xor ecx, ecx
	xchg cx, [@@newvalue]
	mov [ebx], cx
	ret
ENDP vectorset

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
	
	sub dx, CHARSPEED	; otherwise decrease edx
	jmp @@return
	
	@@increase:
		add dx, CHARSPEED
	
	@@return:
		call setPlayerData, [@@POS], edx
		ret
ENDP moveCharacter

; Move to the right
PROC moveRight
	call moveCharacter, CHARXPOS, 1
	call setPlayerData, CHARDIR, RIGHT
	ret
ENDP moveRight

; Move to the left
PROC moveLeft
	call moveCharacter, CHARXPOS, 0
	call setPlayerData, CHARDIR, LEFT
	ret
ENDP moveLeft

; Move up
PROC moveUp
	call moveCharacter, CHARYPOS, 0
	call setPlayerData, CHARDIR, UP
	ret
ENDP moveUp

; Move down
PROC moveDown
	call moveCharacter, CHARYPOS, 1
	call setPlayerData, CHARDIR, DOWN
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
	jl	@@setToLeftScreen
	add dx, cx
	cmp dx, GAMEWIDTH
	jg @@setToRightScreen
	
	jmp @@testYPOS
	
	@@setToLeftScreen:
		push eax
		mov edi, offset currentRoom
		call getRoomDoorID, LEFT
		xor eax,eax
		xchg al, dl
		mov [edi], al
		pop eax
		mov ebx, GAMEWIDTH
		sub ebx, ecx
		call setPlayerData, CHARXPOS, ebx
		jmp @@testYPOS
	
	@@setToRightScreen:
		push eax
		mov edi, offset currentRoom
		call getRoomDoorID, RIGHT
		xor eax, eax
		xchg al, dl
		mov [edi], al
		pop eax
		mov ebx, GAMEWIDTH
		sub ebx, ecx
		call setPlayerData, CHARXPOS, 0
		jmp @@testYPOS
	
	@@testYPOS:
		call getPlayerData, CHARYPOS
		cmp edx, INVHEIGHT
		jl @@setToTopScreen
		add edx, eax
		cmp edx, SCRHEIGHT
		jg @@setToBottomScreen
	
		jmp @@return
	
	@@setToTopScreen:
		push eax
		mov edi, offset currentRoom
		call getRoomDoorID, UP
		xor eax,eax
		xchg al, dl
		mov [edi], al
		pop eax
		mov ebx, SCRHEIGHT
		sub ebx, eax
		call setPlayerData, CHARYPOS, ebx
		jmp @@return
	
	@@setToBottomScreen:
		mov edi, offset currentRoom
		call getRoomDoorID, DOWN
		xor eax,eax
		xchg al, dl
		mov [edi], al
		call setPlayerData, CHARYPOS, INVHEIGHT
		jmp @@return
	
	@@return:
		ret
ENDP testBoarders

;;;;---------------------------------------------------------------------------------------------------

;; Menu management

PROC selectOption
	ARG	@@darray:dword, @@option:byte ;  option = 0 or 1, according to if we want to de- or increase the value in darray
	USES eax, ebx, ecx
	
	xor ecx, ecx
	
	mov ebx, [@@darray]	; pointer to option
	mov cl, [ebx]		; option
	
	cmp [@@option], 0
	jg @@nextOption
	jmp @@priorOption
	
	@@nextOption:
		inc cl
		jmp @@setOption
	
	@@priorOption:
		dec cl
	
	@@setOption:
		xor eax, eax
		xchg al, cl
		mov [ebx], al
	
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
	call setPlayerData, CHARDIR, RIGHT
	call moveRight
	jmp @@return
	
@@moveLeft:
	call setPlayerData, CHARDIR, LEFT
	call moveLeft
	jmp @@return
	
@@moveUp:
	call setPlayerData, CHARDIR, UP
	call moveUp
	jmp @@return
	
@@moveDown:
	call setPlayerData, CHARDIR, DOWN
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

; PROC followChar
	; ARG @@xpos: dword, @@ypos: dword
	; USES edx
	
	; call getGamedataElement, ENEMY1XPOS
	
	; cmp edx, [@@xpos]
	; jl @@increasexpos ; Increase it's position if it's lesser 
	; jg @@decreasexpos ; Decrease it's position if it's greater
	
	; jmp @@ypostest
	
	; @@increasexpos:
		; inc edx
		; call setGamedataElement, ENEMY1XPOS, edx
		; jmp @@ypostest
	
	; @@decreasexpos:
		; dec edx
		; call setGamedataElement, ENEMY1XPOS, edx
		; jmp @@ypostest
	
	; @@ypostest:
		; call getGamedataElement, ENEMY1YPOS
		; cmp edx, [@@ypos]
		; jl @@increaseypos
		; jg @@decreaseypos
	
		; jmp @@return
	
	; @@increaseypos:
		; inc edx
		; call setGamedataElement, ENEMY1YPOS, edx
		; jmp @@return
	
	; @@decreaseypos:
		; dec edx
		; call setGamedataElement, ENEMY1YPOS, edx
		; jmp @@return
	
	; @@return:
		; ret		
; ENDP followChar

;-------------------------------------------------------------------------------------------------

; Room management

; store the the desired door (left, right, up, down) roomID in edx
PROC getRoomDoorID
	ARG  @@doorSide:byte RETURNS edx
	USES ebx, ecx
	
	xor ecx,ecx
	mov cx, [offset currentRoom]
	dec ecx
	
	mov ebx, offset rooms
	
	cmp cx, 0
	je @@room1
	
	@@getToRoomIndex:
		add ebx, 66
		loop @@getToRoomIndex
		
	@@room1:
	xor ecx,ecx
	mov cl, [@@doorSide]
	
	@@getToDoorSide:
		inc ebx
		loop @@getToDoorSide
		
	; now set the current room to the room linked with this door (stored in ebx)
	xor edx, edx
	mov dl, [ebx]

	ret
ENDP getRoomDoorID


PROC drawRoom
	ARG 	@@roomData:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
	xor ecx,ecx
	xor ebx,ebx
	xor eax,eax
	xor edi,edi
	xor esi,esi
	
	mov cx, [offset currentRoom]
	dec ecx					; store the id of the room you want to draw
	mov ebx,[@@roomData]
	
	cmp ecx, 0 
	je @@index0
	
	@@goToRoomIndex:
		add ebx, 66
		loop @@goToRoomIndex
		
	@@index0:
	
	mov edi, 50		; the y begin position of every room
	mov ecx, 6		; store the number of rows in ecx
	mov esi, 10		; store the number of cols in esi
	
	add ebx, 6		; move to the first room's sprite
	
	@@rowLoop:
		push esi	; save the cols
		xor eax,eax
		@@colLoop:
			push eax
			mov al, [ebx]	; The sprite that has to be drawn
			
			cmp al, 0
			je @@endcolLoop	; draw no sprite if 0
			
			cmp al, 1
			je @@drawHorWall	; draw horizontallWall if 1
			
			cmp al, 2
			je @@drawHorWall2
			
			cmp al, 3
			je @@drawFloor
			
			jmp @@endcolLoop
			
			@@drawHorWall:
				pop eax
				call drawSprite, eax, edi, offset horizontalWall, offset screenBuffer
				jmp @@endcolLoopIfDrawn
				
			@@drawHorWall2:
				pop eax
				call drawSprite, eax, edi, offset horizontalWall2, offset screenBuffer
				jmp @@endcolLoopIfDrawn
				
			@@drawFloor:
				pop eax
				call drawSprite, eax, edi, offset floor, offset screenBuffer
				jmp @@endcolLoopIfDrawn
			
			@@endcolLoop:
			pop eax
			@@endcolLoopIfDrawn:
			dec esi
			inc ebx
			add eax, 32		; get eax to the next sprite x position
			cmp esi, 0
			jg @@colLoop
		@@break:
		pop esi
		add edi, 25
		loop @@rowLoop
		
	ret
ENDP drawRoom

PROC collisionWithBlock
	ARG		@@blockXpos:word, @@blockYpos:word, @@sprite:dword, @@blockSprite:dword
	USES eax, ebx, ecx, edx, edi
	
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	xor edi, edi
	
	mov edi, [@@sprite]	; character
	mov cl, [edi]		; character-width  (stored in ecx)
	
	; test if the charxpos + it's width is greater then the block's xpos
	call getPlayerData, CHARXPOS
	add dl, cl				; edx is now the charxpos + it's width
	cmp dx, [@@blockXpos]		; charxpos + charwidth > blockXpos ?
	jg	@@test2
	jmp @@return
	
	; test if the charxpos is lesser then the block's xpos + the block's width
	@@test2:
	xor eax,eax
	mov ebx, [@@blockSprite]		; the block sprite is stored in ebx
	mov eax, [ebx]					; eax is now the block's width
	add ax, [@@blockXpos]			; eax is now the block's xpos + width
	call getPlayerData, CHARXPOS
	cmp dx, ax
	jl @@test3
	jmp @@return
	
	; test if the charypos + it's height is greater then the block's ypos
	@@test3:
	xor eax, eax
	mov al, [edi + 2]				; character-height (stored in eax)
	call getPlayerData, CHARYPOS
	add dl, al					; edx is now the charypos + it's height
	cmp dx, [@@blockYpos]
	jg @@test4
	jmp @@return
	
	; test if the charypos is lesser then the block's ypos + the block's height
	@@test4:
	xor eax,eax
	mov eax, [ebx + 2]
	add ax, [@@blockYpos]
	call getPlayerData, CHARYPOS
	cmp dx, ax
	jl @@collides
	jmp @@return
	
	@@collides:
		call getPlayerData, CHARDIR
		cmp dx, LEFT
		je @@setToRightOfBlock
	
		cmp dx, RIGHT
		je @@setToLeftOfBlock
	
		cmp dx, UP
		je @@setToBottomOfBlock
	
		cmp dx, DOWN
		je @@setToTopOfBlock
	
	jmp @@return
	
	; charxpos = block's xpos + block's width
	@@setToRightOfBlock:
		xor eax,eax
		mov eax, [ebx]					; eax is now the block's width
		add ax, [@@blockXpos]			; eax is now the blokc's xpos + width
		call setPlayerData, CHARXPOS, eax
		jmp @@return
		
	; charxpos = block's xpos - char's width
	@@setToLeftOfBlock:
		xor eax, eax
		mov ax, [@@blockXpos]
		sub ax, [edi]
		call setPlayerData, CHARXPOS, eax
		jmp @@return
		
	@@setToBottomOfBlock:
		xor eax, eax
		mov ax, [@@blockYpos]
		add ax, [edi + 2]
		call setPlayerData, CHARYPOS, eax
		jmp @@return
		
	@@setToTopOfBlock:
		xor eax, eax
		mov ax, [@@blockYpos]
		sub ax, [edi + 2]
		call setPlayerData, CHARYPOS, eax
		
	@@return:
		ret
ENDP collisionWithBlock
	

PROC collisionWithRoom
	USES eax, ebx, ecx, edx, edi, esi
	
	xor ecx,ecx
	xor ebx,ebx
	xor eax,eax
	xor edi,edi
	xor esi,esi
	
	mov cx, [offset currentRoom]	; index of the room that needs to be drawn
	dec ecx
	
	mov edi, offset rooms
	
	cmp ecx,0
	je @@index0
	
	@@goToRoomIndex:
		add edi, 66
		loop @@goToRoomIndex
		
	@@index0:
		
	mov ebx, 50		; the y begin position of every room
	mov ecx, 6		; store the number of rows in ecx
	mov esi, 10		; store the number of cols in esi
	
	add edi, 6		; move to the first room's sprite
	
	@@rowLoop:
		push esi	; save the cols
		xor eax,eax
		@@colLoop:
			push eax
			mov al, [edi]	; The sprite that has to be collided with or not
			
			cmp al, 0
			je @@noCollision	; no collision if there's no sprite
			
			cmp al, 3			; no collision if there's a floor
			je @@noCollision
			
			pop eax
			call collisionWithBlock, eax, ebx, offset character, offset horizontalWall
			jmp @@endcolLoopIfCollided
			
			@@noCollision:
			pop eax
			@@endcolLoopIfCollided:
			dec esi
			inc edi
			add eax, 32		; get eax to the next sprite x position
			cmp esi, 0
			jg @@colLoop
		@@break:
		pop esi
		add ebx, 25
		loop @@rowLoop
		
	ret
ENDP collisionWithRoom

PROC drawNSprites
	ARG		@@xpos:word, @@ypos:word, @@nSprites:word, @@gap:word, @@sprite:dword
	USES eax, ebx, ecx, edx, edi
	
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

PROC handleSprites
	ARG		@@data:dword, @@sprite:dword
	USES	eax, ebx, ecx, edx;, edi
	
	mov ebx, [@@data]	; pointer to array
	xor ecx, ecx
	mov cx, [ebx]		; amount of elements
	
	@@findElements:	; find the elements that need to be drawn and draw them
		call vectorref, [@@data], ecx, PROJALIVE
		cmp edx, 0	; if the element isn't alive, don't do anything and skip to next element
		je @@nextElement
		xor eax, eax
		
		; get x- and y-position and draw the sprite
		call vectorref, [@@data], ecx, PROJXPOS
		mov eax, edx
		call vectorref, [@@data], ecx, PROJYPOS
		call drawSprite, eax, edx, [@@sprite], offset screenBuffer
		; after drawing the sprite, check direction and change x- and y-position accordingly for the next iteration
		call vectorref, [@@data], ecx, PROJDIRECTION
		cmp edx, LEFT
		je @@moveLeft
		cmp edx, RIGHT
		je @@moveRight
		cmp edx, UP
		je @@moveUp
		cmp edx, DOWN
		je @@moveDown
		
		@@nextElement:
		loop @@findElements
		
		jmp @@return
		
		@@moveLeft:
			call moveObject, [@@data], ecx, LEFT
			jmp @@nextElement
			
		@@moveRight:
			call moveObject, [@@data], ecx, RIGHT
			jmp @@nextElement
		
		@@moveUp:
			call moveObject, [@@data], ecx, UP
			jmp @@nextElement
			
		@@moveDown:
			call moveObject, [@@data], ecx, DOWN
			jmp @@nextElement
		
	@@return:
		ret
		
ENDP handleSprites


PROC moveObject
	ARG		@@array:dword, @@element:dword, @@direction:byte
	USES 	eax, edx
	
	; store the x-position of the element in eax
	xor eax, eax
	call vectorref, [@@array], [@@element], PROJXPOS
	mov eax, edx
	; get the y-position which is stored in edx
	call vectorref, [@@array], [@@element], PROJYPOS
	
	cmp [@@direction], LEFT
	je @@moveLeft
	cmp [@@direction], RIGHT
	je @@moveRight
	cmp [@@direction], UP
	je @@moveUp
	cmp [@@direction], DOWN
	je @@moveDown
	
	@@moveLeft:
		sub ax, PROJSPEED
		call vectorset, [@@array], [@@element], PROJXPOS, ax
		jmp @@return
		
	@@moveRight:
		add ax, PROJSPEED
		call vectorset, [@@array], [@@element], PROJXPOS, ax
		jmp @@return
		
	@@moveUp:
		sub dx, PROJSPEED
		call vectorset, [@@array], [@@element], PROJYPOS, dx
		jmp @@return
		
	@@moveDown:
		add dx, PROJSPEED
		call vectorset, [@@array], [@@element], PROJYPOS, dx
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
		; call	getGamedataElement, ENEMY1XPOS
		; mov eax, edx
		; call	getGamedataElement, ENEMY1YPOS
		
		; Check lives left
		call 	getPlayerData, CHARLIVES
		cmp edx, 0
		je @@returntomenu ; if lives = 0 return back to the menu
		
		call 	drawNSprites, 2, 2, edx, 2, offset heart
	
		call	drawRoom, offset rooms
	
		;call	drawSprite, 50, 100, offset stone, offset screenBuffer
	
		call	handleSprites, offset projectiles, offset stone
	
		; Draw character
		call handlePlayer
	
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
		call setPlayerData, CHARLIVES, 6 ; set lives to 3 again for the next game
		call selectOption, offset gamestarted, 0 ; set boolean equal to 0 again
		jmp @@menuloop	; jump back to the menu loop
	

	@@gameover:
		call __keyb_uninstallKeyboardHandler
		call terminateProcess
	
ENDP main

; -------------------------------------------------------------------
DATASEG
	currentRoom		dw 1

	gamestarted		db 0
	
	menuoption		db 1

	keybscancodes 	db 29h, 02h, 03h, 04h, 05h, 06h, 07h, 08h, 09h, 0Ah, 0Bh, 0Ch, 0Dh, 0Eh, 	52h, 47h, 49h, 	45h, 35h, 2FH, 4Ah
					db 0Fh, 10h, 11h, 12h, 13h, 14h, 15h, 16h, 17h, 18h, 19h, 1Ah, 1Bh, 		53h, 4Fh, 51h, 	47h, 48h, 49h, 		1Ch, 4Eh
					db 3Ah, 1Eh, 1Fh, 20h, 21h, 22h, 23h, 24h, 25h, 26h, 27h, 28h, 2Bh,    						4Bh, 4Ch, 4Dh
					db 2Ah, 00H, 2Ch, 2Dh, 2Eh, 2Fh, 30h, 31h, 32h, 33h, 34h, 35h, 36h,  			 48h, 		4Fh, 50h, 51h,  1Ch
					db 1Dh, 0h, 38h,  				39h,  				0h, 0h, 0h, 1Dh,  		4Bh, 50h, 4Dh,  52h, 53h
					
	playerlen		dw	4
						;xpos	;ypos	;lives	;direction
	playerdata		dw	150, 	120, 	6, 		1
					
	gamelen			dd	6	; length of gamedata array
	gamedata		dd	150 ; character x-position
					dd	170 ; character y-position
					dd 	6	; number of lives
					dd	100
					dd	80
					dd  0   ; number of projectiles alive
					
	projectiles		dw 	10, 5	; amount of projectiles, information per projectile
							
					; alive, x-pos, y-pos,	direction,	collision?
					dw		0,	150,	  180,		1,			0
					dw		0,		0,		0,		0,			0
					dw		0,		0,		0,		0,			0
					dw		0,		0,		0,		0,			0
					dw		0,		0,		0,		0,			0
					dw		0,	   50,	   60,		2,			0
					dw		0,		0,		0,		0,			0
					dw		0,		0,		0,		0,			0
					dw		0,		0,		0,		0,			0
					dw		0,		0,		0,		0,			0
					
	background	DW 32, 25
				DB 06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,70H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,06H,06H,70H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,70H,70H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,70H,70H,70H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
				DB 06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H,06H
	
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
	
	character	DW 23, 25
				DB 2FH,2FH,2FH,2FH,2FH,2FH,2FH,00H,00H,00H,00H,00H,00H,00H,00H,00H,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,2FH,2FH,2FH
				DB 2FH,2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH,2FH
				DB 2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH
				DB 00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H
				DB 00H,57H,57H,00H,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,00H,00H,00H,57H,57H,00H
				DB 00H,57H,00H,1FH,1FH,00H,00H,00H,57H,57H,57H,57H,57H,57H,57H,00H,1FH,1FH,00H,00H,00H,57H,00H
				DB 00H,57H,00H,1FH,1FH,00H,00H,00H,57H,57H,00H,00H,00H,57H,57H,00H,1FH,1FH,00H,00H,00H,57H,00H
				DB 00H,40H,00H,00H,00H,00H,00H,00H,57H,00H,00H,00H,00H,00H,57H,00H,00H,00H,00H,00H,00H,57H,00H
				DB 00H,40H,40H,00H,00H,00H,00H,57H,57H,00H,1FH,1FH,1FH,00H,57H,57H,00H,00H,00H,00H,57H,57H,00H
				DB 2FH,00H,40H,4EH,4EH,4EH,57H,57H,57H,00H,00H,00H,00H,00H,57H,57H,57H,4EH,4EH,4EH,57H,00H,2FH
				DB 2FH,2FH,00H,4EH,4EH,4EH,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,4EH,4EH,4EH,00H,2FH,2FH
				DB 2FH,2FH,2FH,00H,00H,4EH,4EH,57H,57H,57H,57H,57H,57H,57H,57H,57H,4EH,4EH,00H,00H,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,00H,00H,41H,41H,41H,41H,41H,41H,41H,41H,41H,00H,2FH,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,40H,40H,00H,00H,00H,00H,00H,00H,00H,00H,00H,40H,40H,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,57H,57H,57H,40H,40H,40H,40H,40H,40H,40H,40H,40H,57H,57H,57H,00H,2FH,2FH,2FH
				DB 2FH,2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH,2FH
				DB 2FH,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,2FH
				DB 2FH,00H,57H,57H,57H,00H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,57H,00H,57H,57H,57H,00H,2FH
				DB 2FH,00H,00H,40H,40H,00H,57H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,00H,40H,40H,00H,2FH,2FH
				DB 2FH,2FH,2FH,00H,00H,00H,57H,57H,57H,57H,57H,00H,57H,57H,57H,57H,57H,00H,00H,00H,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,2FH,00H,57H,57H,57H,57H,00H,57H,57H,57H,57H,00H,2FH,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,2FH,2FH,00H,57H,57H,57H,00H,57H,57H,57H,00H,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,00H,00H,00H,2FH,00H,00H,00H,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				
	heart		DW 10, 10
				DB 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,04H,04H,2FH,2FH,04H,04H,2FH,2FH
				DB 2FH,04H,04H,04H,04H,04H,04H,04H,04H,2FH
				DB 2FH,04H,04H,04H,04H,04H,04H,04H,04H,2FH
				DB 2FH,04H,04H,04H,04H,04H,04H,04H,04H,2FH
				DB 2FH,2FH,04H,04H,04H,04H,04H,04H,2FH,2FH
				DB 2FH,2FH,2FH,04H,04H,04H,04H,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,04H,04H,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				DB 2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH,2FH
				
	horizontalWall	DW 32,25
					DB 08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H
					DB 08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H
					
	horizontalWall2	DW 32,25
					DB 16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H
					DB 16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
					DB 16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H
					
	topLeft		DW 32,25
				DB 16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H
				DB 16H,16H,16H,16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H
				DB 16H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,16H,16H,16H
				DB 16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,16H,16H,16H,16H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,16H,16H,16H,16H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,16H,16H,16H,16H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,16H,16H,16H,16H,07H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,16H,16H,16H,16H,07H,07H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,16H,16H,07H,07H,07H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,16H,16H,07H,07H,07H,07H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,16H,08H,08H,08H,08H,08H,08H,08H,08H
				DB 08H,08H,08H,08H,08H,08H,08H,08H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,08H,08H,08H,08H,08H,08H,08H,08H,08H,08H
				DB 08H,08H,08H,08H,08H,08H,16H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
				DB 07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
				DB 07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
				DB 16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H
				DB 07H,07H,07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H
				DB 07H,07H,07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
				DB 07H,07H,08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H
				DB 08H,08H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,07H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H
				DB 16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H,16H
				
	floor	DW 32,25
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
			DB 18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H,18H
					
	stone		DW 6,5
				DB 2FH,00H,00H,00H,00H,2FH
				DB 00H,18H,18H,18H,18H,00H
				DB 00H,18H,18H,18H,18H,00H
				DB 00H,18H,18H,18H,18H,00H
				DB 2FH,00H,00H,00H,00H,2FH
				
	rooms	DB 1, 0, 2, 0, 0, 0
			DB 1,2,1,2,1,2,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,3
			DB 2,3,3,3,3,3,3,3,3,3
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,2,1,2,1,2,1
			
			DB 2, 1, 0, 0, 5, 0
			DB 1,2,1,2,1,2,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 3,3,3,3,3,3,3,3,3,2
			DB 3,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,3,3,2,1,2,1
			
			DB 3, 0, 0, 0, 6, 0
			DB 1,2,1,2,1,2,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,3,3,1,2,1,1

			DB 4, 0, 5, 0, 7, 0
			DB 1,2,1,2,1,2,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,3
			DB 2,3,3,3,3,3,3,3,3,3
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,3,3,1,2,1,1

			DB 5, 4, 6, 2, 0, 0
			DB 1,2,1,2,3,3,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 3,3,3,3,3,3,3,3,3,3
			DB 3,3,3,3,3,3,3,3,3,3
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,2,1,2,1,2,1

			DB 6, 5, 0, 3, 9, 0
			DB 1,2,1,2,3,3,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 3,3,3,3,3,3,3,3,3,2
			DB 3,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,3,3,1,2,1,1

			DB 7, 0, 0, 4, 0, 0
			DB 1,2,1,2,3,3,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,2,1,2,1,2,1

			DB 8, 0, 9, 0, 0, 0
			DB 1,2,1,2,1,2,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,3
			DB 2,3,3,3,3,3,3,3,3,3
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,2,1,2,1,2,1

			DB 9, 8, 0, 6, 0, 0
			DB 1,2,1,2,3,3,1,2,1,2
			DB 2,3,3,3,3,3,3,3,3,1
			DB 3,3,3,3,3,3,3,3,3,2
			DB 3,3,3,3,3,3,3,3,3,1
			DB 1,3,3,3,3,3,3,3,3,2
			DB 2,1,2,1,2,1,2,1,2,1
				
				
	menu	dw 32, 25
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
; -------------------------------------------------------------------

; -------------------------------------------------------------------
UDATASEG
	palette		db 768 dup (?)
	
	screenBuffer db 64000 dup (?) 
	
	currentPlayerSprite db 579 dup(?)
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 12FH

END main
