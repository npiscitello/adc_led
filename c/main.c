#include <avr/io.h>
#include <util/delay.h>

// _BV is defined as (1 << <ARG>)

uint8_t map(uint8_t value, uint8_t min, uint8_t max) {
  return (uint8_t)((((float)value / 256.0) * (float)(max - min)) + min);
}

int main(void) {

  // enable output on pins 8-13 only
  DDRB |= 0x00 | _BV(DDB0) | _BV(DDB1) | _BV(DDB2) | _BV(DDB3) | _BV(DDB4) | _BV(DDB5);

  //--- ADC STUFF ---//
  // power on the ADC (write a zero to the ADC power save mode)
  PRR &= ~_BV(PRADC);
  // enable the ADC (set ADEN to 1) divide system clock by 128 (125kHz ADC clock) (ADPS[2:0] = 111)
  ADCSRA |= _BV(ADEN) | _BV(ADPS2) | _BV(ADPS1) | _BV(ADPS0);
  // enable internal VCC ADC reference (set REFS[1:0] to 01)
  ADMUX &= ~_BV(REFS1);
  ADMUX |= _BV(REFS0);
  // select ADC0 as the ADC pin (MUX[3:0] = 0000)
  ADMUX &= ~_BV(MUX3) & ~_BV(MUX2) & ~_BV(MUX1) & ~_BV(MUX0);
  // left adjust result (read from only ADCH, limits to 8-bit precision) (set ADLAR to 1)
  ADMUX |= _BV(ADLAR);
  // enable auto-trigger and select interrupt as source
  ADCSRA |= _BV(ADATE);
  ADCSRB &= ~_BV(ADTS2) & ~_BV(ADTS1) & ~_BV(ADTS0);
  // kick off ADC continuous  conversions
  ADCSRA |= _BV(ADSC);
  //--- END ADC STUFF ---//

  // counter vars - min/max inclusive
  const uint8_t MIN = _BV(PORTB0);
  const uint8_t MAX = _BV(PORTB5);
  // start at pin 8
  PORTB = MIN;
  uint8_t ascend = 1;

  while (1) {
    // handle limits
    if( PORTB == MAX ) {
      ascend = 0;
    } else if( PORTB == MIN ) {
      ascend = 1;
    }

    // increment/decrement pin
    if( ascend == 1 ) {
      PORTB = PORTB << 1;
    } else {
      PORTB = PORTB >> 1;
    }

    // wait a bit
    _delay_ms(map(ADCH, 10, 150));
  }
  return(0);
}
