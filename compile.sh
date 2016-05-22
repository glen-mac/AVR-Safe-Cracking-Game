#!/usr/bin/env bash
avrdude -c wiring -p m2560 -P /dev/$1 -b 115200 -U flash:w:$2.hex:i -D
