//
//  MPSCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 11.1.2022.
//

#if canImport(Atomics)
import Atomics

public final class MPSCBoundedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
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
    internal let _buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal var head: Int = 0
    
    @usableFromInline
    internal let tail = UnsafeAtomic<Int>.create(0)
    
    public var count: Int {
        let headIndex = head
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (_buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.size = size
        self.mask = size - 1
        self._buffer = .allocate(capacity: size)
        for i in 0..<size {
            _buffer.baseAddress?.advanced(by: i).initialize(to: BufferNode(data: nil))
            _buffer[i].sequence.store(i, ordering: .relaxed)
        }
    }
    
    deinit {
        for item in _buffer {
            item.sequence.destroy()
        }
        _buffer.deallocate()
        tail.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        var node: UnsafeMutablePointer<BufferNode>!
        var pos = tail.load(ordering: .relaxed)
        
        while true {
            node = _buffer.baseAddress?.advanced(by: pos & mask)
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
        let pos = head
        let node: UnsafeMutablePointer<BufferNode> = _buffer.baseAddress!.advanced(by: pos & mask)
        let seq = node.pointee.sequence.load(ordering: .acquiring)
        let difference = seq - (pos + 1)
        if difference == 0 {
            head += 1
        } else if difference < 0 {
            return nil
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

extension MPSCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: MPSCBoundedQueue
        
        @inlinable
        internal init(queue: MPSCBoundedQueue) {
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

