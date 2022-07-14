#include "process.h"
#include "trap.h"
#include "memory.h"
#include "print.h"
#include "lib.h"
#include "debug.h"

extern struct TSS Tss; 
static struct Process process_table[NUM_PROC];
static int pid_num = 1;
static struct ProcessControl pc; /* ready list + current process */

static void set_tss(struct Process *proc)
{
    Tss.rsp0 = proc->stack + STACK_SIZE;    
}

static struct Process* find_unused_process(void)
{
    struct Process *process = NULL; /* NULL if all process is used */

    for (int i = 0; i < NUM_PROC; i++) {
        if (process_table[i].state == PROC_UNUSED) {
            process = &process_table[i];
            break;
        }
    }

    return process;
}

static void set_process_entry(struct Process *proc, uint64_t addr)
{
    uint64_t stack_top;

    proc->state = PROC_INIT;
    proc->pid = pid_num++;

    proc->stack = (uint64_t)kalloc();
    ASSERT(proc->stack != 0);

    memset((void*)proc->stack, 0, PAGE_SIZE);   
    stack_top = proc->stack + STACK_SIZE; /* stack grows downward */

    proc->context = stack_top - sizeof(struct TrapFrame) - 7*8;
    *(uint64_t*)(proc->context + 6*8) = (uint64_t)TrapReturn; /* save TrapReturn where rsp+48 which get return address*/

    proc->tf = (struct TrapFrame*)(stack_top - sizeof(struct TrapFrame)); 
    proc->tf->cs = 0x10|3;
    proc->tf->rip = 0x400000;
    proc->tf->ss = 0x18|3;
    proc->tf->rsp = 0x400000 + PAGE_SIZE;
    proc->tf->rflags = 0x202;
    
    proc->page_map = setup_kvm(); /* new kernel VM for process */
    ASSERT(proc->page_map != 0);
    ASSERT(setup_uvm(proc->page_map, P2V(addr), 5120));    
    proc->state = PROC_READY;
}

static struct ProcessControl* get_pc(void)
{
    return &pc;
}

void init_process(void)
{   
    
    struct ProcessControl *process_control;
    struct Process *process;
    struct HeadList *list;
    uint64_t addr[2] = {0x20000, 0x30000}; /* two user program in 0x20000 and 0x30000 */

    process_control = get_pc();
    list = &process_control->ready_list;

    for (int i = 0; i < 2; i++) {
        /* for loop to find unused process */
        process = find_unused_process();
        set_process_entry(process, addr[i]);
        /* first arg for process to init and second arg for address of user program */
        append_list_tail(list, (struct List*)process);
    }
}

void launch(void)
{   
    struct ProcessControl *process_control;
    struct Process *process;

    process_control = get_pc();
    process = (struct Process*)remove_list_head(&process_control->ready_list);
    process->state = PROC_RUNNING;
    process_control->current_process = process;

    set_tss(&process_table[0]);
    switch_vm(process_table[0].page_map);
    pstart(process_table[0].tf); /* jump to trap return */
}


static void switch_process(struct Process *prev, struct Process *current)
{
    set_tss(current);
    switch_vm(current->page_map);
    swap(&prev->context, current->context);
}

static void schedule(void)
{
    struct Process *prev_proc;
    struct Process *current_proc;
    struct ProcessControl *process_control;
    struct HeadList *list;

    process_control = get_pc();
    prev_proc = process_control->current_process;
    list = &process_control->ready_list;
    ASSERT(!is_list_empty(list));
    
    current_proc = (struct Process*)remove_list_head(list);
    current_proc->state = PROC_RUNNING;   
    process_control->current_process = current_proc;

    switch_process(prev_proc, current_proc);   
}

void yield(void)
{   /* called when timer interrupt fired */

    struct ProcessControl *process_control;
    struct Process *process;
    struct HeadList *list;
    
    process_control = get_pc();
    list = &process_control->ready_list;

    if (is_list_empty(list)) { /* when no other process in ready list */
        return;
    }

    process = process_control->current_process;
    process->state = PROC_READY;
    append_list_tail(list, (struct List*)process);
    schedule();
}
