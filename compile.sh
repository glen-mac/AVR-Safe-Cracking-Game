#!/usr/bin/env bash
avrdude -c wiring -p m2560 -P $0 -b 115200 -U flash:w:$1:i -D
