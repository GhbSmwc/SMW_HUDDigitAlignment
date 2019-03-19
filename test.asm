incsrc "../DisplayStringDefines/Defines.asm"

!MaxChar	= 11
 ;^Max number of characters to write, also how many tiles to clear
 ; so that no leftover tiles appear when it should disappear.
 ; i.e "65535/65535" is 11 characters.
!AlignMode	= 0
 ;0 = left-aligned
 ;1 = right-aligned

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
	LDA $60 : STA $00
	LDA $61 : STA $01
	JSL Routines_ConvertToDigits
	LDX #$00
	JSL Routines_LeftAlignedDigit
	LDA #$26
	STA !Scratchram_CharacterTileTable,x
	INX
	LDA $62 : STA $00
	LDA $63 : STA $01
	JSL Routines_ConvertToDigits
	JSL Routines_LeftAlignedDigit
	LDA.b #!StatusBarPos : STA $00
	LDA.b #!StatusBarPos>>8 : STA $01
	LDA.b #!StatusBarPos>>16 : STA $02
	if !AlignMode != 0
		if !StatusbarFormat == $01
			JSL Routines_ConvertToRightAligned
		else
			JSL Routines_ConvertToRightAlignedFormat2
		endif
	endif
	if !StatusbarFormat == $01
		JSL Routines_WriteToHUDLeftAligned
	else
		JSL Routines_WriteToHUDLeftAlignedFormat2
	endif
	RTL