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

// New implementation vendored from SwiftNIO
#if os(Windows)
@usableFromInline
typealias LockPrimitive = SRWLOCK
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
@usableFromInline
typealias LockPrimitive = os_unfair_lock_s
#else
@usableFromInline
typealias LockPrimitive = pthread_mutex_t
#endif

@usableFromInline
enum LockOperations { }

extension LockOperations {
    @inlinable
    static func create(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
#if os(Windows)
        InitializeSRWLock(mutex)
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        mutex.pointee = .init()
#else
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        debugOnly {
            pthread_mutexattr_settype(&attr, .init(PTHREAD_MUTEX_ERRORCHECK))
        }
        
        let err = pthread_mutex_init(mutex, &attr)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
    
    @inlinable
    static func destroy(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
#if os(Windows) || os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        // No need to do anything on these platforms
#else
        let err = pthread_mutex_destroy(mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
    
    @inlinable
    static func lock(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
#if os(Windows)
        AcquireSRWLockExclusive(mutex)
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        os_unfair_lock_lock(mutex)
#else
        let err = pthread_mutex_lock(mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
    
    @inlinable
    static func unlock(_ mutex: UnsafeMutablePointer<LockPrimitive>) {
#if os(Windows)
        ReleaseSRWLockExclusive(mutex)
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        os_unfair_lock_assert_owner(mutex)
        os_unfair_lock_unlock(mutex)
#else
        let err = pthread_mutex_unlock(mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
#endif
    }
    
    @inlinable
    static func tryLock(_ mutex: UnsafeMutablePointer<LockPrimitive>) -> Bool {
#if os(Windows)
        TryAcquireSRWLockExclusive(mutex) != 0
#elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        os_unfair_lock_trylock(mutex)
#else
        let error = pthread_mutex_trylock(mutex)
        precondition(error == 0 || error == EBUSY, "\(#function) failed to try_lock pthread_mutex with error \(error)")
        return error == 0
#endif
    }
}

// Tail allocate both the mutex and a generic value using ManagedBuffer.
// Both the header pointer and the elements pointer are stable for
// the class's entire lifetime.
@usableFromInline
final class LockStorage<Value>: ManagedBuffer<LockPrimitive, Value> {
    
    @inlinable
    static func create(value: Value) -> Self {
        let buffer = Self.create(minimumCapacity: 1) { _ in
            return LockPrimitive()
        }
        let storage = unsafeDowncast(buffer, to: Self.self)
        
        storage.withUnsafeMutablePointers { lockPtr, valuePtr in
            LockOperations.create(lockPtr)
            valuePtr.initialize(to: value)
        }
        
        return storage
    }
    
    @inlinable
    func lock() {
        self.withUnsafeMutablePointerToHeader { lockPtr in
            LockOperations.lock(lockPtr)
        }
    }
    
    @inlinable
    func unlock() {
        self.withUnsafeMutablePointerToHeader { lockPtr in
            LockOperations.unlock(lockPtr)
        }
    }
    
    @inlinable
    func tryLock() -> Bool {
        self.withUnsafeMutablePointerToHeader { lockPtr in
            LockOperations.tryLock(lockPtr)
        }
    }
    
    @inlinable
    deinit {
        self.withUnsafeMutablePointers { lockPtr, valuePtr in
            LockOperations.destroy(lockPtr)
            valuePtr.deinitialize(count: 1)
        }
    }
    
    @inlinable
    func withLockPrimitive<T>(_ body: (UnsafeMutablePointer<LockPrimitive>) throws -> T) rethrows -> T {
        try self.withUnsafeMutablePointerToHeader { lockPtr in
            return try body(lockPtr)
        }
    }
    
    @inlinable
    func withLockedValue<T>(_ mutate: (inout Value) throws -> T) rethrows -> T {
        try self.withUnsafeMutablePointers { lockPtr, valuePtr in
            LockOperations.lock(lockPtr)
            defer { LockOperations.unlock(lockPtr) }
            return try mutate(&valuePtr.pointee)
        }
    }
}

extension LockStorage: @unchecked Sendable { }

public struct Lock {
    @usableFromInline
    internal let _storage: LockStorage<Void>
    
    /// Create a new lock.
    @inlinable
    public init() {
        self._storage = .create(value: ())
    }

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    @inlinable
    public func lock() {
        self._storage.lock()
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    @inlinable
    public func unlock() {
        self._storage.unlock()
    }
    
    /// Try to acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    @inlinable
    public func tryLock() -> Bool {
        self._storage.tryLock()
    }

    @inlinable
    internal func withLockPrimitive<T>(_ body: (UnsafeMutablePointer<LockPrimitive>) throws -> T) rethrows -> T {
        return try self._storage.withLockPrimitive(body)
    }
}

extension Lock {
    /// Acquire the lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try body()
    }

    @inlinable
    public func withLockVoid(_ body: () throws -> Void) rethrows -> Void {
        try self.withLock(body)
    }
}

extension Lock: Sendable {}

// Old implementation
#if false
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
#endif
