#ifndef _MEMORY_H_
#define _MEMORY_H_

#include "stdint.h"

struct E820 {
    uint64_t address;   /* base address of memory region */
    uint64_t length;    /* length of memory region */
    uint32_t type;      /* type of memory */
} __attribute__((packed));  /* structure start without padding */

struct FreeMemRegion {
    uint64_t address;   /* base address of free memory region */
    uint64_t length;    /* length of free memory region */
};

void init_memory(void);

#endif