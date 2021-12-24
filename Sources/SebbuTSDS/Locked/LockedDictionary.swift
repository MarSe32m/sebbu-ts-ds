//
//  LockedDictionary.swift
//  
//
//  Created by Sebastian Toivonen on 24.12.2021.
//

import Foundation

public final class LockedDictionary<Key: Hashable, Value> {
    private var _buffer: [Key: Value] = [:]
    private let _lock = NSLock()
    
    public var keys: [Key] {
        _lock.withLock {
            Array(_buffer.keys)
        }
    }
    
    public var values: [Value] {
        _lock.withLock {
            Array(_buffer.values)
        }
    }
    
    public var isEmpty: Bool {
        _lock.withLock {
            _buffer.isEmpty
        }
    }
    
    public init() {}
    
    public final func set(value: Value, forKey key: Key) {
        _lock.withLock {
            _buffer[key] = value
        }
    }
    
    public final func removeValue(forKey key: Key) -> Value? {
        _lock.withLock {
            _buffer.removeValue(forKey: key)
        }
    }
    
    public final func contains(_ key: Key) -> Bool {
        _lock.withLock {
            _buffer.index(forKey: key) != nil
        }
    }
    
    @discardableResult
    public final func setIfNotExist(_ key: Key, value: Value) -> Bool {
        _lock.withLock {
            if _buffer[key] != nil { return false }
            _buffer[key] = value
            return true
        }
    }
    
    public final func value(forKey key: Key) -> Value? {
        _lock.withLock {
            _buffer[key]
        }
    }
    
    public final func mutateValue(forKey key: Key, transformation: (Value?) -> Value?) {
        _lock.withLock {
            let currentValue = _buffer[key]
            _buffer[key] = transformation(currentValue)
        }
    }
    
    public subscript(key: Key) -> Value? {
        get {
            value(forKey: key)
        }
        set {
            _lock.withLock {
                if let newValue = newValue {
                    _buffer[key] = newValue
                } else {
                    _buffer.removeValue(forKey: key)
                }
            }
        }
    }
}
