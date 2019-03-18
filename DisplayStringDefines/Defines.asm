;SA-1 detection (don't touch)
if defined("sa1") == 0
	!dp = $0000
	!addr = $0000
	!sa1 = 0
	!gsu = 0

	if read1($00FFD6) == $15
		sfxrom
		!dp = $6000
		!addr = !dp
		!gsu = 1
	elseif read1($00FFD5) == $23
		sa1rom
		!dp = $3000
		!addr = $6000
		!sa1 = 1
	endif
endif

;RAM locations
if !sa1 == 0
 !Scratchram_CharacterTileTable = $7F844A
else
 !Scratchram_CharacterTileTable = $400198
endif
 ;^[X bytes] A table containing strings of "characters"
 ; (more specifically digits). The number of bytes used
 ; is how many characters you would write.
 ; For example:
 ; -If you want to display a 5-digit 16-bit number 65535,
 ;  that will be 5 bytes.
 ; -If you want to display [10000/10000], that will be
 ;  11 bytes (there are 5 digits on each 10000, plus 1
 ;  because "/"; 5 + 5 + 1 = 11)

!StatusbarFormat = $02
 ;^Number of grouped bytes per 8x8 tile:
 ; $01 = Minimalist/SMB3 [TTTTTTTT, TTTTTTTT]...[YXPCCCTT, YXPCCCTT]
 ; $02 = Super status bar/Overworld border plus [TTTTTTTT YXPCCCTT, TTTTTTTT YXPCCCTT]...
 
!StatusBar_UsingCustomProperties           = 0
 ;^Set this to 0 if you are using the vanilla SMW status bar or any status bar patches
 ; that doesn't enable editing the tile properties, otherwise set this to 1 (you may
 ; have to edit "!Default_GraphicalBarProperties" in order for it to work though.).
 ; This define is needed to prevent writing what it assumes tile properties into invalid
 ; RAM addresses.

if !sa1 == 0
 !StatusBarPos = $7FA000
else
 !StatusBarPos = $404000
endif
 ;^Status bar position to write. Redefineable.

!BlankTile = $FC
 ;^Tile number for where there is no characters to be written for each 8x8 space.

!HexDecDigitTable = $02
if !sa1 != 0
	!HexDecDigitTable = $04
endif