//
//  SPSCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

import Atomics

public final class SPSCBoundedQueue<Element>: ConcurrentQueue {
    private let size: Int
    private let mask: Int
    private var buffer: UnsafeMutableBufferPointer<Element?>
    
    private let head = ManagedAtomic<Int>(0)
    private let tail = ManagedAtomic<Int>(0)
    
    public init(size: Int) {
        precondition(size >= 2, "Queue capacity too small")
        self.size = size.nextPowerOf2()
        self.mask = size.nextPowerOf2() - 1
        self.buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2() + 1)
        self.buffer.initialize(repeating: nil)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    @discardableResult
    public final func enqueue(_ value: Element) -> Bool {
        let pos = tail.load(ordering: .relaxed)
        
        if (head.load(ordering: .acquiring) - (pos + 1)) & mask >= 1 {
            buffer[pos & mask] = value
            tail.store(pos + 1, ordering: .releasing)
            return true
        }
        return false
    }
    
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
    
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

