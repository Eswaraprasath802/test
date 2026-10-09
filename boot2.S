/*
 * Minimal RP2040 stage 2: configure SSI for standard 0x03 SPI XIP reads.
 * This deliberately uses no SDK headers or startup code. The ROM copies this
 * section to SRAM and enters it in Thumb state; linker.ld pads it to 252 bytes
 * and reserves the final word for the ROM-checked CRC32.
 */
.syntax unified
.cpu cortex-m0plus
.thumb

.section .boot2, "ax", %progbits
.align 2
.global _stage2_boot
.type _stage2_boot, %function
.thumb_func
_stage2_boot:
    push {lr}

    /* Disable SSI while configuring it. */
    ldr r3, =0x18000000         /* XIP_SSI_BASE */
    movs r1, #0
    str r1, [r3, #0x08]         /* SSIENR */

    /* Conservative SPI clock divider and 32-bit EEPROM-read mode. */
    movs r1, #4
    str r1, [r3, #0x14]         /* BAUDR */
    ldr r1, =0x001f0300         /* DFS_32=32 bits, TMOD=EEPROM read */
    str r1, [r3, #0x00]         /* CTRLR0 */
    ldr r1, =0x03000218         /* 0x03 cmd, 24-bit addr, 8-bit cmd */
    ldr r0, =0x180000f4         /* SPI_CTRLR0 */
    str r1, [r0]
    movs r1, #0
    str r1, [r3, #0x04]         /* CTRLR1: one 32-bit read */

    /* Enable SSI, then enter the flash image (or return to a caller). */
    movs r1, #1
    str r1, [r3, #0x08]         /* SSIENR */
    pop {r0}
    cmp r0, #0
    beq 1f
    bx r0
1:
    ldr r0, =0x10000100         /* XIP flash vector table */
    ldr r1, =0xe000ed08         /* Cortex-M0+ VTOR */
    str r0, [r1]
    ldmia r0, {r0, r1}          /* Initial SP and reset vector */
    msr msp, r0
    bx r1
.size _stage2_boot, . - _stage2_boot
.ltorg
