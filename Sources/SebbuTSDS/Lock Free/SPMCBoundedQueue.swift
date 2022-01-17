//
//  SPMCBoundedQueue.swift
//
//
//  Created by Sebastian Toivonen on 13.1.2022.
//

#if canImport(Atomics)
import Atomics

public final class SPMCBoundedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal struct BufferNode {
        @usableFromInline
        internal var data: UnsafeMutablePointer<Element?>
        
        @usableFromInline
        internal let sequence: UnsafeAtomic<Int> = .create(0)
        
        init(data: Element?) {
            self.data = .allocate(capacity: 1)
            self.data.initialize(to: data)
        }
    }
    
    @usableFromInline
    internal let size: Int
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal var _buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal let head = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal var tail = 0
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail
        return tailIndex < headIndex ? (size - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.size = size
        self.mask = size - 1
        self._buffer = .allocate(capacity: size)
        for i in 0..<size {
            _buffer.baseAddress?.advanced(by: i).initialize(to: BufferNode(data: nil))
            _buffer[i].sequence.store(i, ordering: .releasing)
        }
    }
    
    deinit {
        for item in _buffer {
            item.sequence.destroy()
            item.data.deinitialize(count: 1)
            item.data.deallocate()
        }
        _buffer.deallocate()
        head.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        let pos = tail
        let node: UnsafeMutablePointer<BufferNode> = _buffer.baseAddress!.advanced(by: pos & mask)
        let seq = node.pointee.sequence.load(ordering: .acquiring)
        let difference = seq - pos
        
        if difference == 0 {
            tail += 1
        } else if difference < 0 {
            return false
        }
        
        node.pointee.data.pointee = value
        node.pointee.sequence.store(pos + 1, ordering: .releasing)
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        var node: UnsafeMutablePointer<BufferNode>!
        var pos = head.load(ordering: .relaxed)
        
        while true {
            node = _buffer.baseAddress!.advanced(by: pos & mask)
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
        return node.pointee.data.pointee
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension SPMCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: SPMCBoundedQueue
        
        @inlinable
        internal init(queue: SPMCBoundedQueue) {
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
