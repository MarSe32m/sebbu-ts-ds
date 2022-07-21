//
//  ConcurrentStack.swift
//  
//
//  Created by Sebastian Toivonen on 26.4.2022.
//

/// LIFO stack
public protocol ConcurrentStack {
    associatedtype Element
    
    /// Pushes an item on top of the stack
    /// - returns Boolean value based on if the item was pushed successfully
    @inlinable
    func push(_ value: Element) -> Bool
    
    /// Pops an item from the top of the stack
    @inlinable
    func pop() -> Element?
    
    /// Pop all of the items from the stack
    @inline(__always)
    func popAll(_ closure: (Element) -> Void)
}

public extension ConcurrentStack {
    @inlinable
    func blockingPush(_ value: Element) {
        while !push(value) {}
    }
    
    @inlinable
    func blockingPop() -> Element {
        while true {
            if let value = pop() {
                return value
            }
        }
    }
}

