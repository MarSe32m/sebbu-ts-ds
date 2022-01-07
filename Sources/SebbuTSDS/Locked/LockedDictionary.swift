//
//  LockedDictionary.swift
//  
//
//  Created by Sebastian Toivonen on 24.12.2021.
//

public final class LockedDictionary<Key: Hashable, Value>: @unchecked Sendable {
    @usableFromInline
    internal var _buffer: [Key: Value] = [:]
    
    @usableFromInline
    internal let _lock = Lock()
    
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
    
    @inlinable
    public final func set(value: Value, forKey key: Key) {
        _lock.withLock {
            _buffer[key] = value
        }
    }
    
    @inlinable
    public final func removeValue(forKey key: Key) -> Value? {
        _lock.withLock {
            _buffer.removeValue(forKey: key)
        }
    }
    
    @inlinable
    public final func contains(_ key: Key) -> Bool {
        _lock.withLock {
            _buffer.index(forKey: key) != nil
        }
    }
    
    @discardableResult
    @inlinable
    public final func setIfNotExist(_ key: Key, value: Value) -> Bool {
        _lock.withLock {
            if _buffer[key] != nil { return false }
            _buffer[key] = value
            return true
        }
    }
    
    @inlinable
    public final func value(forKey key: Key) -> Value? {
        _lock.withLock {
            _buffer[key]
        }
    }
    
    @inlinable
    public final func mutateValue(forKey key: Key, transformation: (Value?) -> Value?) {
        _lock.withLock {
            let currentValue = _buffer[key]
            _buffer[key] = transformation(currentValue)
        }
    }
    
    @inlinable
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
