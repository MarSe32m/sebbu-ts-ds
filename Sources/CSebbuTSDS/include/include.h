//
//  include.h
//  
//
//  Created by Sebastian Toivonen on 3.1.2022.
//

#if defined(__x86_64__) || defined(__i386__) || defined(_M_X64)
#define hardware_pause() __asm__("pause")
#elif (defined(__arm__) && defined(_ARM_ARCH_7) && defined(__thumb__)) || defined(__arm64__)
#define hardware_pause() __asm__("yield")
#else
#define hardware_pause() __asm__("")
#endif

static inline __attribute((always_inline)) void _hardware_pause() {
    hardware_pause();
}
