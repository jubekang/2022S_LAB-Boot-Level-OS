#include "memory.h"
#include "print.h"
#include "debug.h"
#include "stddef.h"

static void free_region(uint64_t v, uint64_t e);

static struct FreeMemRegion free_mem_region[50];
static struct Page free_memory;
static uint64_t memory_end;
extern char end;    /* declared in linker file : end of kernel */

void init_memory(void)
{
    int32_t count = *(int32_t*)0x9000;
    uint64_t total_mem = 0;
    struct E820 *mem_map = (struct E820*)0x9008;	
    int free_region_count = 0;

    ASSERT(count <= 50);

	for(int32_t i = 0; i < count; i++) {        
        if(mem_map[i].type == 1) {			
            free_mem_region[free_region_count].address = mem_map[i].address;
            free_mem_region[free_region_count].length = mem_map[i].length;
            total_mem += mem_map[i].length;
            free_region_count++;
        }
        printk("Adress: %x  Length: %uKB  Type: %u\n", mem_map[i].address, mem_map[i].length/1024, (uint64_t)mem_map[i].type);
	}
    /* divide the free memory into a 2MB pages */
    for (int i = 0; i < free_region_count; i++) {                  
        uint64_t vstart = P2V(free_mem_region[i].address);  /* beginning of the memory region: virual adddress */
        uint64_t vend = vstart + free_mem_region[i].length; /* end of the memory region : virual adddress */

        if (vstart > (uint64_t)&end) { /* if start of meory region is larger than the end of kernel, free memory we want */
            free_region(vstart, vend);
        } 
        else if (vend > (uint64_t)&end) { /* if start of meory region is less than the end of kernel, free memory is start from end of kernel */
            free_region((uint64_t)&end, vend);
        }       
    }

    memory_end = (uint64_t)free_memory.next+PAGE_SIZE;
    printk("%x\n",memory_end);
}

static void free_region(uint64_t v, uint64_t e)
{
    for (uint64_t start = PA_UP(v); start+PAGE_SIZE <= e; start += PAGE_SIZE) {        
        if (start+PAGE_SIZE <= 0xffff800040000000) {   /* This value is 1G above the base of kernel */         
           kfree(start);
        }
    }
}

void kfree(uint64_t v)
{
    ASSERT(v % PAGE_SIZE == 0); /* check if virtual address is aligned */
    ASSERT(v >= (uint64_t)&end); /* check if virtual address is not within the kernel */
    ASSERT(v+PAGE_SIZE <= 0xffff800040000000); /* check 1G memory limit */ 

    struct Page *page_address = (struct Page*)v;
    page_address->next = free_memory.next;
    free_memory.next = page_address;

    //printk("free!\n");
}

void* kalloc(void)
{   /* just removing a page from the page list */
    struct Page *page_address = free_memory.next;

    if (page_address != NULL) {
        ASSERT((uint64_t)page_address % PAGE_SIZE == 0);
        ASSERT((uint64_t)page_address >= (uint64_t)&end);
        ASSERT((uint64_t)page_address+PAGE_SIZE <= 0xffff800040000000);

        free_memory.next = page_address->next;            
    }
    
    return page_address;
}
