.syntax unified
.cpu cortex-m0plus
.thumb

.section .vectors, "a", %progbits
.align 2
.global __vector_table
__vector_table:
    .word __StackTop
    .word Reset_Handler
    .rept 46
    .word Default_Handler
    .endr

.section .text.Reset_Handler, "ax", %progbits
.align 2
.global Reset_Handler
.type Reset_Handler, %function
.thumb_func
Reset_Handler:
    /* Copy initialized data from its flash load address into SRAM. */
    ldr r0, =__data_load__
    ldr r1, =__data_start__
    ldr r2, =__data_end__
1:
    cmp r1, r2
    bcs 2f
    ldr r3, [r0]
    str r3, [r1]
    adds r0, #4
    adds r1, #4
    b 1b
2:
    /* Clear zero-initialized data. */
    ldr r1, =__bss_start__
    ldr r2, =__bss_end__
    movs r3, #0
3:
    cmp r1, r2
    bcs 4f
    str r3, [r1]
    adds r1, #4
    b 3b
4:
    /*
     * The boot ROM leaves many peripherals in reset on the flash-boot path.
     * Release IO_BANK0 and PADS_BANK0 before main configures GPIO25.
     */
    ldr r3, =0x4000c000         /* RESETS_BASE */
    ldr r1, =0x00000120         /* IO_BANK0 (bit 5), PADS_BANK0 (bit 8) */
    ldr r0, [r3, #0x00]         /* RESET */
    orrs r0, r1
    str r0, [r3, #0x00]         /* assert reset to establish known state */
    ldr r0, [r3, #0x00]
    bics r0, r1
    str r0, [r3, #0x00]         /* deassert both peripheral resets */
6:
    ldr r0, [r3, #0x08]         /* RESET_DONE */
    ands r0, r1
    cmp r0, r1
    bne 6b

    bl main
5:
    b 5b
.size Reset_Handler, . - Reset_Handler
.ltorg

.section .text.Default_Handler, "ax", %progbits
.align 2
.global Default_Handler
.type Default_Handler, %function
.thumb_func
Default_Handler:
    b Default_Handler
.size Default_Handler, . - Default_Handler
