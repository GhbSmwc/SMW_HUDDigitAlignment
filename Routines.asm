incsrc "../DisplayStringDefines/Defines.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;16-bit hex to 4 (or 5)-digit decimal subroutine
;Input:
;$00-$01 = the value you want to display
;Output:
;!HexDecDigitTable to !HexDecDigitTable+4 = a digit 0-9 per byte table (used for
; 1-digit per 8x8 tile):
; +$00 = ten thousands
; +$01 = thousands
; +$02 = hundreds
; +$03 = tens
; +$04 = ones
;
;!HexDecDigitTable is address $02 for normal ROM and $04 for SA-1.
;
;Note: Because SA-1's multiplication/division registers are signed,
;values over 32,767 ($7FFF) will glitch when you patch SA-1 on your
;game. So make it stop being in the SA-1 dimension (by only using the
;code before "else") if you are going to have values that large.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ConvertToDigits:
	if !sa1 == 0
		PHX
		PHY

		LDX #$04	;>5 bytes to write 5 digits.

		.Loop
		REP #$20	;\Dividend (in 16-bit)
		LDA $00		;|
		STA $4204	;|
		SEP #$20	;/
		LDA.b #10	;\base 10 Divisor
		STA $4206	;/
		JSR .Wait	;>wait
		REP #$20	;\quotient so that next loop would output
		LDA $4214	;|the next digit properly, so basically the value
		STA $00		;|in question gets divided by 10 repeatedly. [Value/(10^x)]
		SEP #$20	;/
		LDA $4216	;>Remainder (mod 10 to stay within 0-9 per digit)
		STA $02,x	;>Store tile

		DEX
		BPL .Loop

		PLY
		PLX
		RTL

		.Wait
		JSR ..Done		;>Waste cycles until the calculation is done
		..Done
		RTS
	else
		PHX
		PHY

		LDX #$04

		.Loop
		REP #$20		;>16-bit XY
		LDA.w #10		;>Base 10
		STA $02			;>Divisor (10)
		SEP #$20		;>8-bit XY
		JSL MathDiv		;>divide
		LDA $02			;>Remainder (mod 10 to stay within 0-9 per digit)
		STA.b !HexDecDigitTable,x	;>Store tile

		DEX
		BPL .Loop

		PLY
		PLX
		RTL
	endif
if !sa1 != 0
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 16bit / 16bit Division
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Arguments
	; $00-$01 : Dividend
	; $02-$03 : Divisor
	; Return values
	; $00-$01 : Quotient
	; $02-$03 : Remainder
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	MathDiv:	REP #$20
			ASL $00
			LDY #$0F
			LDA.w #$0000
	-		ROL A
			CMP $02
			BCC +
			SBC $02
	+		ROL $00
			DEY
			BPL -
			STA $02
			SEP #$20
			RTL
endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Left-aligned number display (single number). Useful for removing leading
;spaces in the digits (so if it tries to display [---3], it's displayed as
;[3***] where * indicates garbage (unwritten) bytes).
;
; Input:
;  -!HexDecDigitTable to !HexDecDigitTable+6 = a digit 0-9 per byte (used for 1-digit per
;   8x8 tile, using my 4/5 hexdec routine; ordered from high to low digits)
;  -X = the location within the table to place the string in.
; Output:
;  -!Scratchram_CharacterTileTable = A table containing a string of numbers with
;   unnecessary spaces and zeroes stripped out.
;  -X = the location to place string AFTER the numbers. Also use for
;   indicating the last digit (or any tile) number for how many tiles to
;   be written to the status bar, overworld border, etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LeftAlignedDigit:
	;Y index is used for searching until the first nonzero digit of a number
	;string. For example: 00123 with X = 0:
	;Y = 0, which is the leftmost digit, obtains a "0": [{0} 0  1  2  3]
	;      (X only increments after the first nonzero digit is found).
	;Y = 1, which points to the second "0":             [ 0 {0} 1  2  3]
	;Y = 2, which points to the third digit "1"         [ 0  0 {1} 2  3]
	;Now it starts writing the subsequent digits after (you must use
	;fixed-width font for proper viewing ASCII art here):
	;[ 0  0  1  2  3]
	;        |  |  |
	;  +-----+  |  |
	;  |  +-----+  |
	;  |  |  +-----+
	;  |  |  |
	;[ 1  2  3  *  *]
	;Each time it places a digit, it increments X to place the next digit.
	;Just before the routine ends, X increment +1 again after the last
	;character, in the example above with 00123 turning into 123, it
	;would be the first "*" (X = 3) for additional characters.
	LDY #$00			;>Start looking at the leftmost (highest) digit
	LDA #$00			;\When the value is 0, display it as single digit as zero
	STA !Scratchram_CharacterTileTable,x	;/(gets overwritten should nonzero input exist)

	.Loop
	LDA.w !HexDecDigitTable|!dp,Y	;\If there is a leading zero, move to the next digit to check without moving the position to
	BEQ ..NextDigit			;/place the tile in the table
	
	..FoundDigit
	LDA.w !HexDecDigitTable|!dp,Y	;\Place digit
	STA !Scratchram_CharacterTileTable,x	;/
	INX				;>Next string position in table
	INY				;\Next digit
	CPY #$05			;|
	BCC ..FoundDigit		;/
	RTL
	
	..NextDigit
	INY			;>1 digit to the right
	CPY #$05		;\Loop until no digits left (minimum is 1 digit)
	BCC .Loop		;/
	INX			;>Next item in table
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Write to Status bar/OWB+ (left aligned)
;
;Input:
; -$00-$02 = 24-bit address location to write to status bar tile number.
; -If tile properties are edit-able:
; --$03-$05 = Same as $00-$02 but tile properties.
; --$06 = the tile properties.
; -X = The number of characters to write, ("123" would have X = 3)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WriteToHUDLeftAligned:
	DEX
	TXY
	
	.Loop
	LDA !Scratchram_CharacterTileTable,x
	STA [$00],y
	if !StatusBar_UsingCustomProperties != 0
		LDA $06
		STA [$03],y
	endif
	DEX
	DEY
	BPL .Loop
	RTL
WriteToHUDLeftAlignedFormat2:
	DEX
	TXA				;\SSB and OWB+ uses a byte pair format.
	ASL				;|
	TAY				;/
	
	.Loop
	LDA !Scratchram_CharacterTileTable,x
	STA [$00],y
	if !StatusBar_UsingCustomProperties != 0
		LDA $06
		STA [$03],y
	endif
	DEX
	DEY #2
	BPL .Loop
	RTL