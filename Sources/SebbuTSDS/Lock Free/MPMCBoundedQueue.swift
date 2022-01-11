//
//  MPMCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Atomics)
import Atomics

public final class MPMCBoundedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal struct BufferNode {
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal let sequence: UnsafeAtomic<Int> = .create(0)
    }
    
    @usableFromInline
    internal let size: Int
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<UnsafeMutablePointer<BufferNode>>
    
    @usableFromInline
    internal var head = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal var tail = UnsafeAtomic<Int>.create(0)
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public init(size _size: Int) {
        self.size = _size.nextPowerOf2()
        self.mask = _size.nextPowerOf2() - 1
        self.buffer = UnsafeMutableBufferPointer.allocate(capacity: _size.nextPowerOf2())
        for i in 0..<_size.nextPowerOf2() {
            let ptr = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
            ptr.initialize(to: BufferNode())
            ptr.pointee.sequence.store(i, ordering: .relaxed)
            buffer[i] = ptr
        }
    }
    
    deinit {
        for item in buffer {
            item.pointee.sequence.destroy()
            item.deallocate()
        }
        buffer.deallocate()
        head.destroy()
        tail.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        var node: UnsafeMutablePointer<BufferNode>!
        var pos = tail.load(ordering: .relaxed)
        
        while true {
            node = buffer[pos & mask]
            let seq = node.pointee.sequence.load(ordering: .acquiring)
            let difference = seq - pos
            
            if difference == 0 {
                if tail.weakCompareExchange(expected: pos,
                                            desired: pos + 1,
                                            successOrdering: .relaxed,
                                            failureOrdering: .relaxed).exchanged {
                    break
                }
            } else if difference < 0 {
                return false
            } else {
                pos = tail.load(ordering: .relaxed)
            }
        }
        
        node.pointee.data = value
        node.pointee.sequence.store(pos + 1, ordering: .releasing)
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        var node: UnsafeMutablePointer<BufferNode>!
        var pos = head.load(ordering: .relaxed)
        
        while true {
            node = buffer[pos & mask]
            let seq = node.pointee.sequence.load(ordering: .acquiring)
            let difference = seq - (pos + 1)
            
            if difference == 0 {
                if head.weakCompareExchange(expected: pos, desired: pos + 1, successOrdering: .relaxed, failureOrdering: .relaxed).exchanged {
                    break
                }
            } else if difference < 0 {
                return nil
            } else {
                pos = head.load(ordering: .relaxed)
            }
        }
        defer {
            node.pointee.sequence.store(pos + mask + 1, ordering: .releasing)
        }
        return node.pointee.data
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension MPMCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let queue: MPMCBoundedQueue
        
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}
#endif
