;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;16-bit hex to 4 (or 5)-digit decimal subroutine
;Input:
;$00-$01 = the value you want to display
;Output:
;!DigitTable to !DigitTable+4 = a digit 0-9 per byte table (used for
; 1-digit per 8x8 tile):
; +$00 = ten thousands
; +$01 = thousands
; +$02 = hundreds
; +$03 = tens
; +$04 = ones
;
;!DigitTable is address $02 for normal ROM and $04 for SA-1.
;
;Note: Because SA-1's multiplication/division registers are signed,
;values over 32,767 ($7FFF) will glitch when you patch SA-1 on your
;game. So make it stop being in the SA-1 dimension (by only using the
;code before "else") if you are going to have values that large.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if read1($00FFD5) == $23	;\can be omitted if pre-included
	!Sa1 = 1
	sa1rom
else
	!Sa1 = 0
endif				;/

!DigitTable = $02		;\This is due to if you are using SA-1,
if !Sa1 != 0			;|it had to use an unsigned 16-bit integer, since
	!DigitTable = $04	;|SA-1 multiplication/division register are signed.
endif				;/
	
ConvertToDigits:
	if !Sa1 == 0
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
		STA.b !DigitTable,x	;>Store tile

		DEX
		BPL .Loop

		PLY
		PLX
		RTL
	endif

if !Sa1 != 0
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