/* Create an RP2040 UF2 from a raw flash image and fill the boot2 CRC32. */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define UF2_BLOCK_SIZE 512u
#define UF2_PAYLOAD_SIZE 256u
#define UF2_FLASH_BASE 0x10000000u
#define UF2_FLASH_SIZE (2u * 1024u * 1024u)
#define UF2_FAMILY_ID 0xE48BFF56u

static void put_le32(uint8_t *p, uint32_t value)
{
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
}

/* RP2040 ROM CRC: non-reflected CRC-32, init 0xffffffff, final XOR 0. */
static uint32_t boot2_crc32(const uint8_t *data, size_t length)
{
    uint32_t crc = 0xffffffffu;

    for (size_t i = 0; i < length; ++i) {
        crc ^= (uint32_t)data[i] << 24;
        for (unsigned bit = 0; bit < 8; ++bit) {
            crc = (crc & 0x80000000u)
                ? (crc << 1) ^ 0x04c11db7u
                : crc << 1;
        }
    }
    return crc;
}

static int read_file(const char *path, uint8_t **data_out, size_t *size_out)
{
    FILE *file = fopen(path, "rb");
    if (!file) {
        fprintf(stderr, "cannot open %s: %s\n", path, strerror(errno));
        return -1;
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fprintf(stderr, "cannot seek %s\n", path);
        fclose(file);
        return -1;
    }
    long end = ftell(file);
    if (end < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fprintf(stderr, "cannot determine size of %s\n", path);
        fclose(file);
        return -1;
    }

    uint8_t *data = malloc((size_t)end ? (size_t)end : 1u);
    if (!data) {
        fprintf(stderr, "out of memory reading %s\n", path);
        fclose(file);
        return -1;
    }
    if (fread(data, 1, (size_t)end, file) != (size_t)end) {
        fprintf(stderr, "cannot read %s\n", path);
        free(data);
        fclose(file);
        return -1;
    }
    fclose(file);
    *data_out = data;
    *size_out = (size_t)end;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s input.bin output.uf2\n", argv[0]);
        return 2;
    }

    uint8_t *image = NULL;
    size_t image_size = 0;
    if (read_file(argv[1], &image, &image_size) != 0)
        return 1;

    if (image_size < UF2_PAYLOAD_SIZE || image_size > UF2_FLASH_SIZE) {
        fprintf(stderr, "image must be between 256 bytes and 2 MiB\n");
        free(image);
        return 1;
    }

    /* Extend the final flash page with erased-state bytes. */
    size_t padded_size = (image_size + UF2_PAYLOAD_SIZE - 1u)
                       & ~(size_t)(UF2_PAYLOAD_SIZE - 1u);
    if (padded_size > UF2_FLASH_SIZE) {
        fprintf(stderr, "page-aligned image exceeds 2 MiB flash\n");
        free(image);
        return 1;
    }
    uint8_t *padded = realloc(image, padded_size);
    if (!padded) {
        fprintf(stderr, "out of memory padding image\n");
        free(image);
        return 1;
    }
    image = padded;
    memset(image + image_size, 0xff, padded_size - image_size);

    uint32_t crc = boot2_crc32(image, 252u);
    put_le32(image + 252u, crc);

    /* Keep the raw .bin valid too, not only its UF2 wrapper. */
    FILE *patched_input = fopen(argv[1], "r+b");
    int patch_failed = patched_input == NULL;
    if (patched_input) {
        if (fseek(patched_input, 252L, SEEK_SET) != 0
            || fwrite(image + 252u, 1, 4, patched_input) != 4) {
            patch_failed = 1;
        }
        if (fclose(patched_input) != 0)
            patch_failed = 1;
    }
    if (patch_failed) {
        fprintf(stderr, "cannot write boot2 CRC to %s\n", argv[1]);
        free(image);
        return 1;
    }

    size_t block_count = padded_size / UF2_PAYLOAD_SIZE;
    FILE *output = fopen(argv[2], "wb");
    if (!output) {
        fprintf(stderr, "cannot create %s: %s\n", argv[2], strerror(errno));
        free(image);
        return 1;
    }

    uint8_t block[UF2_BLOCK_SIZE];
    for (size_t index = 0; index < block_count; ++index) {
        memset(block, 0, sizeof(block));
        put_le32(block + 0, 0x0a324655u);
        put_le32(block + 4, 0x9e5d5157u);
        put_le32(block + 8, 0x00002000u); /* family ID present */
        put_le32(block + 12, UF2_FLASH_BASE + (uint32_t)(index * UF2_PAYLOAD_SIZE));
        put_le32(block + 16, UF2_PAYLOAD_SIZE);
        put_le32(block + 20, (uint32_t)index);
        put_le32(block + 24, (uint32_t)block_count);
        put_le32(block + 28, UF2_FAMILY_ID);
        memcpy(block + 32, image + index * UF2_PAYLOAD_SIZE, UF2_PAYLOAD_SIZE);
        put_le32(block + 508, 0x0ab16f30u);
        if (fwrite(block, 1, sizeof(block), output) != sizeof(block)) {
            fprintf(stderr, "error writing %s\n", argv[2]);
            fclose(output);
            free(image);
            return 1;
        }
    }

    if (fclose(output) != 0) {
        fprintf(stderr, "error closing %s\n", argv[2]);
        free(image);
        return 1;
    }
    printf("Created %s: %zu UF2 blocks, flash address 0x%08x, boot2 CRC 0x%08x\n",
           argv[2], block_count, UF2_FLASH_BASE,
           (unsigned)crc);
    free(image);
    return 0;
}
