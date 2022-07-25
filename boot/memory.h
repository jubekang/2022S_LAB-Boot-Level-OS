#ifndef _MEMORY_H_
#define _MEMORY_H_

#include "stdint.h"
#include "stddef.h"
#include "stdbool.h"

struct E820 {
    uint64_t address;
    uint64_t length;
    uint32_t type;
} __attribute__((packed));

struct FreeMemRegion {
    uint64_t address;
    uint64_t length;
};

struct Page {
    struct Page* next;
};
typedef uint64_t PDE;
typedef PDE* PD;
typedef PD* PDPTR;

#define PTE_P 1 /* P -> 0 - page table is not in the memory => page fault */
#define PTE_W 2 /* W -> 1 - Readable and Writable */
#define PTE_U 4 /* U -> 0 - user program in ring3 is not allowed to access page */
#define PTE_ENTRY 0x80 /* 7th bit 1 -> hold 1g physical page translation */
#define KERNEL_BASE 0xffff800000000000

#define PAGE_SIZE (2*1024*1024) /* 2GB */
#define PA_UP(v) ((((uint64_t)v+PAGE_SIZE-1)>>21)<<21) /* allign the address to 2m boundary */
#define PA_DOWN(v) (((uint64_t)v>>21)<<21)
#define P2V(p) ((uint64_t)(p) + KERNEL_BASE)
#define V2P(v) ((uint64_t)(v) - KERNEL_BASE)
#define PDE_ADDR(p) (((uint64_t)p >> 12) << 12) /* clear the lower 12 bits to get correct address from Page Directory (Pointer) Table */
#define PTE_ADDR(p) (((uint64_t)p >> 21) << 21) /* clear the lower 21 bits to get correct address from Page Table Entry */

void init_memory(void);
void init_kvm(void);
void switch_vm(uint64_t map);
void* kalloc(void);
uint64_t get_total_memory(void);
void kfree(uint64_t v);
bool map_pages(uint64_t map, uint64_t v, uint64_t e, uint64_t pa, uint32_t attribute);
void load_cr3(uint64_t map);
void free_vm(uint64_t map);
void free_page(uint64_t map, uint64_t v, uint64_t e);
bool setup_uvm(uint64_t map, uint64_t start, int size);
uint64_t setup_kvm(void);
bool copy_uvm(uint64_t dst_map, uint64_t src_map, int size);

#endif