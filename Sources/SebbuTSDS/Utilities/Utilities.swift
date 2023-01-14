//
//  Utilities.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

//TODO: Add the Foundation specific utilities to a different package so that the SebbuTSDS has no Foundation dependency
import Foundation
import CSebbuTSDS

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

@inlinable
internal func debugOnly(_ body: () -> Void) {
    assert({ body(); return true}())
}

public extension NSLock {
    @inline(__always)
    final func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
}

extension NSLock: @unchecked Sendable {}

public enum HardwareUtilities {
    /// Issues a hardware pause
    /// On x86/x64 this is the PAUSE instruction, on ARM this is yield, othewise its a no-op
    @inline(__always)
    @_transparent
    public static func pause() {
        _hardware_pause()
    }
}
