CROSS_COMPILE ?= arm-none-eabi-
CC       := $(CROSS_COMPILE)gcc
OBJCOPY  := $(CROSS_COMPILE)objcopy
OBJDUMP  := $(CROSS_COMPILE)objdump
READELF  := $(CROSS_COMPILE)readelf
HOSTCC   ?= cc
BUILD    := build

CPUFLAGS := -mcpu=cortex-m0plus -mthumb
CFLAGS   := $(CPUFLAGS) -std=c11 -O2 -g -ffreestanding -fno-builtin \
            -ffunction-sections -fdata-sections -fno-unwind-tables \
            -fno-asynchronous-unwind-tables -Wall -Wextra -Werror
ASFLAGS  := $(CPUFLAGS) -g
LDFLAGS  := $(CPUFLAGS) -nostdlib -nostartfiles -nodefaultlibs \
            -Wl,--gc-sections -Wl,--build-id=none \
            -Wl,-Map=$(BUILD)/blink.map -T linker.ld

OBJECTS := $(BUILD)/startup.o $(BUILD)/boot2.o $(BUILD)/main.o

.PHONY: all clean inspect flash
all: $(BUILD)/blink.uf2

$(BUILD):
	mkdir -p $@

$(BUILD)/startup.o: startup.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/boot2.o: boot2.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/main.o: main.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/blink.elf: $(OBJECTS) linker.ld
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@
	$(READELF) -S $@ > $(BUILD)/sections.txt
	$(OBJDUMP) -h $@ > $(BUILD)/sections-objdump.txt

$(BUILD)/blink.bin: $(BUILD)/blink.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD)/mkuf2: tools/mkuf2.c | $(BUILD)
	$(HOSTCC) -std=c11 -O2 -Wall -Wextra -Werror $< -o $@

$(BUILD)/blink.uf2: $(BUILD)/blink.bin $(BUILD)/mkuf2
	$(BUILD)/mkuf2 $< $@

inspect: $(BUILD)/blink.elf
	$(READELF) -h -S -l $<
	$(OBJDUMP) -d $<

PICO_MOUNT ?= /media/$(USER)/RPI-RP2
flash: $(BUILD)/blink.uf2
	@test -f "$(PICO_MOUNT)/INFO_UF2.TXT" || { echo "Pico BOOTSEL drive not found at $(PICO_MOUNT)"; exit 1; }
	@grep -q 'RPI-RP2' "$(PICO_MOUNT)/INFO_UF2.TXT" || { echo "$(PICO_MOUNT) is not an RP2040 BOOTSEL drive"; exit 1; }
	cp $(BUILD)/blink.uf2 "$(PICO_MOUNT)/blink.uf2"
	sync
	@echo "Copied UF2 to $(PICO_MOUNT); the Pico should disconnect and reboot."

clean:
	rm -rf $(BUILD)
