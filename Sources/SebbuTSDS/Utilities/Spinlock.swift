//
//  Spinlock.swift
//  
//
//  Created by Sebastian Toivonen on 28.12.2021.
//

// Spinlocking is extremely bad on iOS, tvOS and watchOS, so for them we will use the Mutex primitive
#if !(os(iOS) || os(tvOS) || os(watchOS))
import Synchronization
import CSebbuTSDS

public struct Spinlock: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _lock: Atomic<Bool> = .init(false)
    
    public init() {}
    
    @inline(__always)
    public func lock() {
        while true {
            // Optimistically assume the lock is free on the first try
            if (!_lock.exchange(true, ordering: .acquiring)) { return }
            // Wait for the lock to be released without generating cache misses
            while _lock.load(ordering: .relaxed) {
                //Issue an X86_64 pause or arm yield instruction
                HardwareUtilities.pause()
            }
        }
    }
    
    @inline(__always)
    public func tryLock() -> Bool {
        // First do a relaxed load to check if the lock is free in order to prevent
        // unnecessary cache misses if someone does a while !tryLock() {...}
        !_lock.load(ordering: .relaxed) && !_lock.exchange(true, ordering: .acquiring)
    }
    
    @inline(__always)
    public func unlock() {
        _lock.store(false, ordering: .releasing)
    }
    
    @inline(__always)
    public func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
}
#else
typealias Spinlock = Lock
#endif
