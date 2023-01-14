//
//  Spinlock.swift
//  
//
//  Created by Sebastian Toivonen on 28.12.2021.
//

// Spinlocking is extremely bad on iOS, tvOS and watchOS, so for them we will use the os_unfair_lock
#if canImport(Atomics) && !(os(iOS) || os(tvOS) || os(watchOS))
import Atomics
import CSebbuTSDS

public final class Spinlock: @unchecked Sendable {
    @usableFromInline
    internal let _lock = UnsafeAtomic<Bool>.create(false)
    
    public init() {}
    
    @inline(__always)
    public final func lock() {
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
    public final func tryLock() -> Bool {
        // First do a relaxed load to check if the lock is free in order to prevent
        // unnecessary cache misses if someone does a while !tryLock() {...}
        !_lock.load(ordering: .relaxed) && !_lock.exchange(true, ordering: .acquiring)
    }
    
    @inline(__always)
    public final func unlock() {
        _lock.store(false, ordering: .releasing)
    }
    
    @inline(__always)
    public final func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
    
    @inline(__always)
    public final func withLockVoid(_ body: () throws -> Void) rethrows -> Void {
        try withLock(body)
    }
    
    deinit {
        _lock.destroy()
    }
}
#else
public typealias Spinlock = Lock
#endif
