//
//  MPSCQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

import Atomics

public final class MPSCQueue<Element>: ConcurrentQueue {
    struct BufferNode {
        var data: Element?
        let next: UnsafeAtomic<UnsafeMutablePointer<BufferNode>?> = UnsafeAtomic.create(nil)
        
        init(data: Element?) {
            self.data = data
        }
    }
    
    private var head: ManagedAtomic<UnsafeMutablePointer<BufferNode>>
    private var tail: ManagedAtomic<UnsafeMutablePointer<BufferNode>>
    
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
    public final func enqueue(_ value: Element) -> Bool {
        let bufferNode = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
        bufferNode.initialize(to: BufferNode(data: value))
        
        let previous = tail.exchange(bufferNode, ordering: .acquiringAndReleasing)
        previous.pointee.next.store(bufferNode, ordering: .releasing)
        return true
    }
    
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
    
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}
