#include <stdbool.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>

#include "../../include/pim.h"
#include "pim_mem.h"

void _real_free(void);

#define PAGE_SIZE 4096
#define PAGE_SHIFT 12
#define NUM_PAGES 512 /* HUGE_PAGE_SIZE / PAGE_SIZE */

/* Record keeping for pim_mem */
typedef struct __pim_mem {
    /* The number of page to guarantee physically continuity */
    uint ncont_page;

    /* The total number of lists in the mem_pool, whether or not available */
    uint ntotal_mem_pools;

    /* Double-linked mem_pool */
    struct mem_pool *curr_mem_pool;
    struct mem_pool *head_mem_pool;
    struct mem_pool *tail_mem_pool;
} _pim_mem;
static _pim_mem pim_mem;

/* 
 * Record keeping for mem_pool 
 * mem_pool manages page
 * Size of mem_pool is 2MB (Huge page size)
 */
struct mem_pool {
    void *start_va;
#ifdef DEBUG_PIM_MEM
    uint index;
#endif
    /* Indicates the start of the unused page */
    uint32_t curr_idx;

    /* The number of available lists in the mem_pool */
    uint32_t nfree_pages;

    /* This flag means large allocated mem_pool */
    bool large_mem_pool;

    struct page *head_page;

    /* Linked list mem_pool */
    struct mem_pool *next;
    struct mem_pool *prev;

    /* 
     * Bit vetor for used flag of page (512bits)
     * For architecture compatibility, use char type bit-vector instead of AVX2 
     */
    char bit_vector[NUM_PAGES + 1];
};

/* Page structure */
struct page {
    void *addr;
#ifdef DEBUG_PIM_MEM
    uint index;
#endif
    /* Since the argument of pim_free has no size, we need it for tracking */
    uint32_t alloc_size;
};


/* TODO: implement atomic RD/WR */
#define update_member_pim_mem(member, value) \
    pim_mem.member = value

#define get_member_pim_mem(member) \
    pim_mem.member

#define init_pim_mem()       \
    pim_mem.ntotal_mem_pools = 0; \
    pim_mem.curr_mem_pool = NULL; \
    pim_mem.head_mem_pool = NULL; \
    pim_mem.tail_mem_pool = NULL;


#define ASSERT_PRINT(fmt, ...) \
    printf(fmt, ##__VA_ARGS__); \
    assert(0);

#define list_for_prev(pos) \
    for (; pos != NULL; pos=pos->prev)

#define list_for_next(pos) \
    for (; pos != NULL; pos=pos->next)

#define list_for_next_value(pos, value) \
    for (uint32_t i = 0; i < value; i++, pos=pos->next)

#define list_add_tail(new_mem_pool, curr_mem_pool, tail_mem_pool) \
    new_mem_pool->prev = tail_mem_pool; \
    tail_mem_pool->next = new_mem_pool; \
    curr_mem_pool = new_mem_pool;

#define container_of(ptr, type, member) ({          \
    void *__mptr = (void *)(ptr);                   \
    ((type *)(__mptr - offsetof(type, member))); })


/*
 * Find the first occurrence of find in s, where the search is limited to the
 * first slen characters of s.
 */
static inline char *_strnstr(const char *s, const char *find, size_t slen)
{
    char c, sc;
    size_t len;

    if ((c = *find++) != '\0') {
        len = strlen(find);
        do {
            do {
                if (slen-- < 1 || (sc = *s++) == '\0')
                    return (NULL);
            } while (sc != c);
            if (len > slen)
                return (NULL);
        } while (strncmp(s, find, len) != 0);
        s--;
    }
    return ((char *)s);
}

/* Set the value of the bit_vector to 1 as many as the number of nalloc_pages 
 * bit_vector value
 *   1 means in use
 *   0 means free
 */
static inline int _set_bit_vector(struct mem_pool *curr_mem_pool, int nalloc_pages)
{
    uint64_t idx = -1;
    char free_flag[nalloc_pages + 1];
    memset(free_flag, '0', nalloc_pages * sizeof(char));
    free_flag[nalloc_pages] = '\0';

    PIM_MEM_LOG("\t  set_bit_vector\n");
    PIM_MEM_LOG("BIT[%d]:  %s \n", curr_mem_pool->index, curr_mem_pool->bit_vector);
    PIM_MEM_LOG("alloc: %d \n", nalloc_pages);
    /* 
     * Divide into 2 rounds to reduce search complexity.
     * First round: find enough page from current index to end [idx:512]
     */
    char *ptr =strstr(curr_mem_pool->bit_vector + curr_mem_pool->curr_idx, free_flag);
    if (ptr) {
        char used_flag[nalloc_pages + 1];
        memset(used_flag, '1', nalloc_pages * sizeof(char));
        used_flag[nalloc_pages] = '\0';
        idx = (uint64_t)ptr - (uint64_t)(curr_mem_pool->bit_vector);
        strncpy(curr_mem_pool->bit_vector + idx, used_flag, nalloc_pages);
        PIM_MEM_LOG("used: %s \n", used_flag);
        PIM_MEM_LOG("free: %s \n", free_flag);
        PIM_MEM_LOG("BIT[%d]:  %s \n", curr_mem_pool->index, curr_mem_pool->bit_vector);
        curr_mem_pool->nfree_pages = curr_mem_pool->nfree_pages - nalloc_pages;
        curr_mem_pool->curr_idx = idx + nalloc_pages;
    } else {
        /* Second round: find enough page from start to current index [0:idx-1] */
        PIM_MEM_LOG("NO FIND first round \n");
        char *ptr =_strnstr(curr_mem_pool->bit_vector, free_flag, curr_mem_pool->curr_idx - 1);
        if (ptr) {
            char used_flag[nalloc_pages + 1];
            memset(used_flag, '1', nalloc_pages * sizeof(char));
            used_flag[nalloc_pages] = '\0';
            idx = (uint64_t)ptr - (uint64_t)(curr_mem_pool->bit_vector);
            strncpy(curr_mem_pool->bit_vector + idx, used_flag, nalloc_pages);
            PIM_MEM_LOG("BIT[%d]:  %s \n", curr_mem_pool->index, curr_mem_pool->bit_vector);
            curr_mem_pool->nfree_pages = curr_mem_pool->nfree_pages - nalloc_pages;
            curr_mem_pool->curr_idx = idx + nalloc_pages;
        } else {
            PIM_MEM_LOG("NO FIND second round \n");
        }
    }
    return idx;
}

/* Clear the value of the bit_vector to 0 as many as the number of nalloc_pages */
static inline void _clr_bit_vector(struct mem_pool *mem_pool, int idx, int nalloc_pages)
{
    char free_flag[nalloc_pages + 1];
    memset(free_flag, '0', nalloc_pages * sizeof(char));
    free_flag[nalloc_pages] = '\0';

    PIM_MEM_LOG("\nclr_bit_vector\n");
    PIM_MEM_LOG("BIT[%d]:  %s \n", mem_pool->index, mem_pool->bit_vector);
    PIM_MEM_LOG("free: %s \n", free_flag);
    PIM_MEM_LOG("alloc: %d \n", nalloc_pages);
    PIM_MEM_LOG("IDX: %d \n", idx);

    strncpy(mem_pool->bit_vector + idx, free_flag, nalloc_pages);
    mem_pool->curr_idx = idx;
    mem_pool->nfree_pages = mem_pool->nfree_pages + nalloc_pages;    

    PIM_MEM_LOG("BIT[%d]:  %s \n", mem_pool->index, mem_pool->bit_vector);
    PIM_MEM_LOG("CURR_IDX: %u \n", mem_pool->curr_idx);

}


/* New mem_pool allocator */
static struct mem_pool *_mem_pool_allocation()
{
    struct mem_pool *mem_pool_obj;
    mem_pool_obj = malloc(sizeof(struct mem_pool));
    if (mem_pool_obj == NULL) {
        ASSERT_PRINT("Internal Error during malloc \n");
    }

    // Memory allocation to PIM driver (Huge page or IO mapping)
    mem_pool_obj->start_va = mmap_drv(HUGE_PAGE_SIZE);
    if (mem_pool_obj->start_va == NULL) {
        ASSERT_PRINT("Out-of memory \n");
    }

    struct page *page_obj = (struct page *)malloc(sizeof(struct page) * NUM_PAGES);
    if (page_obj == NULL) {
        printf("Internal Error during malloc \n");
        return NULL;
    }    
    for (int i = 0; i < NUM_PAGES; i++) {
        page_obj[i].addr = mem_pool_obj->start_va + (i * PAGE_SIZE);
    #ifdef DEBUG_PIM_MEM
        page_obj[i].index = i;
    #endif
    }
    mem_pool_obj->next = mem_pool_obj->prev = NULL;
    mem_pool_obj->curr_idx = 0;
    memset(mem_pool_obj->bit_vector, '0', NUM_PAGES * sizeof(char));
    mem_pool_obj->bit_vector[NUM_PAGES] = '\0';    
    mem_pool_obj->head_page = &page_obj[0];
    mem_pool_obj->nfree_pages = NUM_PAGES;
    #ifdef DEBUG_PIM_MEM
        mem_pool_obj->index = get_member_pim_mem(ntotal_mem_pools);
    #endif        
    mem_pool_obj->large_mem_pool = false;
    update_member_pim_mem(ntotal_mem_pools, get_member_pim_mem(ntotal_mem_pools) + 1);
    PIM_MEM_LOG("    New mem_pool: %d - nfree_pages:%d/%d \n", mem_pool_obj->index, mem_pool_obj->nfree_pages, NUM_PAGES);
    return mem_pool_obj;
}

/* New mem_pool allocator */
static struct mem_pool *_large_mem_pool_allocation(struct mem_pool *curr_mem_pool, uint32_t num_mem_pool)
{
    void *large_mem_pool = NULL; 
    struct mem_pool *ret_obj = NULL;
    struct mem_pool *mem_pool_obj[num_mem_pool];
    struct page *page_obj;
    PIM_MEM_LOG("Large mem_pool :%d \n", num_mem_pool);

    large_mem_pool = mmap_drv(HUGE_PAGE_SIZE * num_mem_pool);
    if (large_mem_pool == NULL) {
        ASSERT_PRINT("Out-of memory (large-mem_pool) \n");
    }
    for (size_t i = 0; i < num_mem_pool; i++) {
        mem_pool_obj[i] = malloc(sizeof(struct mem_pool));
        if (mem_pool_obj[i] == NULL) {
            ASSERT_PRINT("Internal Error during malloc \n");
        }
        mem_pool_obj[i]->start_va = large_mem_pool + (i * HUGE_PAGE_SIZE);
        PIM_MEM_LOG("start_va[%lu]: %p \n", i, mem_pool_obj[i]->start_va);
        mem_pool_obj[i]->next = mem_pool_obj[i]->prev = NULL;
        page_obj = (struct page *)malloc(sizeof(struct page) * NUM_PAGES);
        if (page_obj == NULL) {
            ASSERT_PRINT("Internal Error during malloc \n");
        }        
        for (int j = 0; j < NUM_PAGES; j++) {
            page_obj[j].addr = mem_pool_obj[i]->start_va + (j * PAGE_SIZE); // Address is virtual address
        #ifdef DEBUG_PIM_MEM
            page_obj[j].index = j;
        #endif
        }
        mem_pool_obj[i]->curr_idx = 0;
        memset(mem_pool_obj[i]->bit_vector, '0', NUM_PAGES * sizeof(char));
        mem_pool_obj[i]->bit_vector[NUM_PAGES] = '\0';
        mem_pool_obj[i]->head_page = &page_obj[0];
        mem_pool_obj[i]->nfree_pages = 0;
        mem_pool_obj[i]->large_mem_pool = true;
        #ifdef DEBUG_PIM_MEM        
            mem_pool_obj[i]->index = get_member_pim_mem(ntotal_mem_pools);
        #endif
        update_member_pim_mem(ntotal_mem_pools, get_member_pim_mem(ntotal_mem_pools) + 1);
        if (i == 0) {
            ret_obj = mem_pool_obj[i];
            PIM_MEM_LOG("    mem_pool_obj[%lu]:%p (RET: %d) \n", i, mem_pool_obj[i], ret_obj->index);
        }
        PIM_MEM_LOG("    New Large mem_pool: %d (nfree_pages:%d/%d)\n", mem_pool_obj[i]->index, mem_pool_obj[i]->nfree_pages, NUM_PAGES);

        PIM_MEM_LOG("    NEW: %d, CURR: %d , TAIL: %d \n", mem_pool_obj[i]->index, curr_mem_pool->index, get_member_pim_mem(tail_mem_pool)->index);
        list_add_tail(mem_pool_obj[i], curr_mem_pool, get_member_pim_mem(tail_mem_pool));
        PIM_MEM_LOG("    NEW: %d, CURR: %d , TAIL: %d \n", mem_pool_obj[i]->index, curr_mem_pool->index, get_member_pim_mem(tail_mem_pool)->index);
        update_member_pim_mem(tail_mem_pool, curr_mem_pool);
        PIM_MEM_LOG("    CURR: %d , TAIL: %d (RET: %d) \n", curr_mem_pool->index, get_member_pim_mem(tail_mem_pool)->index, ret_obj->index);
    }
    // Clear large_mem_pool flag of the last generated mem_pool
    mem_pool_obj[num_mem_pool-1]->large_mem_pool = false;
    ret_obj->head_page[0].alloc_size = NUM_PAGES;
    return ret_obj;
}

/* External function */
void *pim_malloc(size_t size)
{
#ifndef __PIM_MALLOC__
    //return  mmap(0x0, size, (PROT_READ | PROT_WRITE), MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    return malloc(size);
#else
    void *ret_ptr=NULL;
    int idx = 0;
    uint nalloc_pages = 0;    
    /* Initialization mem_pool */
    if (get_member_pim_mem(curr_mem_pool) == NULL) {
        // Initialization PIM driver
        __init_pim_drv();
        atexit(_real_free);
        struct mem_pool *new_mem_pool = _mem_pool_allocation();
        update_member_pim_mem(curr_mem_pool, new_mem_pool);
        update_member_pim_mem(head_mem_pool, new_mem_pool);
        update_member_pim_mem(tail_mem_pool, new_mem_pool);
    }
    struct mem_pool *head_mem_pool = get_member_pim_mem(head_mem_pool);
    struct mem_pool *curr_mem_pool = get_member_pim_mem(curr_mem_pool);
    nalloc_pages = size / PAGE_SIZE ? (size / PAGE_SIZE) : 1;
    nalloc_pages = size % PAGE_SIZE ? nalloc_pages + 1 : nalloc_pages;
    PIM_MEM_LOG("\n pim_malloc, size = %lu (%d-page) --> \n", size, nalloc_pages);

    if (size > HUGE_PAGE_SIZE) {
        /* Large mem_pool allocator */
        uint64_t tmp = size / HUGE_PAGE_SIZE;
        uint32_t num_mem_pool = size % HUGE_PAGE_SIZE ? (tmp+1) : tmp;
        PIM_MEM_LOG("Num mem_pool: %d (Size:%lu) \n", num_mem_pool, size);
        uint32_t cnt = 0;
        bool find_mem_pool = false;
        struct mem_pool *tail_mem_pool = get_member_pim_mem(tail_mem_pool);
        list_for_next(tail_mem_pool) {
            PIM_MEM_LOG("\t Search large mem_pool[CHUNK:%d] - page:%d \n", tail_mem_pool->index, tail_mem_pool->nfree_pages);
            /* Allocation of large mem_pool must guarantee virtual address continuous */
            if ((tail_mem_pool->nfree_pages == NUM_PAGES) && (tail_mem_pool->prev && (tail_mem_pool->prev->nfree_pages == NUM_PAGES))) {
                cnt++;
            } else {
                cnt = 0;
            }
            if (cnt == (num_mem_pool - 1)) {
                find_mem_pool = true;
                tail_mem_pool = tail_mem_pool->prev;
                break;
            }
        }
        if (find_mem_pool) {
            ret_ptr = tail_mem_pool->head_page[0].addr;
            update_member_pim_mem(curr_mem_pool, tail_mem_pool);            
            PIM_MEM_LOG("\t\t Find large mem_pool [CHUNK:%d] (num_mem_pool:%d)\n", tail_mem_pool->index, num_mem_pool);
            list_for_next_value(tail_mem_pool, num_mem_pool) {
                tail_mem_pool->large_mem_pool = true;
                tail_mem_pool->nfree_pages = 0;
            }
        } else {
            /* If there is no large mem_pool with enough page, mem_pool expansion is required */
            struct mem_pool *tmp_mem_pool = _large_mem_pool_allocation(curr_mem_pool, num_mem_pool);
            ret_ptr = tmp_mem_pool->head_page[0].addr;
            update_member_pim_mem(curr_mem_pool, tmp_mem_pool);
        }
        goto done;
    } else if (nalloc_pages > curr_mem_pool->nfree_pages) {
        PIM_MEM_LOG("Full (%d / %d)\n", nalloc_pages, curr_mem_pool->nfree_pages);
        goto find_mem_pool;
    } else {
        /* 
            Scenario 1: Not a large mem_pool size
            Scenario 2: There is enough page in the curr_mem_pool
         */
        head_mem_pool = curr_mem_pool;
    }

find_mem_pool:
    /* Search if there are enough free_lists from head to tail mem_pool */
    list_for_next(head_mem_pool) {
        PIM_MEM_LOG("\t Search mem_pool[CHUNK:%d] - num_free:%d/512 \n", head_mem_pool->index, head_mem_pool->nfree_pages);
        if (nalloc_pages <= head_mem_pool->nfree_pages) {
            PIM_MEM_LOG("\t Find [CHUNK:%d]\n", head_mem_pool->index);
            break;
        }
    }
    if (head_mem_pool == NULL) {
        /* If there is no mem_pool with enough page, mem_pool expansion is required */
        PIM_MEM_LOG("\t\tCould not find mem_pool with enough page\n");
        struct mem_pool *new_mem_pool = _mem_pool_allocation();
        list_add_tail(new_mem_pool, head_mem_pool, get_member_pim_mem(tail_mem_pool));
        update_member_pim_mem(tail_mem_pool, head_mem_pool);
    }
    idx = _set_bit_vector(head_mem_pool, nalloc_pages);
    PIM_MEM_LOG("\t\tset_used[CHUNK:%d] nalloc_pages: %d, (idx:%d) \n", head_mem_pool->index, nalloc_pages, idx);
    if (idx < 0) {
        head_mem_pool = head_mem_pool->next;
        goto find_mem_pool;
    }
    ret_ptr = head_mem_pool->head_page[idx].addr;
    head_mem_pool->head_page[idx].alloc_size = nalloc_pages;
    update_member_pim_mem(curr_mem_pool, head_mem_pool);
done:
    PIM_MEM_LOG(" Complete return VA: %p (Remain page: %d/%d) (ALLOC_SIZE:%d) \n\n", ret_ptr,  head_mem_pool->nfree_pages, NUM_PAGES, head_mem_pool->head_page[idx].alloc_size);
    return ret_ptr;
#endif
}

/* 
 * External function
 * pim_free function does not really free the FPGA DRAM
 * Only initialization of mem_pool and page structure is executed
 */
void pim_free(void *addr)
{
#ifndef __PIM_MALLOC__
    free(addr);
#else
    struct mem_pool *head_mem_pool = get_member_pim_mem(head_mem_pool);

    PIM_MEM_LOG("\n pim_free, addr: %lx\n", (uint64_t)addr);
    /* 
     * Find free page
     */
    list_for_next(head_mem_pool) {
        // First, find mem_pool using address range [mem_pool_start < addr < mem_pool_end]
        PIM_MEM_LOG("Search CHUNK[%d] - %p \n", head_mem_pool->index, head_mem_pool->start_va);
        if ((head_mem_pool->start_va <= addr) &&
            ((head_mem_pool->start_va + HUGE_PAGE_SIZE - 1) >= addr)) {

            if (head_mem_pool->large_mem_pool == true) {
                goto need_free;
            }
            // Second, calculate page address
            uint64_t page_idx = (((uint64_t)(addr - head_mem_pool->start_va)) >> PAGE_SHIFT);
            struct page *curr_page= &head_mem_pool->head_page[page_idx];
            uint32_t free_size = curr_page->alloc_size;
            if (free_size == 0) {
                ASSERT_PRINT("Free size can never be zero! \n");
            }
            PIM_MEM_LOG("\tFind Addr [CHUNK:%d][LIST:%d - %p] (VA: %p, HEAD: %p) \n", head_mem_pool->index, curr_page->index, curr_page, head_mem_pool->start_va, head_mem_pool->head_page);
            PIM_MEM_LOG("\t                     (free_size:%u, page_idx:%lu)\n", free_size, page_idx);
            _clr_bit_vector(head_mem_pool, page_idx, free_size);
            goto done_free;
        }
    }
    ASSERT_PRINT("Free address not found ! \n");
need_free:
    list_for_next(head_mem_pool) {
        head_mem_pool->nfree_pages = NUM_PAGES;
        PIM_MEM_LOG("\t\t CON'T Find Addr [CHUNK:%d] (VA: %p) (Free:%u/512) \n", head_mem_pool->index, head_mem_pool->start_va, head_mem_pool->nfree_pages);
        if (!head_mem_pool->large_mem_pool) {
            goto done_free;
        }
        else {
            head_mem_pool->large_mem_pool = false;
        }
    }
done_free:
#endif
    return;
}

/* _real_free function munmap the FPGA DRAM and initialize global mem_pool
 * When the process that called the pim_malloc function ends, this function is automatically executed
 * TODO: atexit function change to GC
 */
void _real_free(void)
{
    PIM_MEM_LOG("\n EXIT (PID: %d)\n", getpid());

    struct mem_pool *head_mem_pool = get_member_pim_mem(head_mem_pool);
    struct mem_pool *tmp;

    while (head_mem_pool != NULL)
    {
        tmp = head_mem_pool;
        head_mem_pool = head_mem_pool->next;
        struct page *head_page = tmp->head_page;
        PIM_MEM_LOG("Free Chunk [%d] %p, %p \n", tmp->index, tmp, head_page);
        free(head_page);
        PIM_MEM_LOG("\n");
        free(tmp);
    }    
    __release_pim_drv();
    init_pim_mem();
}