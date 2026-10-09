/* RP2040 (Raspberry Pi Pico) flash and SRAM layout. */
ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x10000000, LENGTH = 2M
    /* RP2040 has 256 KiB striped SRAM plus two contiguous 4 KiB banks. */
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 264K
}

__StackTop = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    /* The ROM loads and runs these 256 bytes from SRAM before XIP is set up. */
    .boot2 ORIGIN(FLASH) :
    {
        __boot2_start__ = .;
        KEEP(*(.boot2))
        ASSERT(. <= ORIGIN(FLASH) + 0xFC,
               "boot2 code exceeds the 252-byte code/checksum limit");
        FILL(0x00000000)
        . = ORIGIN(FLASH) + 0xFC;
        LONG(0)
        __boot2_end__ = .;
    } > FLASH
    ASSERT(ADDR(.boot2) == ORIGIN(FLASH), "boot2 must start at flash offset 0")
    ASSERT(SIZEOF(.boot2) == 0x100, "boot2 must be exactly 256 bytes")

    /* The boot2 exit code vectors through the table at flash offset 0x100. */
    .vectors ORIGIN(FLASH) + 0x100 :
    {
        __vectors_start__ = .;
        KEEP(*(.vectors))
        __vectors_end__ = .;
    } > FLASH
    ASSERT(ADDR(.vectors) == 0x10000100,
           "vector table must immediately follow boot2 at 0x10000100")
    ASSERT(SIZEOF(.vectors) == 0xC0,
           "RP2040 vector table must contain 48 words (192 bytes)")

    .text :
    {
        . = ALIGN(4);
        *(.text.Reset_Handler)
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > FLASH

    .data : ALIGN(4)
    {
        __data_start__ = .;
        *(.data .data.*)
        . = ALIGN(4);
        __data_end__ = .;
    } > RAM AT > FLASH
    __data_load__ = LOADADDR(.data);

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start__ = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
    } > RAM

    .uninit (NOLOAD) : ALIGN(4)
    {
        *(.uninit .uninit.*)
    } > RAM

    /* These sections are not needed by the bare-metal image. */
    /DISCARD/ :
    {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
    }

    ASSERT(__bss_end__ <= __StackTop,
           "RAM sections overlap the initial stack pointer")
    ASSERT(LOADADDR(.data) + SIZEOF(.data) <= ORIGIN(FLASH) + LENGTH(FLASH),
           "flash image exceeds the Pico's 2 MiB flash")
}
