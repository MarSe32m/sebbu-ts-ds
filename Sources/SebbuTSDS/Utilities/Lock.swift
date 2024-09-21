//
//  Lock.swift
//
//
//  Created by Sebastian Toivonen on 7.1.2022.
//

import Synchronization
/// Lock object. This is basically a wrapper around the standard library Mutex
@available(*, deprecated, message: "Use the standard library Mutex type instead.")
public struct Lock: ~Copyable, Sendable {
    @usableFromInline
    internal let _lock: Mutex<Void> = Mutex(())
    
    /// Create a new lock.
    @inlinable
    public init() {}

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    @inlinable
    public func lock() {
        _lock._unsafeLock()
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    @inlinable
    public func unlock() {
        _lock._unsafeUnlock()
    }
    
    /// Try to acquire the lock.
    ///
    /// Whenever possible, consider using `withLock`instead of this method and
    /// `unlock`, to simplify lock handling.
    @inlinable
    public func tryLock() -> Bool {
        _lock._unsafeTryLock()
    }

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
}