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
;game. Therefore, I added a Sa-1 detection to use an unsigned division
;as the SNES registers become inaccessible on SA-1 mode.
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
	; unsigned 16bit / 16bit Division
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
;Suppress Leading zeros via left-aligned positioning
;
;This routines takes a 16-bit unsigned integer (works up to 5 digits),
;suppress leading zeros and moves the digits so that the first non-zero
;digit number is located where X is indexed to. Example: the number 00123
;with X = $00:
;
; [0] [0] [1] [2] [3]
;
; Each bracketed item is a byte storing a digit. The X above means the X
; index position.
; After this routine is done, they are placed in an address defined
; as "!Scratchram_CharacterTileTable" like this:
;
;              X
; [1] [2] [3] [*] [*]...
;
; [*] Means garbage and/or unused data. X index is now set to $03, shown
; above.
;
;Usage:
; Input:
;  -!HexDecDigitTable to !HexDecDigitTable+4 = a 5-digit 0-9 per byte (used for
;   1-digit per 8x8 tile, using my 4/5 hexdec routine; ordered from high to low digits)
;  -X = the location within the table to place the string in.
; Output:
;  -!Scratchram_CharacterTileTable = A table containing a string of numbers with
;   unnecessary spaces and zeroes stripped out.
;  -X = the location to place string AFTER the numbers. Also use for
;   indicating the last digit (or any tile) number for how many tiles to
;   be written to the status bar, overworld border, etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SupressLeadingZeros:
	LDY #$00				;>Start looking at the leftmost (highest) digit
	LDA #$00				;\When the value is 0, display it as single digit as zero
	STA !Scratchram_CharacterTileTable,x	;/(gets overwritten should nonzero input exist)

	.Loop
	LDA.w !HexDecDigitTable|!dp,Y		;\If there is a leading zero, move to the next digit to check without moving the position to
	BEQ ..NextDigit				;/place the tile in the table
	
	..FoundDigit
	LDA.w !HexDecDigitTable|!dp,Y		;\Place digit
	STA !Scratchram_CharacterTileTable,x	;/
	INX					;>Next string position in table
	INY					;\Next digit
	CPY #$05				;|
	BCC ..FoundDigit			;/
	RTL
	
	..NextDigit
	INY			;>1 digit to the right
	CPY #$05		;\Loop until no digits left (minimum is 1 digit)
	BCC .Loop		;/
	INX			;>Next item in table
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Convert left-aligned to right-aligned.
;
;Use this routine after calling SupressLeadingZeros and before calling
;WriteStringDigitsToHUD. Note: Be aware that the math of handling the address
;does NOT account to changing the bank byte (address $XX****), so be aware of
;having status bar tables that crosses bank borders ($7EFFFF, then $7F0000,
;as an made-up example, but its unlikely though).
;
;Input:
; -$00-$02 = 24-bit address location to write to status bar tile number.
; -If tile properties are edit-able:
; --$03-$05 = Same as $00-$02 but tile properties.
; --$06 = the tile properties.
; -X = The number of characters to write, ("123" would have X = 3)
;Output:
; -$00-$02 and $03-$05 are subtracted by [(NumberOfCharacters-1)*!StatusbarFormat]
;  so that the last character is always at a fixed location and as the number
;  of characters increase, the string would extend leftwards. Therefore,
;  $00-$02 and $03-$05 before calling this routine contains the ending address
;  which the last character will be written.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ConvertToRightAligned:
	TXA
	DEC
	TAY					;>Transfer status bar leftmost position to Y
	BRA +
ConvertToRightAlignedFormat2:
	TXA
	DEC
	ASL
	TAY					;>Transfer status bar leftmost position to Y
	+
	REP #$21				;\-(NumberOfTiles-1)...
	AND #$00FF				;|
	EOR #$FFFF				;|
	INC A					;/
	ADC $00					;>...+LastTilePos (we are doing LastTilePos - (NumberOfTiles-1))
	STA $00					;>Store difference in $00-$01
	SEP #$20				;\Handle bank byte
;	LDA $02					;|
;	SBC #$00				;|
;	STA $02					;/
	
	if !StatusBar_UsingCustomProperties != 0
		TYA
		DEC
		ASL
		REP #$21				;\-(NumberOfTiles-1)
		AND #$00FF				;|
		EOR #$FFFF				;|
		INC A					;/
		ADC $03					;>+LastTilePos (we are doing LastTilePos - (NumberOfTiles-1))
		STA $03					;>Store difference in $00-$01
		SEP #$20				;\Handle bank byte
;		LDA $05					;|
;		SBC #$00				;|
;		STA $05					;/
	endif
	RTL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Write aligned digits to Status bar/OWB+
;
;Input:
; -$00-$02 = 24-bit address location to write to status bar tile number.
; -If tile properties are edit-able:
; --$03-$05 = Same as $00-$02 but tile properties.
; --$06 = the tile properties.
; -X = The number of characters to write, ("123" would have X = 3)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WriteStringDigitsToHUD:
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
WriteStringDigitsToHUDFormat2:
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