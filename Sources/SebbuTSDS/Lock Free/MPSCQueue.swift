//
//  MPSCQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Atomics)
import Atomics

public final class MPSCQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal struct BufferNode {
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal let next: UnsafeAtomic<UnsafeMutablePointer<BufferNode>?> = UnsafeAtomic.create(nil)
        
        @usableFromInline
        internal init(data: Element?) {
            self.data = data
        }
    }
    
    @usableFromInline
    internal var head: ManagedAtomic<UnsafeMutablePointer<BufferNode>>
    
    @usableFromInline
    internal var tail: ManagedAtomic<UnsafeMutablePointer<BufferNode>>
    
    @inlinable
    public init() {
        let node = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
        node.initialize(to: BufferNode(data: nil))
        self.head = ManagedAtomic<UnsafeMutablePointer<BufferNode>>(node)
        self.tail = ManagedAtomic<UnsafeMutablePointer<BufferNode>>(node)
    }
    
    deinit {
        while let _ = dequeue() {}
        tail.load(ordering: .relaxed).deallocate()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        //TODO: Can we do something about this allocation?
        let bufferNode = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
        bufferNode.initialize(to: BufferNode(data: value))
        
        let previous = tail.exchange(bufferNode, ordering: .acquiringAndReleasing)
        previous.pointee.next.store(bufferNode, ordering: .releasing)
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        let currentHead = head.load(ordering: .relaxed)
        guard let next = currentHead.pointee.next.load(ordering: .acquiring) else {
            return nil
        }
        let result = next.pointee.data
        head.store(next, ordering: .releasing)
        currentHead.pointee.next.destroy()
        currentHead.deallocate()
        return result
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension MPSCQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let queue: MPSCQueue
        
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}
#endif
