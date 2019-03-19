incsrc "../DisplayStringDefines/Defines.asm"

!MaxChar	= 5
 ;^Max number of characters to write, also how many tiles to clear
 ; so that no leftover tiles appear when it should disappear.
 ; i.e "65535/65535" is 11 characters.
!AlignMode	= 1
 ;0 = left-aligned
 ;1 = right-aligned

if !AlignMode == 0
 if !sa1 == 0
  !StatusBarPos = $7FA000
 else
  !StatusBarPos = $404000
 endif
else
 if !sa1 == 0
  !StatusBarPos = $7FA03E
 else
  !StatusBarPos = $40403E
 endif
endif
 ;^Status bar position to write. When left-aligned, this represents the first tile address,
 ; if right-aligned, this is the last tile position (will occupy tiles this and BEFORE it).

main:

	LDA $15
	BIT.b #%00001000
	BNE .Up
	BIT.b #%00000100
	BNE .Down
	BRA +
	
	.Up
	REP #$20
	LDA $60
	INC A
	STA $60
	SEP #$20
	BRA +
	
	.Down
	REP #$20
	LDA $60
	DEC A
	STA $60
	SEP #$20
	
	+
	
	LDA $15
	BIT.b #%00000001
	BNE .Left
	BIT.b #%00000010
	BNE .Right
	BRA +
	
	.Left
	REP #$20
	LDA $62
	INC A
	STA $62
	SEP #$20
	BRA +
	
	.Right
	REP #$20
	LDA $62
	DEC A
	STA $62
	SEP #$20
	
	+
	
	.StatusBarRemoveFrozenTiles
	LDA #$FC
	LDX.b #(!MaxChar-1)*!StatusbarFormat
	-
	if !AlignMode == 0
		STA !StatusBarPos,x
	else
		STA !StatusBarPos-((!MaxChar-1)*!StatusbarFormat),x
	endif
	DEX #2
	BPL -
	
	.WriteStatusBar
	LDA $60 : STA $00			;\First number HEX->DEC
	LDA $61 : STA $01			;|
	JSL Routines_ConvertToDigits		;/
	LDX #$00				;>Initialize string position
	JSL Routines_SupressLeadingZeros		;>Place only the necessary digits in the string table
	LDA #$26				;\The number separator (its "X" by default, acting as a "/")
	STA !Scratchram_CharacterTileTable,x	;/
	INX					;>Increment X to write next number preceding it
	LDA $62 : STA $00			;\Do the same thing as above, this time without initalizing X
	LDA $63 : STA $01			;|so that it places the second number after the "/".
	JSL Routines_ConvertToDigits		;|
	JSL Routines_SupressLeadingZeros	;/
	CPX.b #!MaxChar+1			;\If there are more characters than the max, skip status bar write.
	BCS ..TooMuch				;/
	LDA.b #!StatusBarPos : STA $00		;\Set address to write at a given status bar position.
	LDA.b #!StatusBarPos>>8 : STA $01	;|
	LDA.b #!StatusBarPos>>16 : STA $02	;/
	if !AlignMode != 0
		if !StatusbarFormat == $01				;\These offset the write position based on how many
			JSL Routines_ConvertToRightAligned		;|characters so that it is right-aligned.
		else
			JSL Routines_ConvertToRightAlignedFormat2	;|
		endif							;/
	endif
	if !StatusbarFormat == $01					;\Write to status bar
		JSL Routines_WriteStringDigitsToHUD			;|
	else
		JSL Routines_WriteStringDigitsToHUDFormat2		;|
	endif								;/
	..TooMuch
	RTL