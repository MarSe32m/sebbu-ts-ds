//
//  Lock.swift
//  
//
//  Created by Sebastian Toivonen on 7.1.2022.
//

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Windows)
import ucrt
import WinSDK
#else
import Glibc
#endif

public final class Lock: @unchecked Sendable {
#if os(Windows)
    @usableFromInline
    internal let mutex: UnsafeMutablePointer<SRWLOCK> = UnsafeMutablePointer.allocate(capacity: 1)
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    @usableFromInline
    internal let mutex: os_unfair_lock_t = os_unfair_lock_t.allocate(capacity: 1)
#else
    @usableFromInline
    internal let mutex: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: 1)
#endif
    
    public init() {
#if os(Windows)
        InitializeSRWLock(self.mutex)
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        self.mutex.pointee = .init()
#else
        initialize_pthread_mutex(self.mutex)
#endif
    }
    
    deinit {
#if os(Windows) || os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        // No need to do anything on these platforms
#else
        let error = pthread_mutex_destroy(self.mutex)
        precondition(error == 0, "\(#function) failed to destroy pthread_mutex with error \(error)")
#endif
        self.mutex.deallocate()
    }
    
    @inlinable
    public final func lock() {
#if os(Windows)
        AcquireSRWLockExclusive(self.mutex)
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        os_unfair_lock_lock(self.mutex)
#else
        let error = pthread_mutex_lock(self.mutex)
        precondition(error == 0, "\(#function) failed to lock pthread_mutex with error \(error)")
#endif
    }
    
    @inlinable
    public final func unlock() {
#if os(Windows)
        ReleaseSRWLockExclusive(self.mutex)
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        os_unfair_lock_assert_owner(self.mutex)
        os_unfair_lock_unlock(self.mutex)
#else
        let error = pthread_mutex_unlock(self.mutex)
        precondition(error == 0, "\(#function) failed to unlock pthread_mutex with error \(error)")
#endif
    }
    
    @inlinable
    public final func tryLock() -> Bool {
#if os(Windows)
        TryAcquireSRWLockExclusive(self.mutex) != 0
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        os_unfair_lock_trylock(self.mutex)
#else
        let error = pthread_mutex_trylock(self.mutex)
        precondition(error == 0 || error == EBUSY, "\(#function) failed to try_lock pthread_mutex with error \(error)")
        return error == 0
#endif
    }
}

extension Lock {
    @inlinable
    public final func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        let result = try block()
        unlock()
        return result
    }
    
    @inlinable
    public final func withLockVoid(_ body: () throws -> Void) rethrows -> Void {
        try withLock(body)
    }
}

#if !os(Windows)
fileprivate func initialize_pthread_mutex(_ pointer: UnsafeMutablePointer<pthread_mutex_t>) {
    var attributes = pthread_mutexattr_t()
    pthread_mutexattr_init(&attributes)
    debugOnly {
        pthread_mutexattr_settype(&attributes, .init(PTHREAD_MUTEX_ERRORCHECK))
    }
    let error = pthread_mutex_init(pointer, &attributes)
    precondition(error == 0, "\(#function) failed to initialize pthread_mutex with error \(error)")
}
#endif
