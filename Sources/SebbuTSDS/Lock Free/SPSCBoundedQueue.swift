//
//  SPSCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Atomics)
import Atomics

public final class SPSCBoundedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    /// The size of the queue
    public let size: Int
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element?>
    
    @usableFromInline
    internal let head = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal var headCached: Int = 0
    
    @usableFromInline
    internal let tail = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal var tailCached: Int = 0
    
    /// The amount of elements that the queue contains
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
        while dequeue() != nil {}
        buffer.baseAddress?.deinitialize(count: size)
        buffer.deallocate()
        head.destroy()
        tail.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        let pos = tail.load(ordering: .relaxed)
        let nextPos = pos + 1
        if (headCached - nextPos) & mask < 1 {
            headCached = head.load(ordering: .acquiring)
            if (headCached - nextPos) & mask < 1 {
                return false
            }
        }
        buffer[pos & mask] = value
        tail.store(pos + 1, ordering: .releasing)
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        let pos = head.load(ordering: .relaxed)
        if (tailCached - pos) & mask < 1 {
            tailCached = tail.load(ordering: .acquiring)
            if (tailCached - pos) & mask < 1 {
                return nil
            }
        }
        let value = buffer[pos & mask]
        head.store(pos + 1, ordering: .releasing)
        return value
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension SPSCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: SPSCBoundedQueue
        
        @inlinable
        internal init(queue: SPSCBoundedQueue) {
            self.queue = queue
        }
        
        @inlinable
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}
#endif
