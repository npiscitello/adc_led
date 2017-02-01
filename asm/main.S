; Nick Piscitello
; January 2017
; Atmel ATMEGA328P-PU
; avr-gcc 4.3.3 (WinAVR 20100110)

; I apologize for the stupidly verbose comments; this is my first foray into assembler and I intend
; on using this file as a reference for future projects

; the interrupt table is handled automatically by the compiler using the macros defined in 
; 'avr/ioXXX.h' as the subroutine labels AS LONG AS those labels are declared '.global'.

#include <avr/io.h>

;=== REGISTER MAP ===;
; r16: temporary working reg
#define TEMP r16
; r17: minimum LED for chase sequence
#define MIN r17
; r18: maximimum LED for chase sequence
#define MAX r18
; r19: current LED lit
#define LOC r19
; r20: LED direction (1 for ascending, 0 for descending)
#define DIR r20
#define ASC 0x01
#define DSC 0x00
; r21: ADC value to be written to output compare
#define ADC r21

;=== UTILITY MACROS ===;
#define low(x) ((x) & 0xFF)
#define high(x) (((x) >> 8) & 0xFF)

; run when the chip resets
.global main
main:
  ; divide system clock by 64 (I would prescale it down by 256 but the ADC needs at least 100kHz)
  ; this gives a system clock speed of 8 MHz / 64 = 125 kHz
  ; TESTED - the ADC problem is NOT clock-related
  ldi TEMP,0x00 | _BV(CLKPCE)
  sts CLKPR,TEMP
  ldi TEMP, 0x00 | _BV(CLKPS2) | _BV(CLKPS1)
  sts CLKPR,TEMP

  ; enable output pins
  ldi TEMP,0x00 | _BV(DDB5) | _BV(DDB4) | _BV(DDB3) | _BV(DDB2) | _BV(DDB1) | _BV(DDB0)
  out _SFR_IO_ADDR(DDRB),TEMP

  ; set min and max for LED chase and initialize location to min LED
  clr MIN
  clr MAX
  clr LOC
  clr DIR
  ldi MIN,_BV(PORTB0)
  ldi MAX,_BV(PORTB5)
  mov LOC,MIN
  ldi DIR,ASC

  ; power on the features we are using
  ; TESTED - the timer is NOT interfereing with the ADC
  lds TEMP,PRR
  cbr TEMP,PRTIM0
  cbr TEMP,PRADC
  sts PRR,TEMP

  ; set stack pointer to the end of RAM (required for returning from interrupts)
  ldi TEMP,low(RAMEND)
  sts SPL,TEMP
  ldi TEMP,high(RAMEND)
  sts SPH,TEMP

  ; set up the timer/counter 0 mode (CTC)
  ldi TEMP,0x00 | _BV(WGM01)
  sts TCCR0A,TEMP

  ; set up the timer/counter 0 clock source (sys / 1024)
  ldi TEMP, 0x00 | _BV(CS02) | _BV(CS00)
  sts TCCR0B,TEMP

  ; clear pending interrupts
  ldi TEMP,0x00 | _BV(TOV0)
  out TIFR0,TEMP

  ; enable timer/counter 0 output compare A interrupt
  ldi TEMP,0x00 | _BV(OCIE0A)
  sts TIMSK0,TEMP

  ; set up ADC voltage reference and input pin
  lds TEMP,ADMUX  ; load ADMUX into TEMP
  cbr TEMP,REFS1  ; enable internal voltage ref
  sbr TEMP,REFS0  ; enable internal voltage ref
  cbr TEMP,MUX3   ; set ADC0 as the ADC pin
  cbr TEMP,MUX2   ; set ADC0 as the ADC pin
  cbr TEMP,MUX1   ; set ADC0 as the ADC pin
  cbr TEMP,MUX0   ; set ADC0 as the ADC pin
  sbr TEMP,ADLAR  ; left adjust result for 8-bit precision
  sts ADMUX,TEMP  ; set ADMUX to TEMP

  ; set up ADC trigger source
  lds TEMP,ADCSRB ; load ADCSRB into TEMP
  cbr TEMP,ADTS2  ; select ADC interrupt as trigger source
  cbr TEMP,ADTS1  ; select ADC interrupt as trigger source
  cbr TEMP,ADTS0  ; select ADC interrupt as trigger source
  sts ADCSRB,TEMP ; set ADCSRB to TEMP

  ; set up ADC clocking and triggering, enable ADC
  lds TEMP,ADCSRA ; load ADCSRA into TEMP
  sbr TEMP,ADEN   ; enable ADC
  cbr TEMP,ADPS2  ; divide system clock by 2 (62.5 kHz)
  cbr TEMP,ADPS1  ; divide system clock by 2 (62.5 kHz)
  sbr TEMP,ADPS0  ; divide system clock by 2 (62.5 kHz)
  sbr TEMP,ADATE  ; enable auto trigger
  sbr TEMP,ADIE   ; enable ADC interrupts
  sbr TEMP,ADIF   ; clear pending ADC interrupts
  sbr TEMP,ADSC   ; trigger first read
  sts ADCSRA,TEMP ; set ADCSRA to TEMP

  sei             ; globally enable interrupts
  out _SFR_IO_ADDR(PORTB),LOC   ; start at minimum LED
  rjmp loop       ; jump into infinite loop

; infinite loop. I guess this could be a sleep maybe?
loop:
  ;lds ADC,ADCH    ; read the ADC value
  ;ldi ADC,0xFF    ; test that the timer works correctly
  ;sts OCR0A,ADC   ; write it to the timer compare value
  rjmp loop       ; loop infinitely

; run when the ADC finishes a conversion
.global ADC_vect
ADC_vect:
  ;lds ADC,ADCH   ; set the output compare for timer 0 to the ADC value
;  ldi ADC,0x00
;  sts OCR0A,ADC  ; set the output compare for timer 0 to the ADC value
;  reti            ; return from ISR

; run when timer/counter0 matches OCR0A
;.global TIMER0_COMPA_vect
;TIMER0_COMPA_vect:
  cpi DIR,ASC     ; compare the direction reg with the ascend direction constant...
  breq ascend     ; ...and skip to the ascend code if they're equal...
  rjmp descend    ; ...or to the descend code if they're not.

ascend:
  lsl LOC         ; increment LED location (originally used rol, but it screwed up the compare
  out _SFR_IO_ADDR(PORTB),LOC   ; write LED location out
  cpse LOC,MAX    ; compare the location to the max location...
  reti            ; ...and skip this instruction if they're the same.
  ldi DIR,DSC     ; reverse direction
  reti            ; return from ISR

descend:
  lsr LOC         ; decrement LED location (originally used ror, but it screwed up the compare)
  out _SFR_IO_ADDR(PORTB),LOC   ; write LED location out
  cpse LOC,MIN    ; compare the current location with the min location...
  reti            ; ...and skip this instruction if they're the same.
  ldi DIR,ASC     ; reverse direction
  reti            ; return from ISR
