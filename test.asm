incsrc "../DisplayStringDefines/Defines.asm"
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
	LDX.b #(5-1)*2
	-
	STA !StatusBarPos,x
	DEX #2
	BPL -
	
	
	LDA $60 : STA $00
	LDA $61 : STA $01
	JSL Routines_ConvertToDigits
	LDX #$00
	JSL Routines_LeftAlignedDigit
	LDA.b #!StatusBarPos : STA $00
	LDA.b #!StatusBarPos>>8 : STA $01
	LDA.b #!StatusBarPos>>16 : STA $02
	JSL Routines_WriteToHUDLeftAlignedFormat2
	RTL