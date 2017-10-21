; Nick Piscitello
; September 2017
; Atmel ATMEGA328-PU
; avr-gcc 7.2.0
; fuses: default (l: 0x62, h: 0xD9, e: 0x07)

; This code could use some optimization; the display updating algorithm is kinda
; janky and doesn't make for a very smooth refresh.

#include <avr/io.h>
#include <avr/interrupt.h>

;=== REGISTER MAP ===;
; temporary working reg
#define TEMP r16
; current LED index lit
#define INDEX r17
; output bitfield
#define OUT r18
; LED direction
#define DIR r19
; iterator reg for FOR loop
#define CNT r20

;=== UTILITY MACROS ===;
#define low(x) ((x) & 0xFF)
#define high(x) (((x) >> 8) & 0xFF)

;=== CONSTANTS ===;
; LEDs are ascending
#define ASC 0x01
; LEDs are descending
#define DSC 0x00
; minimum index
#define MIN 0x00
; maximum index (must be <= 0x09)
#define MAX 0x09

; run when the chip resets
.global main
main:
  ; divide 8 MHz internal crystal by 256
  ; The fuse settings cause the chip to start up with CLKPS[3:0]
  ; set to divide the clock by 8. This section resets those bits
  ; to divide the clock by 256.
  ; This gives a system clock speed of 8 MHz / 256 = 31.25 kHz
  ; Serial with AVRDUDE must be run slower than normal (-B128 or so)
  ldi TEMP,0x00 | _BV(CLKPCE)
  sts CLKPR,TEMP
  ldi TEMP, 0x00 | _BV(CLKPS3)
  sts CLKPR,TEMP

  ; enable output pins
  ; LED order: D0 D1 D2 D3 D4 D5 D6 D7 B6 B7
  ldi TEMP,0xFF
  out _SFR_IO_ADDR(DDRD),TEMP
  ldi TEMP,0x00 | _BV(DDB6) | _BV(DDB7)
  out _SFR_IO_ADDR(DDRB),TEMP

  ; set min and max for LED chase and initialize location to min LED
  clr INDEX
  clr DIR
  ldi INDEX,MIN
  ldi DIR,ASC

  ; power on only the features we are using
  ; PRR [ PRTWI | PRTIM2 | PRTIM0 | - | PRTIM1 | PRSPI | PRUSART0 | PRADC ]
  ldi TEMP, 0xFF & !_BV(PRTIM0)
  sts PRR,TEMP

  ; set stack pointer to the end of RAM (required for returning from interrupts)
  ldi TEMP,low(RAMEND)
  sts SPL,TEMP
  ldi TEMP,high(RAMEND)
  sts SPH,TEMP

  ; set up the timer/counter 0 mode (CTC)
  ldi TEMP,0x00 | _BV(WGM01)
  sts TCCR0A,TEMP

  ; set up the timer/counter 0 clock source (sys / 1024) - with a 31.25 kHz
  ; system clock, that means the timer runs just a little over 30.5 Hz
  ldi TEMP,0x00 | _BV(CS02) | _BV(CS00)
  sts TCCR0B,TEMP

  ; clear pending interrupts
  ldi TEMP,0x00 | _BV(TOV0)
  out TIFR0,TEMP

  ; enable timer/counter 0 output compare A interrupt, set counter value
  ldi TEMP,0x00 | _BV(OCIE0A)
  sts TIMSK0,TEMP
  ldi TEMP,0x03
  sts OCR0A,TEMP

  sei               ; globally enable interrupts
  rjmp loop         ; jump into infinite loop

; infinite loop. In the spirit of minimizing interrupt code, the leds are lit from here
loop:
  clr TEMP          ; clean out registers to prevent anything weird from happening
  clr OUT
  clr CNT
  mov TEMP,INDEX    ; store a static copy of INDEX in case the timer fires during update
  ldi OUT,0x01      ; load a seed to shift right
  mov CNT,TEMP      ; load the loop counter with the number of times to shift
  cpi TEMP,0x08
  brlo shift_loop   ; if the index is less than 8, jump directly into the loop
  subi CNT,2        ; if not, subtract 2 (shift 2 fewer places right)
  shift_loop:       ; for loop to shift the 0x01 seed right far enough
    cpi CNT,0x00    ; if the counter has reached zero...
    breq output     ; jump to the output router
    lsl OUT         ; if not, left shift the output byte...
    dec CNT         ; ...decrement the counter...
    rjmp shift_loop ; ...and jump back to the head of the loop

output:
  cpi TEMP,0x08
  brsh out_portb    ; send the output to PORTB if the index is high enough...
  rjmp out_portd    ; ...or to PORTD if it's low enough
  out_portd:
    out _SFR_IO_ADDR(PORTB),0x00
    out _SFR_IO_ADDR(PORTD),OUT
    rjmp loop       ; loop infinitely
  out_portb:
    out _SFR_IO_ADDR(PORTD),0x00
    out _SFR_IO_ADDR(PORTB),OUT
    rjmp loop       ; loop infinitely

; run when timer/counter0 matches OCR0A
.global TIMER0_COMPA_vect
TIMER0_COMPA_vect:
  cpi DIR,ASC       ; compare the direction reg with the ascend direction constant...
  breq ascend       ; ...and skip to the ascend code if they're equal...
  rjmp descend      ; ...or to the descend code if they're not.

ascend:
  inc INDEX         ; increment LED location (originally used rol, but it screwed up the compare
  cpi INDEX,MAX     ; compare the index to the max index...
  breq start_descending
  reti              ; ...and skip this instruction if they're the same.
  start_descending:
    ldi DIR,DSC     ; reverse direction
    reti            ; return from ISR

descend:
  dec INDEX         ; decrement LED location (originally used ror, but it screwed up the compare)
  cpi INDEX,MIN     ; compare the current index with the min index...
  breq start_ascending
  reti              ; ...and skip this instruction if they're the same.
  start_ascending:
    ldi DIR,ASC     ; reverse direction
    reti            ; return from ISR
