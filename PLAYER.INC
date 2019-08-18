GLOBAL __keyb_installKeyboardHandler:PROC
GLOBAL __keyb_uninstallKeyboardHandler:PROC

GLOBAL __keyb_keyboardState:BYTE:128
GLOBAL __keyb_rawScanCode:BYTE
GLOBAL __keyb_keysActive:BYTE

GLOBAL	getPlayerData:PROC, \
		setPlayerData:PROC, \
		decreaseHealth:PROC, \
		resetPlayer:PROC
		
GLOBAL	vectorref:PROC, \
		vectorset:PROC
		
GLOBAL	shootProjectile:PROC, \
		deleteProjectile:PROC, \
		deleteAllProjectiles:PROC, \
		projectiles:WORD
		
GLOBAL	killEnemy:PROC, \
		deleteAllEnemies:PROC, \
		followChar:PROC, \
		enemiesFollow:PROC, \
		enemies:WORD