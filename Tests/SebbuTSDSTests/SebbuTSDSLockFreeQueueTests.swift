import XCTest
import SebbuTSDS
#if canImport(Atomics)
import Atomics
#endif
final class SebbuTSDSLockFreeQueueTests: XCTestCase {
    func testSPSCBoundedQueue() {
#if canImport(Atomics)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1_000_000), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1_000_000), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1_000_000), writers: 1, readers: 1, elements: 10_000_000)
        
        testQueueSequenceConformance(SPSCBoundedQueue<Int>(size: 1_000))
#endif
    }
    
    func testSPSCQueue() {
#if canImport(Atomics)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(), writers: 1, readers: 1, elements: 10_000)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 2000), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 2000), writers: 1, readers: 1, elements: 10_000)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 2000), writers: 1, readers: 1, elements: 10_000_000)
    
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: 1, readers: 1, elements: 10_000)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: 1, readers: 1, elements: 10_000_000)
        
        testQueueSequenceConformance(SPSCQueue<Int>())
#endif
    }
    
    func testMPMCBoundedQueue() {
#if canImport(Atomics)
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i - 1, readers: 1, elements: 1_000_00)
            
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i - 1, readers: 1, elements: 1_000_00)
            
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        testQueueSequenceConformance(MPMCBoundedQueue<Int>(size: 1000))
#endif
    }
    
    func testSPMCBoundedQueue() {
#if canImport(Atomics)
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: SPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: i - 1, elements: 128)
            test(queue: SPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: i - 1, elements: 10_000)
            test(queue: SPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: i - 1, elements: 10_000_00)
        }
        
        testQueueSequenceConformance(SPMCBoundedQueue<Int>(size: 1000))
#endif
    }
    
    func testMPSCQueue() {
#if canImport(Atomics)
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: MPSCQueue<(item: Int, thread: Int)>(), writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: MPSCQueue<(item: Int, thread: Int)>(cacheSize: 10000), writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: MPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        testQueueSequenceConformance(MPSCQueue<Int>())
#endif
    }
    
    func testMPSCBoundedQueue() {
#if canImport(Atomics)
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: MPSCBoundedQueue<(item: Int, thread: Int)>(size: 10000), writers: i - 1, readers: 1, elements: 1_000_00)
        }
        testQueueSequenceConformance(MPSCBoundedQueue<Int>(size: 10000))
#endif
    }
    
    func testQueueDraining() {
#if canImport(Atomics)
        testDraining(SPSCBoundedQueue<Int>(size: 128))
        testDraining(SPSCBoundedQueue<Int>(size: 1024))
        testDraining(SPSCBoundedQueue<Int>(size: 65536))
        
        testDraining(SPSCQueue<Int>())
        
        testDraining(MPMCBoundedQueue<Int>(size: 128))
        testDraining(MPMCBoundedQueue<Int>(size: 1024))
        testDraining(MPMCBoundedQueue<Int>(size: 65536))
        
        testDraining(SPMCBoundedQueue<Int>(size: 128))
        testDraining(SPMCBoundedQueue<Int>(size: 1024))
        testDraining(SPMCBoundedQueue<Int>(size: 65536))
        
        testDraining(MPSCBoundedQueue<Int>(size: 128))
        testDraining(MPSCBoundedQueue<Int>(size: 1024))
        testDraining(MPSCBoundedQueue<Int>(size: 65536))
        
        testDraining(MPSCQueue<Int>())
#endif
    }
}

