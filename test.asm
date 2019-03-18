!Scratchram_CharacterTileTable = $7F844B
 ;^[X bytes] A table containing strings of "characters"
 ; (more specifically digits). When using it with my 4/5 hexdec
 ; converter, it uses 5 bytes. The location depends on the value
 ; of X to write starting in this address (!Scratchram_CharacterTileTable+x).
 ;
 ; The number of bytes it uses is !Scratchram_CharacterTileTable + X + C
 ;
 ; X = index number at the highest
 ; C = number of characters to write at the highest

!StatusbarFormat = $02
 ;^Number of grouped bytes per 8x8 tile:
 ; $01 = Minimalist/SMB3 [TTTTTTTT, TTTTTTTT]...[YXPCCCTT, YXPCCCTT]
 ; $02 = Super status bar/Overworld border plus [TTTTTTTT YXPCCCTT, TTTTTTTT YXPCCCTT]...

if !sa1 == 0
 !StatusBarPos	= $7FA000
else
 !StatusBarPos	= $404032
endif
 ;^Status bar position to write. Redefineable.

!Max8x8Write = 7
 ;^Maximum number of 8x8 tiles to be written in decimal. Used when
 ; there is less written 8x8 tiles than the maximum to write blank tiles.
 ; This can be redefined for different counters.

!BlankTile = $FC
 ;^Tile number for where there is no characters to be written for each 8x8 space.

; Example code. Makes Mario crazy.
if read1($00FFD5) == $23	;\can be ommited if pre-included
	!Sa1 = 1
	sa1rom
else
	!Sa1 = 0
endif
!DigitTable = $02
if !Sa1 != 0
	!DigitTable = $04
endif
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

	
	
	.RemoveStatusBarGarbage
	LDX.b #(!Max8x8Write*!StatusbarFormat)-!StatusbarFormat		;\Remove leftover garbage. #(X*!StatusbarFormat)-!StatusbarFormat where X...
	LDA #!BlankTile							;|>#$FC is the blank tile to replace garbage

	..Loop								;|...is the highest number of 8x8 tiles to be written.
	STA !StatusBarPos,x						;|
	DEX #!StatusbarFormat						;|
	BPL ..Loop							;/
	
	.NumberTest
	REP #$20				;\Input 16-bit integer
	LDA $60					;|
	STA $00					;|
	SEP #$20				;/
	JSL HexDec_ConvertToDigits		;>Convert into decimal digits
	LDX #$00				;>Input the index position of the string table
	JSL LeftyNumbers_LeftAlignedDigit	;>Change the display to be left-aligned.
	LDA #$26				;>"/" symbol (not exist in vanilla SMW), feel free to change this number.
	STA !Scratchram_CharacterTileTable,x	;>Place after the last digit (so "300/")
	INX					;>First digit of the second number placed after the "/" (so 300/400)
	REP #$20				;\Same as above, but the second number.
	LDA $62					;|
	STA $00					;|
	SEP #$20				;/
	JSL HexDec_ConvertToDigits			;>Convert into decimal digits
	JSL LeftyNumbers_LeftAlignedDigit		;>Change the display to be left-aligned (no LDX #$00 so it continues where it left off.).
	JSL LeftyNumbers_RightAlignedDigit		;>Convert to right-aligned.
	BCC +

	.StatusBarWrite
	TXA					;\Index to use the right section of table for status bar
	CLC					;|
	ADC.b #!Max8x8Write-1			;|
	SEC					;|
	SBC $03					;|
	TAX					;/
	if !StatusbarFormat == 1 ;\Write to status bar. $03 = number of 8x8s to write a string -1.
		..Loop
		LDA !Scratchram_CharacterTileTable,x
		STA !StatusBarPos,x
		DEX
		DEC $03
		BPL ..Loop
	else
		ASL
		TAY

		..Loop
		LDA !Scratchram_CharacterTileTable,x
		PHX
		TYX
		STA !StatusBarPos,x
		PLX
		DEY #2
		DEX
		DEC $03
		BPL ..Loop
	endif
	+
	RTL
