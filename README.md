#What This Does
The goal of this project is to create an LED chase sequence using an arduino. The speed of the chase
is to be controlled by the user through a potentiometer.

This is implemented by reading the potentiometer value with the Arduino's inbuilt ADC and using that
value (scaled if necessary) to delay between steps in the chase. This is to be done in C as a proof
of concept (and to cut my teeth on the avr-gcc and WinAVR toolchain) and then in assembler as an
excersise to learn assembler (also, because I guess I like pain).

#The Circuit
Very simple - the Arduino has the anode of an LED each on pins D8 through D13. The cathodes are on a
common bus and linked to GND through a 220 ohm resistor. A potentiometer is hooked up between +5V
and GND with the wiper on A0. For the switch setup, see the RC debouncer at
http://www.ganssle.com/debouncing.htm. D2 is linked to ground through a capacitor. Two resistors in
series act as a voltage divider (with the switch to ground in the middle) between +5V and D2. I used
a .005 uF ceramic cap and 1M ohm resisters (because those were the first components I happened to
grab out of my drawers) and that did the trick very nicely.
