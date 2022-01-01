//
//  SPSCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Atomics)
import Atomics

public final class SPSCBoundedQueue<Element>: ConcurrentQueue {
    
    @usableFromInline
    internal let size: Int
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element?>
    
    @usableFromInline
    internal let head = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal let tail = UnsafeAtomic<Int>.create(0)
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public init(size: Int) {
        precondition(size >= 2, "Queue capacity too small")
        self.size = size.nextPowerOf2()
        self.mask = size.nextPowerOf2() - 1
        self.buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2() + 1)
        self.buffer.initialize(repeating: nil)
    }
    
    deinit {
        buffer.deallocate()
        head.destroy()
        tail.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        let pos = tail.load(ordering: .relaxed)
        
        if (head.load(ordering: .acquiring) - (pos + 1)) & mask >= 1 {
            buffer[pos & mask] = value
            tail.store(pos + 1, ordering: .releasing)
            return true
        }
        return false
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        let pos = head.load(ordering: .relaxed)
        
        if (tail.load(ordering: .acquiring) - pos) & mask >= 1 {
            defer {
                head.store(pos + 1, ordering: .releasing)
            }
            return buffer[pos & mask]
        }
        return nil
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}
#endif
