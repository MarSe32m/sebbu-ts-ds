//
//  ConcurrentDeque.swift
//  
//
//  Created by Sebastian Toivonen on 29.12.2021.
//


public protocol ConcurrentDeque {
    associatedtype Element
    func popFirst() -> Element?
    func popLast() -> Element?
    func removeFirst() -> Element
    func removeFirst(_ n: Int)
    func removeLast() -> Element
    func removeAll(keepingCapacity: Bool)
    func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows
    func append(_ newElement: Element)
    func append<T: Sequence>(contentsOf elements: T) where T.Element == Element
    func append<T: Collection>(contentsOf elements: T) where T.Element == Element
    func prepend(_ newElement: Element)
    func prepend<T: Sequence>(contentsOf elements: T) where T.Element == Element
    func prepend<T: Collection>(contentsOf elements: T) where T.Element == Element
    func contains(where predicate: (Element) throws -> Bool) rethrows -> Bool
}
