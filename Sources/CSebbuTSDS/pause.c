//
//  pause.c
//  
//
//  Created by Sebastian Toivonen on 3.1.2022.
//

#include "include/include.h"

#if defined(__x86_64__) || defined(__i386__) || defined(_M_X64)
#define hardware_pause() __asm__("pause")
#elif (defined(__arm__) && defined(_ARM_ARCH_7) && defined(__thumb__)) || defined(__arm64__)
#define hardware_pause() __asm__("yield")
#else
#define hardware_pause() __asm__("")
#endif

void _pause() {
    hardware_pause();
}

__attribute__((constructor)) void setupSharedThreadPool() {
    setup_shared_threadpool();
}
