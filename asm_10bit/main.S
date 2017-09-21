; Nick Piscitello
; January 2017
; Atmel ATMEGA328P-PU
; avr-gcc 4.3.3 (WinAVR 20100110)
; fuses: default (l: 0x62, h: 0xD9, e: 0x07)

; I apologize for the stupidly verbose comments; this is my first foray into assembler and I intend
; on using this file as a reference for future projects

; the interrupt table is handled automatically by the compiler using the macros defined in 
; 'avr/ioXXX.h' as the subroutine labels AS LONG AS those labels are declared '.global'.

#include <avr/io.h>
#include <avr/interrupt.h>

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
#define CONV r21

;=== UTILITY MACROS ===;
#define low(x) ((x) & 0xFF)
#define high(x) (((x) >> 8) & 0xFF)

; run when the chip resets
.global main
main:
  ; divide 8 MHz internal crystal by 64
  ; the clock is already divided by 8 due to fuse settings
  ; set prescaler to divide that signal by 8 additionally
  ; this gives a system clock speed of 1 MHz / 8 = 125 kHz
  ; According to the datasheet, the ADC needs a system clock above 100 kHz,
  ; so this is as low as we can go.
  ldi TEMP,0x00 | _BV(CLKPCE)
  sts CLKPR,TEMP
  ldi TEMP, 0x00 | _BV(CLKPS1) | _BV(CLKPS0)
  sts CLKPR,TEMP

  ; enable output pins
  ;ldi TEMP,0x00 | _BV(DDD5) | _BV(DDD4) | _BV(DDD3) | _BV(DDD2) | _BV(DDD1) | _BV(DDD0)
  ldi TEMP,0xFF
  out _SFR_IO_ADDR(DDRD),TEMP

  ; set min and max for LED chase and initialize location to min LED
  clr MIN
  clr MAX
  clr LOC
  clr DIR
  ldi MIN,_BV(PORTD0)
  ldi MAX,_BV(PORTD7)
  mov LOC,MIN
  ldi DIR,ASC

  ; power on only the features we are using
  ; PRR [ PRTWI | PRTIM2 | PRTIM0 | - | PRTIM1 | PRSPI | PRUSART0 | PRADC ]
  ldi TEMP, 0xFF & !_BV(PRTIM0) & !_BV(PRADC)
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
  ldi TEMP,0x00 | _BV(CS02) | _BV(CS00)
  sts TCCR0B,TEMP

  ; clear pending interrupts
  ldi TEMP,0x00 | _BV(TOV0)
  out TIFR0,TEMP

  ; enable timer/counter 0 output compare A interrupt
  ldi TEMP,0x00 | _BV(OCIE0A)
  sts TIMSK0,TEMP

  ; set up ADC voltage reference and input pin
  ; ADMUX [ REFS1 | REFS0 | ADLAR | - | MUX3 | MUX2 | MUX1 | MUX0 ]
  ldi TEMP,0x00 | _BV(REFS0) | _BV(ADLAR)
  sts ADMUX,TEMP  ; set ADMUX to TEMP

  ; set up ADC trigger source
  ; ADCSRB [ - | ACME | - | - | - | ADTS2 | ADTS1 | ADTS0 ]
  ldi TEMP,0x00
  sts ADCSRB,TEMP ; set ADCSRB to TEMP

  ; set up ADC clocking and triggering, enable ADC
  ; ADCSRA [ ADEN | ADSC | ADATE | ADIF | ADIE | ADPS2 | ADPS1 | ADPS0 ]
  ldi TEMP,0x00 | _BV(ADEN) | _BV(ADATE) | _BV(ADIE) | _BV(ADIF) | _BV(ADSC)
  sts ADCSRA,TEMP ; set ADCSRA to TEMP

  sei             ; globally enable interrupts
  out _SFR_IO_ADDR(PORTD),LOC   ; start at minimum LED
  rjmp loop       ; jump into infinite loop

; infinite loop. I guess this could be a sleep maybe?
loop:
  rjmp loop       ; loop infinitely

; run when the ADC finishes a conversion
.global ADC_vect
ADC_vect:
  lds CONV,ADCH   ; set the output compare for timer 0 to the ADC value
  sts OCR0A,CONV  ; set the output compare for timer 0 to the ADC value
  reti            ; return from ISR

; run when timer/counter0 matches OCR0A
.global TIMER0_COMPA_vect
TIMER0_COMPA_vect:
  cpi DIR,ASC     ; compare the direction reg with the ascend direction constant...
  breq ascend     ; ...and skip to the ascend code if they're equal...
  rjmp descend    ; ...or to the descend code if they're not.

ascend:
  lsl LOC         ; increment LED location (originally used rol, but it screwed up the compare
  out _SFR_IO_ADDR(PORTD),LOC   ; write LED location out
  cpse LOC,MAX    ; compare the location to the max location...
  reti            ; ...and skip this instruction if they're the same.
  ldi DIR,DSC     ; reverse direction
  reti            ; return from ISR

descend:
  lsr LOC         ; decrement LED location (originally used ror, but it screwed up the compare)
  out _SFR_IO_ADDR(PORTD),LOC   ; write LED location out
  cpse LOC,MIN    ; compare the current location with the min location...
  reti            ; ...and skip this instruction if they're the same.
  ldi DIR,ASC     ; reverse direction
  reti            ; return from ISR
