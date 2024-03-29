#include "trap.h"
#include "print.h"
#include "syscall.h"
#include "process.h"
#include "keyboard.h"

static struct IdtPtr idt_pointer;
static struct IdtEntry vectors[256];
static uint64_t ticks;

static void init_idt_entry(struct IdtEntry *entry, uint64_t addr, uint8_t attribute)
{
    entry->low = (uint16_t)addr;
    entry->selector = 8;    /* what for? */
    entry->attr = attribute;
    entry->mid = (uint16_t)(addr>>16);
    entry->high = (uint32_t)(addr>>32);
}

void init_idt(void)
{
    init_idt_entry(&vectors[0],(uint64_t)vector0,0x8e); /* attribute is 0x8e */
    init_idt_entry(&vectors[1],(uint64_t)vector1,0x8e);
    init_idt_entry(&vectors[2],(uint64_t)vector2,0x8e);
    init_idt_entry(&vectors[3],(uint64_t)vector3,0x8e);
    init_idt_entry(&vectors[4],(uint64_t)vector4,0x8e);
    init_idt_entry(&vectors[5],(uint64_t)vector5,0x8e);
    init_idt_entry(&vectors[6],(uint64_t)vector6,0x8e);
    init_idt_entry(&vectors[7],(uint64_t)vector7,0x8e);
    init_idt_entry(&vectors[8],(uint64_t)vector8,0x8e);
    init_idt_entry(&vectors[10],(uint64_t)vector10,0x8e);
    init_idt_entry(&vectors[11],(uint64_t)vector11,0x8e);
    init_idt_entry(&vectors[12],(uint64_t)vector12,0x8e);
    init_idt_entry(&vectors[13],(uint64_t)vector13,0x8e);
    init_idt_entry(&vectors[14],(uint64_t)vector14,0x8e);
    init_idt_entry(&vectors[16],(uint64_t)vector16,0x8e);
    init_idt_entry(&vectors[17],(uint64_t)vector17,0x8e);
    init_idt_entry(&vectors[18],(uint64_t)vector18,0x8e);
    init_idt_entry(&vectors[19],(uint64_t)vector19,0x8e);
    init_idt_entry(&vectors[32],(uint64_t)vector32,0x8e);
    init_idt_entry(&vectors[33],(uint64_t)vector33,0x8e);
    init_idt_entry(&vectors[39],(uint64_t)vector39,0x8e);
    init_idt_entry(&vectors[0x80],(uint64_t)sysint,0xee); /* Different is DPL is set ot 3 */

    idt_pointer.limit = sizeof(vectors)-1;
    idt_pointer.addr = (uint64_t)vectors;
    load_idt(&idt_pointer);
}

uint64_t get_ticks(void)
{
    return ticks;
}

static void timer_handler(void)
{
    ticks++;
    wake_up(-1);
}

void handler(struct TrapFrame *tf)
{
    unsigned char isr_value;

    switch (tf->trapno) {   /* only dealed with vector 32 and 39 */
        case 32:    /* Timer interrupt */
            timer_handler();
            eoi();  /* end of interrupt */
            break;
        
        case 33:    /* keyboard interrupt */
            keyboard_handler();
            eoi();  /* if no eoi() we will not receive keyboard interrupt after we reture */
            break;

        case 39:    /* spurious interrupt */
            isr_value = read_isr(); /* check whether it's real interrupt */
            if ((isr_value&(1<<7)) != 0) {
                eoi();  /* real interrupt */
            }
            break;  /* spurious interrupt -> ignore and just return */
        
        case 0x80:
            system_call(tf);
            break;

        default:
            if ((tf->cs & 3) == 3){ /* when error in user program */
                printk("Exception is %d\n", tf->trapno);
                exit();
            }
            else { /* when error in kernel program */
                while (1) { } /* halt the system */
            }
            //printk("[Error %d at ring %d] %d:%x %x", tf->trapno, (tf->cs & 3), tf->errorcode, read_cr2(), tf->rip);
    }

    if(tf->trapno == 32){
        yield();
    }
}