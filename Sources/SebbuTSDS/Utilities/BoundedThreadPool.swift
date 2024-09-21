//
//  BoundedThreadPool.swift
//  
//
//  Created by Sebastian Toivonen on 30.12.2022.
//

import Dispatch
import Foundation
import HeapModule

#if canImport(Atomics)
import Atomics

public final class BoundedThreadPool {
    @usableFromInline
    internal let workQueue: MPMCBoundedQueue<Work>
    
    @usableFromInline
    internal let timedWorkQueue: MPSCBoundedQueue<TimedWork>
    
    @usableFromInline
    internal var timedWork: Heap<TimedWork> = Heap()
    
    @usableFromInline
    internal let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    
    @usableFromInline
    internal let running: UnsafeAtomic<Bool> = .create(false)
    
    @usableFromInline
    internal let nextTimedWorkDeadline: UnsafeAtomic<UInt64> = .create(0)
    
    @usableFromInline
    internal let handlingTimedWork: UnsafeAtomic<Bool> = .create(false)
    
    public let numberOfThreads: Int
    public let size: Int
    
    public init(size: Int, numberOfThreads: Int) {
        assert(size > 0, "Thread pool must have a size of > 0")
        self.size = size
        self.numberOfThreads = numberOfThreads
        self.workQueue = MPMCBoundedQueue(size: size)
        self.timedWorkQueue = MPSCBoundedQueue(size: size)
    }
    
    public func start() {
        if running.exchange(true, ordering: .relaxed) { return }
        for index in 0..<numberOfThreads {
            let thread = Thread {
                Worker(threadPool: self).run()
            }
            thread.name = "SebbuTSDS-Worker-Thread-\(index)"
            thread.start()
        }
    }
    
    deinit {
        running.destroy()
        nextTimedWorkDeadline.destroy()
        handlingTimedWork.destroy()
    }
    
    public final func run(_ work: @escaping () -> Void) -> Bool {
        let work = Work(work: work)
        let enqueued: Bool = workQueue.enqueue(work)
        semaphore.signal()
        return enqueued
    }
    
    @inlinable
    public final func run(after nanoseconds: UInt64, _ block: @escaping () -> ()) {
        let deadline = DispatchTime.now().uptimeNanoseconds + nanoseconds
        timedWorkQueue.enqueue(TimedWork(block, deadline))
        semaphore.signal()
    }

    @inlinable
    internal func handleTimedWork() {
        if handlingTimedWork.exchange(true, ordering: .acquiring) { return }
        defer { handlingTimedWork.store(false, ordering: .releasing) }
        
        // Move the enqueued work into the priority queue
        for work in timedWorkQueue {
            timedWork.insert(TimedWork(work.work, work.deadline))
        }
        
        // Process the priority queue
        let currentTime = DispatchTime.now().uptimeNanoseconds
        while let workItem = timedWork.max {
            if workItem.deadline > currentTime {
                nextTimedWorkDeadline.store(workItem.deadline, ordering: .relaxed)
                return
            }
            
            let workItem = timedWork.removeMax()
            // Enqueue the work to a worker thread
            if !run(workItem.work) {
                workItem.work()
            }
        }
    }
    
    public final func stop() {
        running.store(false, ordering: .releasing)
        for _ in 0..<numberOfThreads {
            semaphore.signal()
        }
    }
}

extension BoundedThreadPool {
    @usableFromInline
    internal struct Work {
        @usableFromInline
        let work: () -> ()
        
        @inlinable
        init(work: @escaping () -> ()) {
            self.work = work
        }
    }

    @usableFromInline
    internal struct TimedWork: Comparable {
        @usableFromInline
        let work: () -> ()
        
        @usableFromInline
        let deadline: UInt64
        
        @inlinable
        init(_ work: @escaping () -> (), _ deadline: UInt64) {
            self.work = work
            self.deadline = deadline
        }
        
        @usableFromInline
        static func < (lhs: TimedWork, rhs: TimedWork) -> Bool {
            lhs.deadline > rhs.deadline
        }

        @usableFromInline
        static func == (lhs: TimedWork, rhs: TimedWork) -> Bool {
            lhs.deadline == rhs.deadline
        }
    }
}

extension BoundedThreadPool {
    @usableFromInline
    internal final class Worker {
        @usableFromInline
        let running: UnsafeAtomic<Bool> = .create(false)
        
        let threadPool: BoundedThreadPool
        
        init(threadPool: BoundedThreadPool) {
            self.threadPool = threadPool
        }
        
        public func run() {
            running.store(true, ordering: .relaxed)
            while threadPool.running.load(ordering: .relaxed) {
                threadPool.handleTimedWork()
                while let work = threadPool.workQueue.dequeue() {
                    work.work()
                    threadPool.handleTimedWork()
                }
                
                let deadline = threadPool.nextTimedWorkDeadline.exchange(0, ordering: .relaxed)
                if _slowPath(deadline > 0) {
                    _ = threadPool.semaphore.wait(timeout: .init(uptimeNanoseconds: deadline))
                } else {
                    threadPool.semaphore.wait()
                }
            }
        }
        
        public func stop() {
            running.store(false, ordering: .relaxed)
            threadPool.semaphore.signal()
        }
        
        deinit {
            stop()
            running.destroy()
        }
    }
}
#else
public final class BoundedThreadPool {
    
    @usableFromInline
    internal let globalQueue: LockedBoundedQueue<Work>
    
    @usableFromInline
    internal let timedWorkQueue: MPSCQueue<TimedWork>
    
    public let numberOfThreads: Int
    
    @usableFromInline
    internal var workers: [Worker] = []
    
    @usableFromInline
    internal var timedWork: Heap<TimedWork> = Heap()
    
    @usableFromInline
    internal let timedWorkLock: Lock = Lock()
    
    @usableFromInline
    internal let semaphore = DispatchSemaphore(value: 0)
    
    @usableFromInline
    internal var started: Bool = false
    
    @usableFromInline
    internal let startedLock: Lock = Lock()
    
    public init(size: Int = 1024, numberOfThreads: Int) {
        assert(numberOfThreads > 0)
        self.timedWorkQueue = MPSCQueue(cacheSize: size)
        self.globalQueue = LockedBoundedQueue(size: size)
        self.numberOfThreads = numberOfThreads
    }
    
    public func start() {
        let started = startedLock.withLock { self.started }
        if started { return }
        for index in 0..<numberOfThreads {
            let worker = Worker(threadPool: self)
            let thread = Thread {
                worker.run()
            }
            thread.name = "SebbuTSDS-Worker-Thread-\(index)"
            thread.start()
            workers.append(worker)
        }
    }
    
    @inlinable
    public func run(operation: @escaping () -> ()) -> Bool {
        assert({startedLock.withLock { self.started }}(), "The ThreadPool wasn't started before block were submitted")
        assert(!workers.isEmpty)
        let work = Work(operation)
        if globalQueue.enqueue(work) {
            semaphore.signal()
            return true
        }
        return false
    }
    
    @inlinable
    public final func run(after nanoseconds: UInt64, _ block: @escaping () -> ()) {
        let deadline = DispatchTime.now().uptimeNanoseconds + nanoseconds
        timedWorkQueue.enqueue(TimedWork(block, deadline))
        semaphore.signal()
    }

    @inlinable
    @discardableResult
    internal func handleTimedWork() -> UInt64 {
        if !timedWorkLock.tryLock() { return 0 }
        defer { timedWorkLock.unlock() }
        
        // Move the enqueued work into the priority queue
        for work in timedWorkQueue {
            timedWork.insert(work)
        }
        
        // Process the priority queue
        var currentTime = DispatchTime.now().uptimeNanoseconds
        while let workItem = timedWork.max() {
            if workItem.deadline > currentTime {
                return workItem.deadline
            }
            let workItem = timedWork.removeMax()
            // Enqueue the work to a worker thread
            if !run(operation: workItem.work) {
                workItem.work()
                currentTime = DispatchTime.now().uptimeNanoseconds
            }
        }
        return 0
    }
    
    public func stop() {
        workers.forEach { $0.stop() }
        workers.removeAll()
        startedLock.withLock { self.started = false }
    }
}

extension BoundedThreadPool {
    @usableFromInline
    final class Worker {
        @usableFromInline
        var running: Bool = false
        
        @usableFromInline
        let runningLock: Lock = Lock()
        
        @usableFromInline
        let threadPool: BoundedThreadPool
        
        init(threadPool: BoundedThreadPool) {
            self.threadPool = threadPool
        }
        
        @inlinable
        public func run() {
            runningLock.withLock { running = true }
            while true {
                if !runningLock.withLock({
                    running
                }) { return }
                threadPool.handleTimedWork()
                while let work = threadPool.globalQueue.dequeue() {
                    work.work()
                    threadPool.handleTimedWork()
                }
                
                let deadline = threadPool.handleTimedWork()
                if _slowPath(deadline > 0) {
                    _ = threadPool.semaphore.wait(timeout: .init(uptimeNanoseconds: deadline))
                } else {
                    threadPool.semaphore.wait()
                }
            }
        }
        
        public func stop() {
            runningLock.withLock { running = false }
            threadPool.semaphore.signal()
        }
        
        deinit {
            stop()
        }
    }
}
#endif
