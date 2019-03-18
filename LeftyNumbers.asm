
!Scratchram_TileTable = $7F844B
 ;^[X bytes] A table containing strings of "characters"
 ; (more specifically digits). When using it with my 4/5 hexdec
 ; converter, it uses 5 bytes. The location depends on the value
 ; of X to write starting in this address (!Scratchram_TileTable+x).

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Left-aligned number display (single number). Useful for removing leading
;spaces in the digits (so if it tries to display [---3], it's displayed as
;[3***] where * indicates garbage (unwritten) bytes).
;
; Input:
;  -!DigitTable to !DigitTable+6 = a digit 0-9 per byte (used for 1-digit per
;   8x8 tile, using my 4/5 hexdec routine; ordered from high to low digits)
;  -X = the location within the table to place the string in.
; Output:
;  -!Scratchram_TileTable = A table containing a string of numbers with
;   unnecessary spaces and zeroes stripped out.
;  -X = the location to place string AFTER the numbers. Also use for
;   indicating the last digit (or any tile) number for how many tiles to
;   be written to the status bar, overworld border, etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
!DigitTable = $02		;\This routine relies on the HEX -> DEC
if !sa1 != 0			;|routine that uses a division routine.
	!DigitTable = $04	;|
endif				;/
LeftAlignedDigit:
	;Y index is used for searching until the first nonzero digit of a number
	;string. For example: 00123:
	;Y = 0, which is the leftmost digit, obtains a "0": [{0} 0  1  2  3]
	;Y = 1, which points to the second "0":             [ 0 {0} 1  2  3]
	;Y = 2, which points to the third digit "1"         [ 0  0 {1} 2  3]
	;Now it starts writing the subsequent digits after.
	
	LDY #$00			;>Start looking at the leftmost (highest) digit
	LDA #$00			;\When the value is 0, display it as single digit as zero
	STA !Scratchram_TileTable,x	;/(gets overwritten should nonzero input exist)

	.Loop
	LDA.w !DigitTable|!dp,Y			;\If there is a leading zero, move to the next digit to check without moving the position to
	BEQ ..NextDigit			;/place the tile in the table
	
	..FoundDigit
	LDA.w !DigitTable|!dp,Y			;\Place digit
	STA !Scratchram_TileTable,x	;/
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
;Convert to right-aligned digits. Best use if the number display is at least
;displaying two numbers (200/300), since displaying a single number is
;already right-aligned by default after calling the HEX -> DEC routine and
;after removing the leading zeroes.
;
;You must use this routine after calling LeftAlignedDigit as the removing
;leading zeros and "compressing" the string ([00200/00300] -> 200/300, not
;[  200/  300]) is needed.
;
; Input:
;  -X = the number of characters to place.
; Output:
;  -Carry:
;    CLEAR should there be an excessive number of characters.
;    SET when the number of characters is not exceeding Max8x8Write.
;  -Scratchram_CharacterTileTable: string containing right-aligned
;   characters.
;
; Assuming you have !Max8x8Write set to 11, you would have a space like
; like this: [+++++++++++], where each + is a byte and you want to display
; 200/300, it would be [++++200/300], thus !Scratchram_CharacterTileTable+4
; to Scratchram_CharacterTileTable+11 contains the desired digits.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RightAlignedDigit:
	LDA.b #!Scratchram_CharacterTileTable		;\Store address of the table
	STA $00						;|(<opcode>[$00],y means a "moveable table")
	LDA.b #!Scratchram_CharacterTileTable>>8	;|
	STA $01						;|
	LDA.b #!Scratchram_CharacterTileTable>>16	;|
	STA $02						;/
	DEX						;\Last character in $03 (also being the number of characters -1)
	STX $03						;/(if there are 3 digits (like 123, it would be 2, not 3), since the loop includes index = 0)
	STZ $04						;>Remove high byte

	REP #$20
	LDA $00						;>Starting position of the RAM table
	CLC						;\Go all the way to the end of the table
	ADC.w #!Max8x8Write-1				;/
	SEC						;\Move the "moveable table" to the left so that
	SBC $03						;/the last character is the last of the table (rightmost without exceed)
	CMP $00						;>If the number of characters was too long, carry clear to flag that it could write in locations BEFORE !Scratchram_CharacterTileTable.
	STA $00						;>Place "moveable table" starting here.
	SEP #$20
	BCC +
	PHX
	TXY					;\Transfer string to the right section of the table

	.Loop
	LDA !Scratchram_CharacterTileTable,x	;|
	STA [$00],y				;|
	DEY					;|
	DEX					;|
	BPL .Loop				;/
	PLX
	BCS
	+
	RTL