//
//  Utilities.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

import Foundation

extension FixedWidthInteger {
    /// Returns the next power of two.
    @inlinable
    func nextPowerOf2() -> Self {
        guard self != 0 else {
            return 1
        }
        return 1 << (Self.bitWidth - (self - 1).leadingZeroBitCount)
    }
}

public extension NSLock {
    @inline(__always)
    final func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
}
