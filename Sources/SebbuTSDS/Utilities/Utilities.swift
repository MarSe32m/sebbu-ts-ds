//
//  Utilities.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

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
