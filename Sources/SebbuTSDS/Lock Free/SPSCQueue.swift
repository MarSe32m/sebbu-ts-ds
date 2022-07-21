//
//  SPSCQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Atomics)
import Atomics

public final class SPSCQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal struct Node {
        @usableFromInline
        internal var next: UnsafeMutablePointer<Node>?
        
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        init(data: Element?) {
            self.data = data
        }
    }
    
    @usableFromInline
    internal var head: UnsafeMutablePointer<Node>
    
    @usableFromInline
    internal var tail: UnsafeMutablePointer<Node>
    
    @usableFromInline
    internal let cache: SPSCBoundedQueue<UnsafeMutablePointer<Node>>
    
    public init(cacheSize: Int = 128) {
        let node = UnsafeMutablePointer<Node>.allocate(capacity: 1)
        node.initialize(to: Node(data: nil))
        head = node
        tail = node
        cache = SPSCBoundedQueue(size: cacheSize)
    }

    deinit {
        while dequeue() != nil {}
        while let nodePtr = cache.dequeue() {
            nodePtr.deinitialize(count: 1)
            nodePtr.deallocate()
        }
        tail.deinitialize(count: 1)
        tail.deallocate()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        let node = allocateNode()
        node.pointee.data = value
        atomicMemoryFence(ordering: .acquiringAndReleasing)
        tail.pointee.next = node
        tail = node
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        atomicMemoryFence(ordering: .acquiring)
        // Thread sanitizer will throw a data race here...
        if head.pointee.next == nil {
            return nil
        }
        let result = head.pointee.next?.pointee.data
        head.pointee.next?.pointee.data = nil
        atomicMemoryFence(ordering: .acquiringAndReleasing)
        let front = head
        head = front.pointee.next!
        if (!cache.enqueue(front)) {
            front.deinitialize(count: 1)
            front.deallocate()
        }
        return result
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
    
    @inlinable
    internal final func allocateNode() -> UnsafeMutablePointer<Node> {
        if let node = cache.dequeue() {
            node.pointee.next = nil
            return node
        }
        let node: UnsafeMutablePointer<Node> = .allocate(capacity: 1)
        node.initialize(to: Node(data: nil))
        return node
    }
}

extension SPSCQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: SPSCQueue
        
        @inlinable
        internal init(queue: SPSCQueue) {
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
