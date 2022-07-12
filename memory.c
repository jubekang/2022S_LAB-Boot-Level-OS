#include "memory.h"
#include "print.h"
#include "debug.h"
#include "lib.h"
#include "stddef.h"
#include "stdbool.h"

static void free_region(uint64_t v, uint64_t e);

static struct FreeMemRegion free_mem_region[50];
static struct Page free_memory;
static uint64_t memory_end;
uint64_t page_map;
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
    printk("end of memory: %x\n",memory_end);   /* This memory_end should be align in 2MB */
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

static PDPTR find_pml4t_entry(uint64_t map, uint64_t v, int alloc, uint32_t attribute)
{   /* find specific pml4 table entry according to the VA */

    PDPTR *map_entry = (PDPTR*)map;
    PDPTR pdptr = NULL;
    unsigned int index = (v >> 39) & 0x1FF;

    if ((uint64_t)map_entry[index] & PTE_P) { /* if it already has page */
        pdptr = (PDPTR)P2V(PDE_ADDR(map_entry[index]));       
    } 
    else if (alloc == 1) { /* when P == 0 */
        pdptr = (PDPTR)kalloc();          
        if (pdptr != NULL) {     
            memset(pdptr, 0, PAGE_SIZE);     
            map_entry[index] = (PDPTR)(V2P(pdptr) | attribute);           
        }
    } 

    return pdptr;    /* page directory pointer table */
}

static PD find_pdpt_entry(uint64_t map, uint64_t v, int alloc, uint32_t attribute)
{   /* find specific pdp table entry */
    /* if parameter "alloc" is 1, we create a page if it does exist */

    PDPTR pdptr = NULL;
    PD pd = NULL;
    unsigned int index = (v >> 30) & 0x1FF; /* index is at 30th bit */

    pdptr = find_pml4t_entry(map, v, alloc, attribute);
    if (pdptr == NULL)
        return NULL;
       
    if ((uint64_t)pdptr[index] & PTE_P) { /* if it already has page */  
        pd = (PD)P2V(PDE_ADDR(pdptr[index]));      
    }
    else if (alloc == 1) { /* when P == 0 */
        pd = (PD)kalloc();
        if (pd != NULL) {    
            memset(pd, 0, PAGE_SIZE);       
            pdptr[index] = (PD)(V2P(pd) | attribute);
        }
    } 

    return pd;
}

bool map_pages(uint64_t map, uint64_t v, uint64_t e, uint64_t pa, uint32_t attribute)
{ /* mapping to PA */
    uint64_t vstart = PA_DOWN(v);   /* saving aligned virtual address */
    uint64_t vend = PA_UP(e);       /* '' */
    PD pd = NULL;
    unsigned int index;

    ASSERT(v < e); /* start < end */
    ASSERT(pa % PAGE_SIZE == 0); /* aligned */
    ASSERT(pa+vend-vstart <= 1024*1024*1024); /* if it excess 1G */

    do {
        /* first : find "page directory pointer table" */
        pd = find_pdpt_entry(map, vstart, 1, attribute);    
        if (pd == NULL) {
            return false; /* Not found */
        }

        index = (vstart >> 21) & 0x1FF; /* index bit starts from 21th bit : 9 bit */
        ASSERT(((uint64_t)pd[index] & PTE_P) == 0); /* if PTE_P is 0 => it cannot be happened */

        pd[index] = (PDE)(pa | attribute | PTE_ENTRY);

        vstart += PAGE_SIZE;
        pa += PAGE_SIZE;
    } while (vstart + PAGE_SIZE <= vend);
  
    return true;
}

void switch_vm(uint64_t map)
{   /* load cr3 register with the new translation table */

    load_cr3(V2P(map));   
}

static void setup_kvm(void)
{   /* remap our kernel using 2m pages */

    page_map = (uint64_t)kalloc(); /* allocate new free page */
    ASSERT(page_map != 0);

    memset((void*)page_map, 0, PAGE_SIZE); /* zero the page */       
    bool status = map_pages(page_map, KERNEL_BASE, memory_end, V2P(KERNEL_BASE), PTE_P|PTE_W);
    /* PML4 Table, start address, end address(kernel), physical address of kernel, Attribute(readable, writable, not accessible by user) */
    ASSERT(status == true);
}

void init_kvm(void)
{
    setup_kvm();
    switch_vm(page_map);
    printk("Memory manager is working now");
}

void free_pages(uint64_t map, uint64_t vstart, uint64_t vend)
{   /* reverse process of mapping pages */

    unsigned int index; 

    ASSERT(vstart % PAGE_SIZE == 0); /* check whether start and end aligned */
    ASSERT(vend % PAGE_SIZE == 0);

    do {
        PD pd = find_pdpt_entry(map, vstart, 0, 0);
        /* free the existing page */
        if (pd != NULL) {
            index = (vstart >> 21) & 0x1FF;
            ASSERT(pd[index] & PTE_P); /* should be exist */          
            kfree(P2V(PTE_ADDR(pd[index])));
            pd[index] = 0;
        }

        vstart += PAGE_SIZE;
    } while (vstart+PAGE_SIZE <= vend);
}

static void free_pdt(uint64_t map)
{   /* look through the pml4 table */

    PDPTR *map_entry = (PDPTR*)map;

    for (int i = 0; i < 512; i++) {
        if ((uint64_t)map_entry[i] & PTE_P) {            
            PD *pdptr = (PD*)P2V(PDE_ADDR(map_entry[i]));
            
            for (int j = 0; j < 512; j++) {
                if ((uint64_t)pdptr[j] & PTE_P) {
                    kfree(P2V(PDE_ADDR(pdptr[j])));
                    pdptr[j] = 0;
                }
            }
        }
    }
}

static void free_pdpt(uint64_t map)
{
    PDPTR *map_entry = (PDPTR*)map;

    for (int i = 0; i < 512; i++) {
        if ((uint64_t)map_entry[i] & PTE_P) {          
            kfree(P2V(PDE_ADDR(map_entry[i])));
            map_entry[i] = 0;
        }
    }
}

static void free_pml4t(uint64_t map)
{
    kfree(map);
}

void free_vm(uint64_t map)
{   
    //free_pages(map,vstart,vend); /* dosen't have process and user space, yet. */
    free_pdt(map);
    free_pdpt(map);
    free_pml4t(map);
    printk("Freed VM");
}