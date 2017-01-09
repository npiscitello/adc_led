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

;=== UTILITY MACROS ===;
#define low(x) ((x) & 0xFF)
#define high(x) (((x) >> 8) & 0xFF)

; run when the chip resets
.global main
main:
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

  clr XH          ; clear X high byte (we don't need any 2 byte memory addresses)

  ; power on the features we are using
  ldi XL,PRR      ; set X low byte to a pointer to the PRR reg
  ld  TEMP,X      ; load the memory at X into TEMP
  cbr TEMP,PRTIM0 ; clear the timer 0 power save bit (send power to timer 0) 
  cbr TEMP,PRADC  ; clear the ADC power save bit (send power to the ADC)
  st  X,TEMP      ; set the memory at X to TEMP

  ; set up stack (required for returning from interrupts)
  ldi TEMP,low(RAMEND)  ; set stack pointer to the end of ram
  ldi XL,SPL            ; load in address to low half of stack pointer
  st X,TEMP             ; set stack pointer to the end of ram
  ldi TEMP,high(RAMEND) ; set stack pointer to the end of ram
  ldi XL,SPH            ; load in address to high half of stack pointer
  st X,TEMP             ; set stack pointer to the end of ram

  ; set up INT0 interrupt
  ;ldi TEMP,0x00 | _BV(ISC01) | _BV(ISC00)  ; set up interrupt situations (rising edge)
  ;ldi TEMP,0x00 | _BV(ISC01) ; set up interrupt situations (falling edge)
  ;ldi XL,EICRA    ; load the addr to the external interrupt control reg
  ;st X,TEMP       ; set the external interrupt control reg to the value stored in TEMP
  ;sbi _SFR_IO_ADDR(EIMSK),INT0  ; enable INT0...

  ; set up the timer/counter 0 mode
  ldi TEMP,0x00
  sts TCCR0A,TEMP

  ; set up the timer/counter 0 clock source (sys / 1024)
  ldi TEMP, 0x00 | _BV(CS02) | _BV(CS01)
  sts TCCR0B,TEMP

  ; clear pending interrupts
  ldi TEMP,_BV(TOV0)
  out TIFR0,TEMP

  ; enable timer/counter 0 overflow interrupts
  ldi TEMP,_BV(TOIE0)
  sts TIMSK0,TEMP

  sei             ; globally enable interrupts

  ; set up ADC trigger source
  ldi XL,ADCSRB   ; set X low byte to a pointer to the ADCSRB reg
  ld  TEMP,X      ; load the memory at X into TEMP
  cbr TEMP,ADTS2  ; select ADC interrupt as trigger source
  cbr TEMP,ADTS1  ; select ADC interrupt as trigger source
  cbr TEMP,ADTS0  ; select ADC interrupt as trigger source
  st  X,TEMP      ; set the memory at X to TEMP

  ; set up ADC voltage reference and input pin
  ldi XL,ADMUX    ; set X low byte to a pointer to the ADCSRB reg
  ld  TEMP,X      ; load the memory at X into TEMP
  cbr TEMP,REFS1  ; enable internal voltage ref
  cbr TEMP,REFS0  ; enable internal voltage ref
  cbr TEMP,MUX3   ; set ADC0 as the ADC pin
  cbr TEMP,MUX2   ; set ADC0 as the ADC pin
  cbr TEMP,MUX1   ; set ADC0 as the ADC pin
  cbr TEMP,MUX0   ; set ADC0 as the ADC pin
  st  X,TEMP      ; set the memory at X to TEMP

  ; set up ADC clocking and triggering, enable ADC
  ldi XL,ADCSRA   ; set X low byte to a pointer to the ADCSRA reg
  ld  TEMP,X      ; load the memory at X into TEMP
  sbr TEMP,ADEN   ; enable ADC
  sbr TEMP,ADPS2  ; divide system clock by 128
  sbr TEMP,ADPS1  ; divide system clock by 128
  sbr TEMP,ADPS0  ; divide system clock by 128
  sbr TEMP,ADATE  ; enable auto trigger
  st  X,TEMP      ; set the memory at X to TEMP
  sbr TEMP,ADSC   ; trigger first read
  st  X,TEMP      ; set the memory at X to TEMP

  out _SFR_IO_ADDR(PORTB),LOC   ; start at minimum LED
  rjmp loop       ; jump into infinite loop

; infinite loop. I guess this could be a sleep maybe?
loop:
  rjmp loop

; run when an interrupt is triggered on D2 (PD2, pin 4)
; eventually, this interrupt will be triggered by a timer instead of a pin
.global TIMER0_OVF_vect
TIMER0_OVF_vect:
;.global INT0_vect
;INT0_vect:
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
