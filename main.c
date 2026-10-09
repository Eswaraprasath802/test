#include <stdint.h>

/* ---------- SIO ---------- */

#define SIO_BASE        0xD0000000u

#define SIO_GPIO_OUT    (*(volatile uint32_t *)(SIO_BASE + 0x010u))
#define SIO_GPIO_OE     (*(volatile uint32_t *)(SIO_BASE + 0x020u))


/* ---------- IO_BANK0 ---------- */

#define IO_BANK0_BASE       0x40014000u

#define GPIO25_CTRL         (*(volatile uint32_t *)(IO_BANK0_BASE + 0x0CCu))


/* ---------- GPIO ---------- */

#define LED_PIN             25u

/*
 * GPIO function select:
 *
 * 5 = SIO
 */
#define GPIO_FUNC_SIO       5u


/* ---------- Simple delay ---------- */

void delay(volatile uint32_t count)
{
    while (count--)
    {
        __asm volatile ("nop");
    }
}


/* ---------- Main ---------- */

int main(void)
{
    /*
     * Select SIO function for GPIO 25.
     */
    GPIO25_CTRL = GPIO_FUNC_SIO;


    /*
     * Enable GPIO 25 as an output.
     */
    SIO_GPIO_OE |= (1u << LED_PIN);


    while (1)
    {
        /*
         * LED ON
         *
         * Set bit 25 of GPIO_OUT.
         */
        SIO_GPIO_OUT |= (1u << LED_PIN);

        delay(1000000);


        /*
         * LED OFF
         *
         * Clear bit 25 of GPIO_OUT.
         */
        SIO_GPIO_OUT &= ~(1u << LED_PIN);

        delay(1000000);
    }
}