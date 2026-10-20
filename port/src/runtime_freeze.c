/* Freeze report: when the game has not shown a new frame for TLG_FREEZE_REPORT_SECONDS
 * (default 10, 0 = off) a monitor thread writes, once per freeze, every thread of the process to
 * the log: its name, what it is blocked on (the wait slots of runtime_thread.c, marked by the
 * runtime's and the GPU library's blocking calls), where it is now (RIP) and its frame chain,
 * in guest offsets inside the game image. The game keeps running; the next report needs frames
 * to resume and stop again.
 * Registers: Linux sends SIGURG to each thread (the handler only copies its registers and frame
 * chain); Windows suspends each thread for GetThreadContext. Memory is read with
 * process_vm_readv / ReadProcessMemory, so a bad frame pointer cannot fault. */
#define _GNU_SOURCE
#include "runtime.h"
#include "gpu/tlggpu.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>
#include <sched.h>
#include <time.h>
#ifdef _WIN32
#include <windows.h>
#include <tlhelp32.h>
#else
#include <dirent.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <signal.h>
#include <ucontext.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/uio.h>
#endif

#define MAX_THREADS 1024
#define MAX_FRAMES 12

static uintptr_t image_base;
static uint64_t image_bytes;

/* Reads that fail instead of faulting (other threads' stacks, freed objects). */
static int safe_read(void *out, uintptr_t address, size_t size) {
    if (!address) return 0;
#ifdef _WIN32
    SIZE_T got = 0;
    return ReadProcessMemory(GetCurrentProcess(), (const void *)address, out, size, &got) && got == size;
#else
    struct iovec local = {out, size}, remote = {(void *)address, size};
    return process_vm_readv(getpid(), &local, 1, &remote, 1, 0) == (ssize_t)size;
#endif
}

/* Return addresses along a frame-pointer chain starting at frame (guest code keeps frame pointers). */
static unsigned walk_frames(uintptr_t frame, uintptr_t *out, unsigned max) {
    unsigned n = 0;
    while (n < max && frame) {
        uintptr_t pair[2];
        if (!safe_read(pair, frame, sizeof(pair)) || !pair[1]) break;
        out[n++] = pair[1];
        if (pair[0] <= frame || pair[0] - frame > (64u << 20)) break;
        frame = pair[0];
    }
    return n;
}

static void describe_address(char *out, size_t size, uintptr_t address) {
    if (image_base && address - image_base < image_bytes) {
        snprintf(out, size, "guest+0x%llx", (unsigned long long)(address - image_base));
        return;
    }
#ifdef _WIN32
    HMODULE module = NULL;
    char name[MAX_PATH];
    if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           (LPCSTR)address, &module) && module && GetModuleFileNameA(module, name, sizeof(name))) {
        const char *base = strrchr(name, '\\');
        snprintf(out, size, "%s+0x%llx", base ? base + 1 : name, (unsigned long long)(address - (uintptr_t)module));
        return;
    }
#else
    Dl_info where;
    if (dladdr((void *)address, &where) && where.dli_fname) {
        const char *base = strrchr(where.dli_fname, '/');
        snprintf(out, size, "%s+0x%llx%s%s%s", base ? base + 1 : where.dli_fname,
                 (unsigned long long)(address - (uintptr_t)where.dli_fbase),
                 where.dli_sname ? " (" : "", where.dli_sname ? where.dli_sname : "", where.dli_sname ? ")" : "");
        return;
    }
#endif
    snprintf(out, size, "0x%llx", (unsigned long long)address);
}

/* ---- Text that grows (the whole report is written at once) ---- */
typedef struct { char *data; size_t length, capacity; } Text;
static void add(Text *t, const char *format, ...) __attribute__((format(printf, 2, 3)));
static void add(Text *t, const char *format, ...) {
    for (;;) {
        va_list args;
        va_start(args, format);
        size_t room = t->capacity - t->length;
        int n = vsnprintf(t->data ? t->data + t->length : NULL, t->data ? room : 0, format, args);
        va_end(args);
        if (n < 0) return;
        if ((size_t)n < room) { t->length += (size_t)n; return; }
        size_t capacity = t->capacity ? t->capacity * 2 : 16384;
        while (capacity - t->length <= (size_t)n) capacity *= 2;
        char *grown = realloc(t->data, capacity);
        if (!grown) return;
        t->data = grown; t->capacity = capacity;
    }
}

/* ---- Wait description (unit-tested) ---- */
static const RuntimeThreadInfo *find_record(const RuntimeThreadInfo *threads, size_t count, const void *record) {
    for (size_t i = 0; i < count; ++i) if (threads[i].record && threads[i].record == record) return &threads[i];
    return NULL;
}
static void describe_level(Text *t, const RuntimeWaitLevel *l, uint64_t now_ms,
                           const RuntimeThreadInfo *threads, size_t count) {
    uint64_t ms = now_ms >= l->since_ms ? now_ms - l->since_ms : 0;
    add(t, "%s", l->kind);
    if (l->name[0]) add(t, " '%s'", l->name);
    if (!strncmp(l->kind, "sleep", 5)) add(t, " of %llu us", (unsigned long long)(uintptr_t)l->object);
    else if (!strncmp(l->kind, "file", 4) && (uintptr_t)l->object < 0x10000) add(t, " (fd %u)", (unsigned)(uintptr_t)l->object);
    else if (!strncmp(l->kind, "semaphore", 9)) add(t, " id %llu", (unsigned long long)(uintptr_t)l->object);
    else if (l->object) add(t, " 0x%llx", (unsigned long long)(uintptr_t)l->object);
    add(t, " for %llu ms", (unsigned long long)ms);
    if (l->owner) {
        const void *holder = NULL;
        if (!safe_read(&holder, (uintptr_t)l->owner, sizeof(holder))) add(t, ", holder unknown");
        else if (!holder) add(t, ", not held now");
        else if (holder == (const void *)1) add(t, ", held by a host thread");
        else {
            const RuntimeThreadInfo *h = find_record(threads, count, holder);
            if (h) add(t, ", held by '%s' (tid %llu)", h->name, (unsigned long long)h->os_tid);
            else add(t, ", held by thread record 0x%llx", (unsigned long long)(uintptr_t)holder);
        }
    }
}
static void describe_wait(Text *t, const RuntimeWait *w, uint64_t now_ms, const RuntimeThreadInfo *threads, size_t count) {
    unsigned depth = w->depth < RUNTIME_WAIT_LEVELS ? w->depth : RUNTIME_WAIT_LEVELS;
    int shown = 0;
    /* Innermost first: what the thread is blocked on right now, then what it was doing. */
    for (unsigned i = depth; i-- > 0;) {
        const RuntimeWaitLevel *l = &w->level[i];
        if (!l->kind) continue;
        add(t, shown ? " (inside " : "waiting on ");
        describe_level(t, l, now_ms, threads, count);
        if (shown) add(t, ")");
        shown = 1;
    }
    if (!shown) add(t, "running (not in a marked wait)");
    if (w->depth > RUNTIME_WAIT_LEVELS) add(t, " (+%u nested waits)", w->depth - RUNTIME_WAIT_LEVELS);
}
void runtime_freeze_describe_wait(char *out, size_t size, const RuntimeWait *wait, uint64_t now_ms,
                                  const RuntimeThreadInfo *threads, size_t count) {
    Text t = {0};
    describe_wait(&t, wait, now_ms, threads, count);
    snprintf(out, size, "%s", t.data ? t.data : "");
    free(t.data);
}

int runtime_freeze_step(FreezeMonitor *m, uint64_t frames, uint64_t now_ms) {
    if (frames != m->last_frames) {
        const int resumed = m->reported;
        m->freeze_ms = now_ms - m->last_change_ms;
        m->last_frames = frames; m->last_change_ms = now_ms; m->reported = 0;
        return resumed ? 2 : 0;
    }
    /* Armed by the first frame: loading before it is not a freeze. */
    if (!frames || !m->seconds || m->reported) return 0;
    if (now_ms - m->last_change_ms < m->seconds * 1000) return 0;
    m->reported = 1;
    return 1;
}

/* ---- Registers of every thread ---- */
typedef struct {
    uint64_t tid;
    int captured;
    uintptr_t rip, rsp, rbp;
    unsigned frames;
    uintptr_t chain[MAX_FRAMES];
    char name[64];
} Capture;

static uint64_t own_tid(void) {
#ifdef _WIN32
    return GetCurrentThreadId();
#else
    return (uint64_t)gettid();
#endif
}

#ifndef _WIN32
static pid_t capture_tid;
static Capture *capture_out;
static int capture_done;
/* Async-signal-safe: registers and the frame chain into the capture the monitor waits on. */
static void capture_signal(int sig, siginfo_t *info, void *context) {
    (void)sig; (void)info;
    int saved = errno;
    if (__atomic_load_n(&capture_tid, __ATOMIC_ACQUIRE) == gettid()) {
        Capture *c = __atomic_load_n(&capture_out, __ATOMIC_ACQUIRE);
        const greg_t *g = ((ucontext_t *)context)->uc_mcontext.gregs;
        c->rip = (uintptr_t)g[REG_RIP]; c->rsp = (uintptr_t)g[REG_RSP]; c->rbp = (uintptr_t)g[REG_RBP];
        c->frames = walk_frames(c->rbp, c->chain, MAX_FRAMES);
        c->captured = 1;
        __atomic_store_n(&capture_done, 1, __ATOMIC_RELEASE);
    }
    errno = saved;
}
static size_t list_threads(Capture *out, size_t max) {
    size_t n = 0;
    DIR *dir = opendir("/proc/self/task");
    struct dirent *e;
    while (dir && n < max && (e = readdir(dir))) {
        long tid = strtol(e->d_name, NULL, 10);
        if (tid <= 0) continue;
        out[n] = (Capture){.tid = (uint64_t)tid};
        char path[64];
        snprintf(path, sizeof(path), "/proc/self/task/%ld/comm", tid);
        int fd = open(path, O_RDONLY);
        if (fd >= 0) {
            ssize_t got = read(fd, out[n].name, sizeof(out[n].name) - 1);
            close(fd);
            if (got > 0) out[n].name[got - (out[n].name[got - 1] == '\n')] = 0;
        }
        ++n;
    }
    if (dir) closedir(dir);
    return n;
}
static void capture(Capture *c) {
    __atomic_store_n(&capture_done, 0, __ATOMIC_RELEASE);
    __atomic_store_n(&capture_out, c, __ATOMIC_RELEASE);
    __atomic_store_n(&capture_tid, (pid_t)c->tid, __ATOMIC_RELEASE);
    if (!syscall(SYS_tgkill, getpid(), (pid_t)c->tid, SIGURG)) {
        /* A thread that blocks SIGURG never answers: 30 ms each at most. */
        for (int i = 0; i < 60 && !__atomic_load_n(&capture_done, __ATOMIC_ACQUIRE); ++i) {
            struct timespec nap = {0, 500000};
            nanosleep(&nap, NULL);
        }
    }
    __atomic_store_n(&capture_tid, 0, __ATOMIC_RELEASE);
}
#else
typedef HRESULT (WINAPI *GetDescription)(HANDLE, PWSTR *);
static size_t list_threads(Capture *out, size_t max) {
    size_t n = 0;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return 0;
    static GetDescription get_description;
    if (!get_description)
        get_description = (GetDescription)(void (*)(void))GetProcAddress(GetModuleHandleA("kernel32.dll"), "GetThreadDescription");
    THREADENTRY32 entry = {.dwSize = sizeof(entry)};
    const DWORD process = GetCurrentProcessId();
    for (BOOL ok = Thread32First(snapshot, &entry); ok && n < max; ok = Thread32Next(snapshot, &entry)) {
        if (entry.th32OwnerProcessID != process) continue;
        out[n] = (Capture){.tid = entry.th32ThreadID};
        HANDLE thread = get_description ? OpenThread(THREAD_QUERY_LIMITED_INFORMATION, FALSE, entry.th32ThreadID) : NULL;
        PWSTR wide = NULL;
        if (thread && SUCCEEDED(get_description(thread, &wide)) && wide) {
            WideCharToMultiByte(CP_UTF8, 0, wide, -1, out[n].name, sizeof(out[n].name), NULL, NULL);
            LocalFree(wide);
        }
        if (thread) CloseHandle(thread);
        ++n;
    }
    CloseHandle(snapshot);
    return n;
}
/* Suspended only for GetThreadContext and the frame reads (no locks are taken meanwhile). */
static void capture(Capture *c) {
    HANDLE thread = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT | THREAD_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)c->tid);
    if (!thread) return;
    if (SuspendThread(thread) != (DWORD)-1) {
        static CONTEXT context __attribute__((aligned(16)));
        memset(&context, 0, sizeof(context));
        context.ContextFlags = CONTEXT_CONTROL | CONTEXT_INTEGER;
        if (GetThreadContext(thread, &context)) {
            c->rip = (uintptr_t)context.Rip; c->rsp = (uintptr_t)context.Rsp; c->rbp = (uintptr_t)context.Rbp;
            c->frames = walk_frames(c->rbp, c->chain, MAX_FRAMES);
            c->captured = 1;
        }
        ResumeThread(thread);
    }
    CloseHandle(thread);
}
#endif

static void add_chain(Text *t, const uintptr_t *chain, unsigned frames) {
    char where[320];
    for (unsigned i = 0; i < frames; ++i) {
        describe_address(where, sizeof(where), chain[i]);
        add(t, "%s%s", i ? " < " : "", where);
    }
}
static void add_thread(Text *t, const Capture *c, const RuntimeThreadInfo *info, uint64_t now_ms,
                       const RuntimeThreadInfo *threads, size_t count) {
    char where[320];
    if (info && info->record) add(t, "  guest '%s' (tid %llu): ", info->name, (unsigned long long)c->tid);
    else add(t, "  host '%s' (tid %llu): ", c->name[0] ? c->name : "?", (unsigned long long)c->tid);
    if (info) describe_wait(t, &info->wait, now_ms, threads, count);
    else add(t, "no marked wait");
    add(t, "\n");
    if (c->captured) {
        describe_address(where, sizeof(where), c->rip);
        add(t, "      now at %s, rsp=0x%llx", where, (unsigned long long)c->rsp);
        if (c->frames) { add(t, "; frames: "); add_chain(t, c->chain, c->frames); }
        add(t, "\n");
    } else {
        add(t, "      registers not captured (the thread did not answer)\n");
    }
    /* The guest frames that called the marked wait (the import's own frame starts the chain). */
    if (info && info->wait.depth && info->wait.level[0].kind && info->wait.level[0].frame) {
        uintptr_t chain[MAX_FRAMES];
        unsigned frames = walk_frames(info->wait.level[0].frame, chain, MAX_FRAMES);
        if (frames) { add(t, "      wait called from "); add_chain(t, chain, frames); add(t, "\n"); }
    }
}

static TlgGpuFrameCounters counters_at_last_frame;
static void add_counters(Text *t) {
    TlgGpuFrameCounters now;
    tlggpu_frame_counters(&now);
    const TlgGpuFrameCounters *then = &counters_at_last_frame;
    add(t, "  frames: %llu flips submitted by the game (+%llu since the last shown frame), %llu shown, "
           "%llu presented (+%llu), %llu vblank ticks (+%llu); page faults being handled now: %llu (%llu handled, +%llu)\n",
        (unsigned long long)now.submitted, (unsigned long long)(now.submitted - then->submitted),
        (unsigned long long)now.shown, (unsigned long long)now.presented,
        (unsigned long long)(now.presented - then->presented), (unsigned long long)now.vblanks,
        (unsigned long long)(now.vblanks - then->vblanks), (unsigned long long)now.faults_in_progress,
        (unsigned long long)now.faults_handled, (unsigned long long)(now.faults_handled - then->faults_handled));
}

static pthread_mutex_t report_lock = PTHREAD_MUTEX_INITIALIZER;
void runtime_freeze_report(FILE *out, const char *head) {
    pthread_mutex_lock(&report_lock);
    Capture *caps = calloc(MAX_THREADS, sizeof(*caps));
    RuntimeThreadInfo *infos = calloc(MAX_THREADS, sizeof(*infos));
    Text t = {0};
    if (!caps || !infos) { free(caps); free(infos); pthread_mutex_unlock(&report_lock); return; }
    const size_t threads = list_threads(caps, MAX_THREADS);
    const uint64_t self = own_tid();
    for (size_t i = 0; i < threads; ++i) if (caps[i].tid != self) capture(&caps[i]);
    /* Wait slots after the registers: the waits shown are at least as old as the RIPs. */
    const uint64_t now_ms = runtime_wait_now_ms();
    const size_t records = runtime_thread_snapshot(infos, MAX_THREADS);
    add(&t, "%s", head);
    add_counters(&t);
    for (int pass = 0; pass < 2; ++pass) {
        for (size_t i = 0; i < threads; ++i) {
            if (caps[i].tid == self) continue;
            /* A live guest record with this OS thread id, else a host wait slot (ids are reused). */
            const RuntimeThreadInfo *info = NULL;
            for (size_t r = 0; r < records && !info; ++r)
                if (infos[r].record && !infos[r].finished && infos[r].os_tid == caps[i].tid) info = &infos[r];
            for (size_t r = 0; r < records && !info; ++r)
                if (!infos[r].record && infos[r].os_tid == caps[i].tid) info = &infos[r];
            const int guest = info && info->record;
            if (guest == (pass == 0)) add_thread(&t, &caps[i], info, now_ms, infos, records);
        }
    }
    add(&t, "FREEZE: end of report (%zu threads; the game keeps running)\n", threads);
    if (t.data) { fwrite(t.data, 1, t.length, out); fflush(out); }
    free(t.data); free(caps); free(infos);
    pthread_mutex_unlock(&report_lock);
}

/* ---- Monitor ---- */
static void sleep_ms(unsigned ms) {
#ifdef _WIN32
    Sleep(ms);
#else
    struct timespec t = {(time_t)(ms / 1000), (long)(ms % 1000) * 1000000};
    while (nanosleep(&t, &t) && errno == EINTR) {}
#endif
}
static void *monitor(void *argument) {
    FreezeMonitor *m = argument;
#ifndef _WIN32
    pthread_setname_np(pthread_self(), "tlg:freeze");
#endif
    const unsigned period = m->seconds >= 4 ? 1000 : (unsigned)m->seconds * 250;
    for (;;) {
        sleep_ms(period);
        TlgGpuFrameCounters now;
        tlggpu_frame_counters(&now);
        const uint64_t ms = runtime_wait_now_ms();
        const uint64_t before = m->last_frames;
        switch (runtime_freeze_step(m, now.shown, ms)) {
        case 1: {
            char head[96];
            snprintf(head, sizeof(head), "FREEZE: no frame for %u s; threads:\n", (unsigned)m->seconds);
            runtime_freeze_report(stdout, head);
            break;
        }
        case 2:
            printf("FREEZE: frames resumed after %.1f s\n", m->freeze_ms / 1000.0);
            fflush(stdout);
            break;
        }
        if (now.shown != before) counters_at_last_frame = now;
    }
    return NULL;
}

static void gpu_wait_begin(const char *kind, const void *object, const char *name, uintptr_t frame) {
    runtime_wait_begin(kind, object, name, NULL, frame);
}
void runtime_freeze_start(uintptr_t image, uint64_t image_size, unsigned seconds) {
    image_base = image; image_bytes = image_size;
    tlggpu_set_wait_hooks(gpu_wait_begin, runtime_wait_end);
#ifndef _WIN32
    struct sigaction action = {0};
    action.sa_sigaction = capture_signal;
    action.sa_flags = SA_SIGINFO | SA_RESTART;
    sigemptyset(&action.sa_mask);
    sigaction(SIGURG, &action, NULL);
#endif
    if (!seconds) return;
    static FreezeMonitor state;
    state = (FreezeMonitor){.seconds = seconds};
    pthread_t thread;
    if (pthread_create(&thread, NULL, monitor, &state)) { puts("Freeze report: monitor thread not started"); return; }
    pthread_detach(thread);
    printf("Freeze report: after %u s without a new frame (TLG_FREEZE_REPORT_SECONDS, 0 = off)\n", seconds);
}

/* ---- CPU time by thread (after FelipePrado0's gow3_pc #813) ----
 * Which threads keep the CPU busy, and how much of that is kernel time (write faults, page
 * protection): every TLG_CPU_REPORT_SECONDS (default 30, 0 = off) the busiest threads of that
 * period, and the whole session from runtime_report at exit. Threads that exited are not listed. */
typedef struct {
    uint64_t tid;
    double user_ms, kernel_ms;
    char name[64];
} ThreadCpu;

static int thread_times(uint64_t tid, double *user_ms, double *kernel_ms) {
#ifdef _WIN32
    HANDLE thread = OpenThread(THREAD_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)tid);
    if (!thread) return 0;
    FILETIME created, exited, kernel, user;
    const BOOL ok = GetThreadTimes(thread, &created, &exited, &kernel, &user);
    CloseHandle(thread);
    if (!ok) return 0;
    *user_ms = (double)(((uint64_t)user.dwHighDateTime << 32) | user.dwLowDateTime) / 1e4;
    *kernel_ms = (double)(((uint64_t)kernel.dwHighDateTime << 32) | kernel.dwLowDateTime) / 1e4;
    return 1;
#else
    char path[64], line[1024];
    snprintf(path, sizeof(path), "/proc/self/task/%llu/stat", (unsigned long long)tid);
    int fd = open(path, O_RDONLY);
    if (fd < 0) return 0;
    ssize_t got = read(fd, line, sizeof(line) - 1);
    close(fd);
    if (got <= 0) return 0;
    line[got] = 0;
    const char *comm_end = strrchr(line, ')');
    unsigned long utime, stime;
    /* After "(comm) ": the state, fields 4-13, then utime and stime (proc(5)). */
    if (!comm_end || sscanf(comm_end + 2, "%*c %*s %*s %*s %*s %*s %*s %*s %*s %*s %*s %lu %lu",
                            &utime, &stime) != 2)
        return 0;
    const double tick_ms = 1000.0 / (double)sysconf(_SC_CLK_TCK);
    *user_ms = (double)utime * tick_ms;
    *kernel_ms = (double)stime * tick_ms;
    return 1;
#endif
}
static unsigned hardware_threads(void) {
#ifdef _WIN32
    DWORD_PTR process = 0, system = 0;
    if (GetProcessAffinityMask(GetCurrentProcess(), &process, &system) && process)
        return (unsigned)__builtin_popcountll((unsigned long long)process);
    return 0;
#else
    cpu_set_t set;
    CPU_ZERO(&set);
    return sched_getaffinity(0, sizeof(set), &set) ? 0 : (unsigned)CPU_COUNT(&set);
#endif
}
/* Every live thread with its CPU time; guest threads by their guest name (Windows has no host
 * name for them, Linux cuts it at 15 characters). Callers hold cpu_lock (static buffers). */
static pthread_mutex_t cpu_lock = PTHREAD_MUTEX_INITIALIZER;
static size_t cpu_snapshot(ThreadCpu *out, size_t max) {
    static Capture threads[MAX_THREADS];
    static RuntimeThreadInfo guests[MAX_THREADS];
    const size_t n = list_threads(threads, MAX_THREADS), g = runtime_thread_snapshot(guests, MAX_THREADS);
    size_t count = 0;
    for (size_t i = 0; i < n && count < max; ++i) {
        ThreadCpu *t = &out[count];
        if (!thread_times(threads[i].tid, &t->user_ms, &t->kernel_ms)) continue;
        t->tid = threads[i].tid;
        const char *name = threads[i].name;
        for (size_t j = 0; j < g; ++j)
            if (guests[j].os_tid == t->tid && !guests[j].finished && guests[j].name[0]) { name = guests[j].name; break; }
        if (name[0]) snprintf(t->name, sizeof(t->name), "%s", name);
        else snprintf(t->name, sizeof(t->name), "tid %llu", (unsigned long long)t->tid);
        ++count;
    }
    return count;
}
static int busier(const void *a, const void *b) {
    const ThreadCpu *x = a, *y = b;
    const double u = x->user_ms + x->kernel_ms, v = y->user_ms + y->kernel_ms;
    return (u < v) - (u > v);
}
/* The threads of `now` minus their time in `before` (absent there: all of it), busiest first. */
static void cpu_print(const char *what, double seconds, const ThreadCpu *now, size_t n,
                      const ThreadCpu *before, size_t m) {
    static ThreadCpu delta[MAX_THREADS];
    double total = 0;
    for (size_t i = 0; i < n; ++i) {
        delta[i] = now[i];
        for (size_t j = 0; j < m; ++j) {
            if (before[j].tid != now[i].tid) continue;
            delta[i].user_ms = now[i].user_ms > before[j].user_ms ? now[i].user_ms - before[j].user_ms : 0;
            delta[i].kernel_ms = now[i].kernel_ms > before[j].kernel_ms ? now[i].kernel_ms - before[j].kernel_ms : 0;
            break;
        }
        total += delta[i].user_ms + delta[i].kernel_ms;
    }
    qsort(delta, n, sizeof(*delta), busier);
    if (seconds <= 0) return;
    const double percent = 100.0 / (seconds * 1000.0); /* ms -> % of one thread */
    printf("CPU by thread, %s (%.0f s): %.0f%% of one thread in total, %u hardware threads, %zu threads\n",
           what, seconds, total * percent, hardware_threads(), n);
    for (size_t i = 0; i < n && i < 12; ++i) {
        const double busy = (delta[i].user_ms + delta[i].kernel_ms) * percent;
        if (busy < 1.0) break;
        printf("  %-32s %5.1f%% of one thread (kernel %.1f%%)\n", delta[i].name, busy, delta[i].kernel_ms * percent);
    }
    fflush(stdout);
}
static uint64_t cpu_start_ms;
static void *cpu_monitor(void *argument) {
    const unsigned seconds = (unsigned)(uintptr_t)argument;
#ifndef _WIN32
    pthread_setname_np(pthread_self(), "tlg:cpu");
#endif
    static ThreadCpu a[MAX_THREADS], b[MAX_THREADS];
    ThreadCpu *before = a, *now = b;
    pthread_mutex_lock(&cpu_lock);
    size_t m = cpu_snapshot(before, MAX_THREADS);
    pthread_mutex_unlock(&cpu_lock);
    uint64_t last_ms = runtime_wait_now_ms();
    for (;;) {
        sleep_ms(seconds * 1000u);
        pthread_mutex_lock(&cpu_lock);
        const size_t n = cpu_snapshot(now, MAX_THREADS);
        const uint64_t ms = runtime_wait_now_ms();
        char what[32];
        snprintf(what, sizeof(what), "last %u s", seconds);
        cpu_print(what, (double)(ms - last_ms) / 1000.0, now, n, before, m);
        pthread_mutex_unlock(&cpu_lock);
        ThreadCpu *swap = before; before = now; now = swap;
        m = n;
        last_ms = ms;
    }
    return NULL;
}
void runtime_cpu_report_start(unsigned seconds) {
    cpu_start_ms = runtime_wait_now_ms();
    if (!seconds) return;
    pthread_t thread;
    if (pthread_create(&thread, NULL, cpu_monitor, (void *)(uintptr_t)seconds)) return;
    pthread_detach(thread);
    printf("CPU report: busiest threads every %u s (TLG_CPU_REPORT_SECONDS, 0 = off)\n", seconds);
}
void runtime_cpu_report_session(void) {
    if (!cpu_start_ms) return;
    static ThreadCpu now[MAX_THREADS];
    pthread_mutex_lock(&cpu_lock);
    const size_t n = cpu_snapshot(now, MAX_THREADS);
    cpu_print("whole session", (double)(runtime_wait_now_ms() - cpu_start_ms) / 1000.0, now, n, NULL, 0);
    pthread_mutex_unlock(&cpu_lock);
}
