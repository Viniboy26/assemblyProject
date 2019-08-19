IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

;;;; Includes

INCLUDE "sprites.inc"
INCLUDE "player.inc"

;;;;---------------------------------------------------------------------------------------------------

;;;; MACROS

; compile-time constants (with macros)
VMEMADR		EQU 0A002FH	; video memory address
SCRWIDTH	EQU 320		; screen width
SCRHEIGHT	EQU 200		; screen height
GAMEWIDTH	EQU 320
GAMEHEIGHT	EQU 150
INVWIDTH	EQU 320
INVHEIGHT	EQU 50

; Grid dimensions
GRIDWIDTH	EQU 32	; width of the grid
GRIDHEIGHT	EQU 25	; height of the grid

; Booleans
TRUE		EQU	1
FALSE		EQU 0

; Directions
STILL		EQU	0
LEFT		EQU 1
RIGHT		EQU 2
UP			EQU 3
DOWN		EQU 4

; character constants
CHARSPEED	EQU 4	
CHARWIDTH	EQU 25	; character width
CHARHEIGHT	EQU 25	; character height
CHARCOLOR	EQU 40 	; character color

; Indexes of character information in "playerdata" array
CHARXPOS	EQU 1	; character begin x-position
CHARYPOS	EQU 2	; character begin y-position
CHARLIVES	EQU 3 	; number of lives character has
CHARDIR		EQU 4	; character's direction
CHARSHOOT	EQU	5	; boolean, test if charater is shooting
CHARDMG		EQU	6	; character's damage towards enemies
CHARARMOR	EQU	7	; character's


; projectile constants
PROJSPEED 		EQU	7

; enemy constants
ENEMY1XPOS		EQU	50
ENEMY1YPOS		EQU	80
ENEMY2XPOS		EQU	220
ENEMY2YPOS		EQU	150
	
; Indexes of gamedata information in "projectiles" and "enemies" array
ELEMALIVE		EQU	1
ELEMXPOS		EQU	2
ELEMYPOS		EQU 3
ELEMDIR			EQU	4
ELEMCOLLISION	EQU	5
ELEMLIVES		EQU	6

; number of keys to track
KEYCNT EQU 89

; Menu options
START	EQU 1
EXIT	EQU 2

; Next or Prior option
PRIOR	EQU 0
NEXT	EQU	1

; Pause options
RESUME 	EQU	1
; EXIT EQU 2 is already defined

; Indexes of gamedata information in "objects" vector
PICKUPEFFECT	EQU	5	; effect that the object has upon picking it up
PICKUPROOM		EQU	6	; room that the object is in

; Effects of pickups
ARMOR		EQU	1
DMGBOOST	EQU	2

; Noticable rooms
STARTROOM		EQU	1
FINALBOSSROOM	EQU	8

;;;;---------------------------------------------------------------------------------------------------

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
	mov edi, offset screenBuffer
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
		sub edi, edx		; substract the width so edi is on the left	
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
	call collisionWithRoom
	
	; Set eax, ecx and edx equal to 0
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	
	call getPlayerData, CHARLIVES
	mov ecx, edx	; assign lives to ecx
	
	call getPlayerData, CHARXPOS
	mov eax, edx	; assign x-position to eax
	
	call getPlayerData, CHARYPOS	; assign y-position to edx
	
	; Draw the character
	call	drawSprite, eax, edx, offset character, offset screenBuffer
	
	; compare lives to 0
	cmp cx, 0
	jg @@stillAlive									; if lives > 0, the player is still alive, gamestarted does not need to be set to 0
	call selectOption, offset gamestarted, FALSE	; if lives = 0, set gamestarted to 0 which will return us to the menu
	jmp @@return									; after setting gamestarted to 0 return out of the function
	
	@@stillAlive:
	call 	drawNSprites, 2, 2, ecx, 2, offset heart ; draw remaining lives	
	
	@@return:
		ret	
ENDP handlePlayer

;;;;---------------------------------------------------------------------------------------------------

;; Final Boss management

PROC handleFinalBoss
	USES	eax, ebx, ecx, edx
	
	mov ebx, offset currentRoom
	cmp [ebx], FINALBOSSROOM
	jne	@@return	; if we are not in the final boss room then skip everything
	
	mov ebx, offset finalboss
	mov cx, [ebx]
	call vectorref, offset finalboss, ecx, ELEMXPOS
	mov eax, edx
	call vectorref, offset finalboss, ecx, ELEMYPOS
	mov ebx, edx
	call drawSprite, eax, ebx, offset character, offset screenBuffer
	
	@@return:
		ret
ENDP handleFinalBoss

;;;;---------------------------------------------------------------------------------------------------

;; Projectile collision management

; Test if a projectile collides with a block
PROC projectileCollisionWithBlock
	ARG		@@projectile:dword, @@blockXpos:word, @@blockYpos:word, @@sprite:dword, @@blockSprite:dword
	USES 	eax, ebx, ecx, edx, edi
	
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	xor edi, edi
	
	mov edi, [@@sprite]	; projectile
	mov cl, [edi]		; projectile width  (stored in ecx)
	
	; test if the charxpos + it's width is greater then the block's xpos
	call vectorref, offset projectiles, [@@projectile], ELEMXPOS
	add dl, cl				; edx is now the ELEMXPOS + it's width
	cmp dx, [@@blockXpos]		; ELEMXPOS + projwidth > blockXpos ?
	jg	@@test2
	jmp @@return
	
	; test if the ELEMXPOS is lesser then the block's xpos + the block's width
	@@test2:
	xor eax,eax
	mov ebx, [@@blockSprite]		; the block sprite is stored in ebx
	mov eax, [ebx]					; eax is now the block's width
	add ax, [@@blockXpos]			; eax is now the block's xpos + width
	call vectorref, offset projectiles, [@@projectile], ELEMXPOS
	cmp dx, ax
	jl @@test3
	jmp @@return
	
	; test if the ELEMYPOS + it's height is greater then the block's ypos
	@@test3:
	xor eax, eax
	mov al, [edi + 2]				; projectile-height (stored in eax)
	call vectorref, offset projectiles, [@@projectile], ELEMYPOS
	add dl, al					; edx is now the ELEMYPOS + it's height
	cmp dx, [@@blockYpos]
	jg @@test4
	jmp @@return
	
	; test if the ELEMYPOS is lesser then the block's ypos + the block's height
	@@test4:
	xor eax,eax
	mov eax, [ebx + 2]
	add ax, [@@blockYpos]
	call vectorref, offset projectiles, [@@projectile], ELEMYPOS
	cmp dx, ax
	jl @@collides
	jmp @@return
	
	@@collides:
		call deleteProjectile, [@@projectile]
		
	@@return:
		ret
ENDP projectileCollisionWithBlock
	
; Test if a projectile collides with the room
PROC projectileCollisionWithRoom
	ARG		@@projectile:dword
	USES 	eax, ebx, ecx, edx, edi, esi
	
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
			call projectileCollisionWithBlock, [@@projectile], eax, ebx, offset stone, offset horizontalWall
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
ENDP projectileCollisionWithRoom

; Test if projectile is out of border
PROC testProjectileBoarders
	ARG 	@@projectile:dword
	USES 	eax, ebx, ecx, edx, edi
	
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	xor edi, edi
	
	mov edi, offset stone	; projectile sprite
	mov cl, [edi]			; projectile-width  (stored in ecx)
	mov al, [edi + 2]		; projectile-height (stored in edx)
	
	call vectorref, offset projectiles, [@@projectile], ELEMXPOS
	cmp	dx, 0
	jl	@@deleteProjectile
	add dx, cx
	cmp dx, GAMEWIDTH
	jg @@deleteProjectile
	
	call vectorref, offset projectiles, [@@projectile], ELEMYPOS
	cmp edx, INVHEIGHT
	jl @@deleteProjectile
	add edx, eax
	cmp edx, SCRHEIGHT
	jg @@deleteProjectile
	
	jmp @@return	; if projectile was not out of border, return without deleting it
	
	@@deleteProjectile:
		call deleteProjectile, [@@projectile]
	
	@@return:
		ret
ENDP testProjectileBoarders

; Test collision for every projectile that is "alive"
PROC testProjectileCollision
	USES	ebx, ecx, edx
	
	mov ebx, offset projectiles
	xor ecx, ecx
	mov cx, [ebx]	; amount of projectiles
	
	; find every living projectile and test collision on them
	@@findProjectile:
		call vectorref, offset projectiles, ecx, ELEMALIVE
		cmp edx, FALSE
		je @@next	; if the projectile is dead, collision should not be tested
		call projectileCollisionWithRoom, ecx
		call testProjectileBoarders, ecx
		@@next:
		loop @@findProjectile
		
	@@return:
		ret
ENDP testProjectileCollision

;;;;---------------------------------------------------------------------------------------------------

;; Pickup collision management


; Test if a pickup is colliding with player
PROC pickupCollisionWithPlayer
	ARG		@@pickup:dword, @@playerXpos:dword, @@playerYpos:dword, @@sprite:dword, @@playerSprite:dword
	USES 	eax, ebx, ecx, edx, edi
	
	xor edi, edi
	xor ecx,ecx
	
	mov edi, [@@sprite]  ; pickup
	mov cl, [edi]        ; pickup's width
	
	; test if charxpos + width > pickup xpos
	call vectorref, offset pickups, [@@pickup], ELEMXPOS
	add dl, cl					; pickup xpos + width
	cmp edx, [@@playerXpos]
	jg @@test2
	jmp @@return
	
	; test if the pickupxpos is lesser then the player's xpos + width
	@@test2:
	xor eax,eax
	mov ebx, [@@playerSprite]		; the block sprite is stored in ebx
	mov eax, [ebx]					; eax is now the player's width
	add eax, [@@playerXpos]			; eax is now the player's xpos + width
	call vectorref, offset pickups, [@@pickup], ELEMXPOS
	cmp dx, ax
	jl @@test3
	jmp @@return
	
	; test if the pickup's ypos + it's height is greater then the player's ypos
	@@test3:
	xor eax, eax
	mov al, [edi + 2]				; player-height (stored in eax)
	call vectorref, offset pickups, [@@pickup], ELEMYPOS
	add dl, al					; edx is now the ELEMYPOS + it's height
	cmp edx, [@@playerYpos]
	jg @@test4
	jmp @@return
	
	; test if the ELEMYPOS is lesser then the block's ypos + the block's height
	@@test4:
	xor eax,eax
	mov eax, [ebx + 2]
	add eax, [@@playerYpos]
	call vectorref, offset pickups, [@@pickup], ELEMYPOS
	cmp dx, ax
	jl @@collides
	jmp @@return
	
	@@collides:
		xor edx,edx
		call vectorref, offset pickups, [@@pickup], PICKUPEFFECT
		cmp dx, ARMOR
		je @@armorPickup
		; It's a dmgboost pickup
		call dmgBoostPickedUp
		
		
		jmp @@pickItUp
		
	@@armorPickup:
	call armorPickedUp
		
	@@pickItUp:
		call vectorset, offset pickups, [@@pickup], ELEMALIVE, FALSE
	
	@@return:
	ret
ENDP pickupCollisionWithPlayer

;;;;---------------------------------------------------------------------------------------------------

;; Enemy collision management 

; Test if a enemy collides with a block
PROC enemyCollisionWithBlock
	ARG		@@enemy:dword, @@blockXpos:word, @@blockYpos:word, @@sprite:dword, @@blockSprite:dword
	USES 	eax, ebx, ecx, edx, edi
	
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	xor edi, edi
	
	mov edi, [@@sprite]	; enemy
	mov cl, [edi]		; enemy width  (stored in ecx)
	
	; test if the charxpos + it's width is greater then the block's xpos
	call vectorref, offset enemies, [@@enemy], ELEMXPOS
	add dl, cl				; edx is now the ELEMXPOS + it's width
	cmp dx, [@@blockXpos]		; ELEMXPOS + enemywidth > blockXpos ?
	jg	@@test2
	jmp @@return
	
	; test if the ELEMXPOS is lesser then the block's xpos + the block's width
	@@test2:
	xor eax,eax
	mov ebx, [@@blockSprite]		; the block sprite is stored in ebx
	mov eax, [ebx]					; eax is now the block's width
	add ax, [@@blockXpos]			; eax is now the block's xpos + width
	call vectorref, offset enemies, [@@enemy], ELEMXPOS
	cmp dx, ax
	jl @@test3
	jmp @@return
	
	; test if the ELEMYPOS + it's height is greater then the block's ypos
	@@test3:
	xor eax, eax
	mov al, [edi + 2]				; enemy-height (stored in eax)
	call vectorref, offset enemies, [@@enemy], ELEMYPOS
	add dl, al					; edx is now the ELEMYPOS + it's height
	cmp dx, [@@blockYpos]
	jg @@test4
	jmp @@return
	
	; test if the ELEMYPOS is lesser then the block's ypos + the block's height
	@@test4:
	xor eax,eax
	mov eax, [ebx + 2]
	add ax, [@@blockYpos]
	call vectorref, offset enemies, [@@enemy], ELEMYPOS
	cmp dx, ax
	jl @@collides
	jmp @@return
	
	@@collides:
		;call killEnemy, [@@enemy]
		
	@@return:
		ret
ENDP enemyCollisionWithBlock

PROC enemyCollisionWithProjectile
ENDP enemyCollisionWithProjectile

; Test collision for every enemy that is alive
PROC testEnemyCollision
	USES	ebx, ecx, edx
	
	mov ebx, offset enemies
	xor ecx, ecx
	mov cx, [ebx]	; amount of enemies
	
	; find every living enemy and test collision on them
	@@findEnemy:
		call vectorref, offset enemies, ecx, ELEMALIVE
		cmp edx, FALSE
		je @@next	; if the enemy is dead, collision should not be tested
		call projectileCollisionWithRoom, ecx
		call testProjectileBoarders, ecx
		@@next:
		loop @@findEnemy
		
	@@return:
		ret
ENDP testEnemyCollision

PROC enemiesMove
	USES	ebx, ecx, edx
	
	mov ebx, offset enemies
	xor ecx, ecx
	mov cx, [ebx]	; amount of enemies
	
	; find every living enemy and make them move
	@@findEnemy:
		call vectorref, offset enemies, ecx, ELEMALIVE
		cmp edx, FALSE
		je @@next	; if the enemy is dead, he does not move
		xor edx, edx
		call vectorref, offset enemies, ecx, ELEMDIR
		call moveObject, offset enemies, ecx, edx
		@@next:
		loop @@findEnemy
		
	@@return:
		ret
ENDP enemiesMove

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
		call deleteAllProjectiles
		push eax
		mov edi, offset currentRoom
		call getRoomDoorID, LEFT
		xor eax,eax
		mov al, dl
		mov [edi], al
		pop eax
		mov ebx, GAMEWIDTH
		sub ebx, ecx
		call setPlayerData, CHARXPOS, ebx
		jmp @@testYPOS
	
	@@setToRightScreen:
		call deleteAllProjectiles
		push eax
		mov edi, offset currentRoom
		call getRoomDoorID, RIGHT
		xor eax, eax
		mov al, dl
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
		call deleteAllProjectiles
		push eax
		mov edi, offset currentRoom
		call getRoomDoorID, UP
		xor eax,eax
		mov al, dl
		mov [edi], al
		pop eax
		mov ebx, SCRHEIGHT
		sub ebx, eax
		call setPlayerData, CHARYPOS, ebx
		jmp @@return
	
	@@setToBottomScreen:
		call deleteAllProjectiles
		mov edi, offset currentRoom
		call getRoomDoorID, DOWN
		xor eax,eax
		mov al, dl
		mov [edi], al
		call setPlayerData, CHARYPOS, INVHEIGHT
		jmp @@return
	
	@@return:
		ret
ENDP testBoarders

;;;;---------------------------------------------------------------------------------------------------

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

;;;;---------------------------------------------------------------------------------------------------

;; Pause management

; Determines what to do when a certain key is pressed while the game is paused
PROC keyboardDuringPause
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
		mov bl, [offset pauseoption]	; get the current pause option, then proceed to test which one it is
	
		cmp bl, RESUME
		je @@resumeGame
	
		cmp bl, EXIT
		je @@exit
	
		jmp @@return
	
	@@resumeGame:
		call resumeGame
		jmp @@return
	
	@@exit:
		call returnToMenu
		jmp @@return
	
	;;-----------------------------------------------
	
	; Other keys
	
	@@priorOption:
		mov bl, [offset pauseoption]
		cmp bl, RESUME	; test to see if we remain in amount of options boundary
		je @@return		; if our current option is the first one we can't go to the prior option
		call selectOption, offset pauseoption, 0
		jmp @@return
	
	@@nextOption:
		mov bl, [offset pauseoption]
		cmp bl, EXIT	; test to see if we remain in amount of options boundary
		je @@return		; if our current option is the last one we can't go to the next option
		call selectOption, offset pauseoption, 1
		jmp @@return
	
	@@return:
		ret
ENDP keyboardDuringPause

PROC returnToMenu
	call fillBackground, 12H
	call drawSprite, 140, 80, offset _start, offset screenBuffer
	call drawSprite, 140, 105, offset _exit, offset screenBuffer
	call updateVideoBuffer, offset screenBuffer
	call selectOption, offset gamepaused, FALSE
	call selectOption, offset gamestarted, FALSE
	call resetAll
	call wait_VBLANK, 5
	ret
ENDP returnToMenu

PROC resumeGame
	call selectOption, offset gamepaused, FALSE
	ret
ENDP resumeGame

PROC pauseGame
	call selectOption, offset gamepaused, TRUE
	ret
ENDP pauseGame


;;;;---------------------------------------------------------------------------------------------------

;; Menu management

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
		call selectOption, offset menuoption, PRIOR
		jmp @@return
	
	@@nextOption:
		mov bl, [offset menuoption]
		cmp bl, EXIT	; test to see if we remain in amount of options boundary
		je @@return		; if our current option is the last one we can't go to the next option
		call selectOption, offset menuoption, NEXT
		jmp @@return
	
	@@return:
		ret
ENDP keyboardDuringMenu

PROC selectOption
	ARG	@@darray:dword, @@option:byte ;  option = 0 or 1, according to if we want to de- or increase the value in darray
	USES eax, ebx, ecx
	
	xor ecx, ecx
	
	mov ebx, [@@darray]	; pointer to option
	mov cl, [ebx]		; option
	
	cmp [@@option], PRIOR
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
	call selectOption, offset gamestarted, TRUE
	ret
ENDP startGame

;;;;---------------------------------------------------------------------------------------------------

;; Keyboard management


; Determines what to do when a certain key is pressed during the game
PROC keyboardFunction
	
	USES	ebx, ecx
	mov ecx, KEYCNT	; amount of keys to process
	movzx ebx, [byte ptr offset keybscancodes + ecx - 1] ; get scancode

	; Test to see which key has been pressed
	
	; p button
	mov bl, [offset __keyb_keyboardState + 19h]	; obtain corresponding key state
	cmp bl, 1
	je @@pauseGame
	
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
	je @@shootProjectile
	
	; if spacebar isn't pressed, the player is not shooting
	call setPlayerData, CHARSHOOT, FALSE
	
	
	; If no key has been pressed, return without doing anything
	jmp @@return
	
	; Consequences according to pressed key
	
	@@pauseGame: 
		call pauseGame
		jmp @@return
	
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
	
	@@shootProjectile:
		call shootProjectile
		call setPlayerData, CHARSHOOT, TRUE
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

;; Drawing management


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

PROC handlePickups
	USES	eax, ebx, ecx, edx
	
	mov ebx, offset pickups
	xor ecx, ecx
	mov cx, [ebx]	; amount of pickups
	
	; find the pickups that are in the room we are in and draw them as long as they were not picked up yet
	@@findPickup:
		xor eax, eax
		xor ebx, ebx
		call vectorref, offset pickups, ecx, ELEMALIVE
		cmp	edx, FALSE
		je @@next
		call getPickupRoom, ecx		; the room in which the pickup is
		cmp dx, [offset currentRoom]
		jne @@next	; if the pickup is in another room, don't draw it
		jmp @@draw
		@@next:
			loop @@findPickup
			
	jmp @@return
			
	@@draw:
 		call vectorref, offset pickups, ecx, ELEMXPOS
		mov eax, edx									; store x-position of pickup in eax
		call vectorref, offset pickups, ecx, ELEMYPOS
		mov ebx, edx									; store y-position of pickup in ebx
		call getPickupEffect, ecx						; store effect of pickup in edx
		cmp edx, ARMOR
		je	@@drawArmor			
			push eax
			xor edx, edx
			call getPlayerData, CHARXPOS
			mov eax, edx
			call getPlayerData, CHARYPOS
			; Collide with the pickup
			call pickupCollisionWithPlayer, ecx, eax, edx, offset damageBoost, offset character
			pop eax
			call drawSprite, eax, ebx, offset damageBoost, offset screenBuffer
		jmp @@next
		@@drawArmor:		
			push eax
			xor edx, edx
			call getPlayerData, CHARXPOS
			mov eax, edx
			call getPlayerData, CHARYPOS
			; Collide with the pickup
			call pickupCollisionWithPlayer, ecx, eax, edx, offset armor, offset character
			pop eax
			call drawSprite, eax, ebx, offset armor, offset screenBuffer
			jmp @@next
			
	
		
	@@return:
		ret
ENDP handlePickups

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

PROC handleSprites
	ARG		@@data:dword, @@sprite:dword
	USES	eax, ebx, ecx, edx;, edi
	
	mov ebx, [@@data]	; pointer to array
	xor ecx, ecx
	mov cx, [ebx]		; amount of elements
	
	@@findElements:	; find the elements that need to be drawn and draw them
		call vectorref, [@@data], ecx, ELEMALIVE
		cmp edx, FALSE	; if the element isn't alive, don't do anything and skip to next element
		je @@nextElement
		xor eax, eax
		
		; get x- and y-position and draw the sprite
		call vectorref, [@@data], ecx, ELEMXPOS
		mov eax, edx
		call vectorref, [@@data], ecx, ELEMYPOS
		call drawSprite, eax, edx, [@@sprite], offset screenBuffer
		; after drawing the sprite, check direction and change x- and y-position accordingly for the next iteration
		call vectorref, [@@data], ecx, ELEMDIR
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
		
		jmp @@return ; once looped over all elements, return out of the function
		
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
	call vectorref, [@@array], [@@element], ELEMXPOS
	mov eax, edx
	; get the y-position which is stored in edx
	call vectorref, [@@array], [@@element], ELEMYPOS
	
	cmp [@@direction], STILL
	je @@return
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
		call vectorset, [@@array], [@@element], ELEMXPOS, ax
		jmp @@return
		
	@@moveRight:
		add ax, PROJSPEED
		call vectorset, [@@array], [@@element], ELEMXPOS, ax
		jmp @@return
		
	@@moveUp:
		sub dx, PROJSPEED
		call vectorset, [@@array], [@@element], ELEMYPOS, dx
		jmp @@return
		
	@@moveDown:
		add dx, PROJSPEED
		call vectorset, [@@array], [@@element], ELEMYPOS, dx
		jmp @@return
	
	@@return:
		ret
ENDP moveObject

;;;;---------------------------------------------------------------------------------------------------

;; Procedure to reset everything

PROC resetAll
	USES	ebx
	
	mov ebx, offset currentRoom
	mov [ebx], STARTROOM
	call resetPlayer
	ret
ENDP resetAll


;;;;---------------------------------------------------------------------------------------------------

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
		call fillBackground, 12H
		push eax
		xor eax,eax
		mov al, [offset menuoption]
		cmp al, START
		je @@drawStartRectangle
		
		cmp al, EXIT
		je @@drawExitRectangle
		
		@@drawStartRectangle:
			call drawRectangle, 138, 78, 35, 21, 07H
			jmp @@drawSprites
		
		@@drawExitRectangle:
			call drawRectangle, 138, 103, 35, 21, 07H
			
		jmp @@drawSprites
		
		@@drawSprites:
		pop eax
		call drawSprite, 140, 80, offset _start, offset screenBuffer
		call drawSprite, 140, 105, offset _exit, offset screenBuffer
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
	
		call	drawRoom, offset rooms
	
		call	handleSprites, offset projectiles, offset stone
		call	handleSprites, offset enemies, offset character
		
		; Handle everything concerning the pickups
		call	handlePickups
		
		; Handle everything concerning the final boss
		call	handleFinalBoss
		
		; Handle everything concerning the player
		call	handlePlayer
		
		call updateVideoBuffer, offset screenBuffer
		; test collision for every projectile and enemy
		call testProjectileCollision
		;call enemiesMove
		
		; test if we died and have to return to the menu
		mov al, [offset gamestarted] ; upon dying, gamestarted is set to 0
		cmp al, FALSE
		je @@returntomenu
		
		; test if we paused the game
		mov al, [offset gamepaused]
		cmp al, TRUE
		je @@pausegame
	
		call 	wait_VBLANK, 1
	
		;; Jump back to the gameloop
		jmp @@gameloop
		
		
	@@returntomenu:
		call returnToMenu 							; return to menu
		jmp @@menuloop								; jump back to the menu loop
		
	
	@@pausegame:
		call fillBackground, 12H	; delete everything
		push eax
		xor eax,eax
		mov al, [offset pauseoption]
		cmp al, 1
		je @@drawBackRectangle
		
		cmp al, 2
		je @@drawMenuRectangle
		
		@@drawBackRectangle:
			call drawRectangle, 138, 78, 35, 21, 07H
			jmp @@drawPauseSprites
		
		@@drawMenuRectangle:
			call drawRectangle, 138, 103, 35, 21, 07H
			
		jmp @@drawPauseSprites
		
		
		@@drawPauseSprites:
		pop eax
		call drawSprite, 140, 80, offset _back, offset screenBuffer
		call drawSprite, 140, 105, offset menu, offset screenBuffer
		call updateVideoBuffer, offset screenBuffer	; draw pause menu
		call keyboardDuringPause
		mov al, [offset gamepaused]
		cmp al, FALSE
		je @@gameloop	; if game isn't paused anymore, return to the game loop
		jmp @@pausegame	; jump back to the pause loop
	

	@@gameover:
		call __keyb_uninstallKeyboardHandler
		call terminateProcess
	
ENDP main

; -------------------------------------------------------------------
DATASEG
	currentRoom		dw 	STARTROOM	; room the player is in
	
	gamestarted		db 	FALSE	; boolean to test if game has started
	
	gamepaused		db 	FALSE	; boolean to test if the game is paused

	menuoption		db 	START	; holds the current menu option
	
	pauseoption		db 	RESUME	; holds the current pause option
	
	collwithEnemy	db	FALSE	; boolean to test if the player has collided with an enemy
	
	keybscancodes 	db 29h, 02h, 03h, 04h, 05h, 06h, 07h, 08h, 09h, 0Ah, 0Bh, 0Ch, 0Dh, 0Eh, 	52h, 47h, 49h, 	45h, 35h, 2FH, 4Ah
					db 0Fh, 10h, 11h, 12h, 13h, 14h, 15h, 16h, 17h, 18h, 19h, 1Ah, 1Bh, 		53h, 4Fh, 51h, 	47h, 48h, 49h, 		1Ch, 4Eh
					db 3Ah, 1Eh, 1Fh, 20h, 21h, 22h, 23h, 24h, 25h, 26h, 27h, 28h, 2Bh,    						4Bh, 4Ch, 4Dh
					db 2Ah, 00H, 2Ch, 2Dh, 2Eh, 2Fh, 30h, 31h, 32h, 33h, 34h, 35h, 36h,  			 48h, 		4Fh, 50h, 51h,  1Ch
					db 1Dh, 0h, 38h,  				39h,  				0h, 0h, 0h, 1Dh,  		4Bh, 50h, 4Dh,  52h, 53h
	

; -------------------------------------------------------------------
UDATASEG
	palette		db 768 dup (?)
	
	screenBuffer db 64000 dup (?) 
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 12FH

END main