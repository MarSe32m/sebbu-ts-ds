//
//  Utilities.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

//TODO: Add the Foundation specific utilities to a different package so that the SebbuTSDS has no Foundation dependency
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#else
#error("Unsupported platform")
#endif

extension FixedWidthInteger {
    /// Returns the next power of two.
    @inlinable
    @_transparent
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

public enum HardwareUtilities {
    /// Issues a hardware pause
    /// On x86/x64 this is the PAUSE instruction, on ARM this is wfe, othewise its a no-op
    @inline(__always)
    @_transparent
    public static func pause() {
        _hardwarePause()
    }
    
    @inlinable
    public static func cacheLineSize() -> Int {
        var lineSize = 0
        #if canImport(Darwin)
        var sizeOfLineSize = MemoryLayout.size(ofValue: lineSize)
        sysctlbyname("hw.cachelinesize", &lineSize, &sizeOfLineSize, nil, 0)
        #elseif canImport(Glibc)
        lineSize = sysconf(Int32(_SC_LEVEL1_DCACHE_LINESIZE))
        #elseif canImport(Musl)
        #warning("FIXME: Assuming common cacheline size of 64 on Musl")
        #elseif canImport(WinSDK)
        var bufferSize: DWORD = 0
        GetLogicalProcessorInformation(nil, &bufferSize)
        let buffer = malloc(Int(bufferSize)).bindMemory(to: SYSTEM_LOGICAL_PROCESSOR_INFORMATION.self, capacity: Int(bufferSize) / MemoryLayout<SYSTEM_LOGICAL_PROCESSOR_INFORMATION>.size)
        GetLogicalProcessorInformation(buffer, &bufferSize)
        
        var index = 0
        while index != Int(bufferSize) / MemoryLayout<SYSTEM_LOGICAL_PROCESSOR_INFORMATION>.size {
            defer { index += 1 }
            if buffer[index].Relationship == RelationCache && buffer[index].Cache.Level == 1 {
                lineSize = Int(buffer[index].Cache.LineSize)
                break
            }
        }
        free(buffer)
        #endif
        // 64 is a common cache line size
        if lineSize <= 0 { return 64 }
        return lineSize
    }
}

//extension UnsafeAtomic {
//    @inlinable
//    public static func createCacheAligned(_ initialValue: Value) -> Self {
//        let byteCount = MemoryLayout<Value.AtomicRepresentation>.size
//        let alignment = HardwareUtilities.cacheLineSize()
//        let rawPtr = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
//        let ptr = rawPtr.assumingMemoryBound(to: Value.AtomicRepresentation.self)
//        ptr.initialize(to: Value.AtomicRepresentation(initialValue))
//        return Self(at: ptr)
//    }
//}
