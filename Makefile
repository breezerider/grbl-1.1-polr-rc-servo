#  Part of Grbl
#
#  Copyright (c) 2009-2011 Simen Svale Skogsrud
#  Copyright (c) 2012-2016 Sungeun K. Jeon for Gnea Research LLC
#
#  Grbl is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Grbl is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Grbl.  If not, see <http://www.gnu.org/licenses/>.


# This is a prototype Makefile. Modify it according to your needs.
# You should at least check the settings for
# MCU .......... The AVR microcontroller unit you compile for
# CLOCK ........ Target AVR clock rate in Hertz
# OBJECTS ...... The object files created from your source files. This list is
#                usually the same as the list of source files with suffix ".o".
# PROGRAMMER ... Options to avrdude which define the hardware you use for
#                uploading to the AVR and the interface where this hardware
#                is connected.
# FUSES ........ Parameters for avrdude to flash the fuses appropriately.

MCU        ?= atmega328p
PORT       ?= /dev/ttyUSB0
BAUD       ?= 115200
CLOCK      ?= 16000000
PROGRAMMER ?= -c arduino -P$(PORT) -b$(BAUD) -D
SOURCE    = main.c motion_control.c gcode.c spindle_control.c coolant_control.c serial.c \
             protocol.c stepper.c eeprom.c settings.c planner.c nuts_bolts.c limits.c jog.c \
             print.c probe.c report.c system.c
BUILDDIR = build
SOURCEDIR = grbl
# FUSES      = -U hfuse:w:0xd9:m -U lfuse:w:0x24:m
FUSES      = -U hfuse:w:0xd2:m -U lfuse:w:0xff:m

# Tune the lines below only if you know what you are doing:

AVRDUDE = avrdude -C/etc/avrdude.conf -v -p $(MCU) $(PROGRAMMER)

# Compile flags for avr-gcc v4.8.1. Does not produce -flto warnings.
# COMPILE = avr-gcc -Wall -Os -DF_CPU=$(CLOCK) -mmcu=$(MCU) -I. -ffunction-sections

# Compile flags for avr-gcc v4.9.2 compatible with the IDE. Or if you don't care about the warnings.
AVR_DEFS = -DF_CPU=$(CLOCK)
COMPILE = avr-gcc -Wall -Os -mmcu=$(MCU) $(AVR_DEFS) -I.
#-Og -g -g3 -gdwarf-3
# Compile flags for avr-gcc v7.5.0+
COMPILE += -ffunction-sections -flto -fdata-sections -fno-exceptions -fno-inline-small-functions -fno-split-wide-types -fno-tree-scev-cprop -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums


OBJECTS = $(addprefix $(BUILDDIR)/,$(notdir $(SOURCE:.c=.o)))

# symbolic targets:
all:	grbl.hex

$(BUILDDIR)/%.o: $(SOURCEDIR)/%.c
	$(COMPILE) -MMD -MP -c $< -o $@

.S.o:
	$(COMPILE) -x assembler-with-cpp -c $< -o $(BUILDDIR)/$@
# "-x assembler-with-cpp" should not be necessary since this is the default
# file type for the .S (with capital S) extension. However, upper case
# characters are not always preserved on Windows. To ensure WinAVR
# compatibility define the file type manually.

#.c.s:
#	$(COMPILE) -S $< -o $(BUILDDIR)/$@

flash: grbl.hex
	$(AVRDUDE) -U flash:w:grbl.hex:i

fuse:
	$(AVRDUDE) $(FUSES)

# Xcode uses the Makefile targets "", "clean" and "install"
install: flash fuse

# if you use a bootloader, change the command below appropriately:
load: all
	bootloadHID grbl.hex

clean:
	rm -f grbl.hex $(BUILDDIR)/*.o $(BUILDDIR)/*.d $(BUILDDIR)/*.elf

# file targets:
$(BUILDDIR)/grbl.elf: $(OBJECTS)
	$(COMPILE) -o $(BUILDDIR)/grbl.elf $(OBJECTS) -lm -Wl,--gc-sections -Wl,--relax
#-Wl,-g

grbl.hex: $(BUILDDIR)/grbl.elf
	rm -f grbl.hex
	avr-objcopy -j .text -j .data -O ihex $(BUILDDIR)/grbl.elf $(BUILDDIR)/grbl.hex
	cp $(BUILDDIR)/grbl.hex grbl.hex
	avr-size --format=berkeley $(BUILDDIR)/grbl.elf
	avr-size -C --mcu=$(MCU) $(BUILDDIR)/grbl.elf
# If you have an EEPROM section, you must also create a hex file for the
# EEPROM and add it to the "flash" target.

# Targets for code debugging and analysis:
disasm: grbl.elf
	avr-objdump -d $(BUILDDIR)/grbl.elf

cpp:
	$(COMPILE) -E $(SOURCEDIR)/main.c

# include generated header dependencies
-include $(BUILDDIR)/$(OBJECTS:.o=.d)
