//
//  BoundedThreadPool.swift
//  
//
//  Created by Sebastian Toivonen on 30.12.2022.
//
#if canImport(Atomics)
import Atomics
import Dispatch
import Foundation
import HeapModule

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
    internal let running: ManagedAtomic<Bool> = ManagedAtomic(false)
    
    @usableFromInline
    internal let handlingTimedWork: ManagedAtomic<Bool> = ManagedAtomic(false)
    
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
    
    public final func run(_ work: @escaping () -> Void) -> Bool {
        let work = Work(work: work)
        let enqueued = workQueue.enqueue(work)
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
    @discardableResult
    internal func handleTimedWork() -> Int {
        if handlingTimedWork.exchange(true, ordering: .acquiring) { return 0 }
        defer { handlingTimedWork.store(false, ordering: .releasing) }
        
        // Move the enqueued work into the priority queue
        for work in timedWorkQueue {
            timedWork.insert(TimedWork(work.work, work.deadline))
        }
        
        // Process the priority queue
        let currentTime = DispatchTime.now().uptimeNanoseconds
        while let workItem = timedWork.max() {
            if workItem.deadline > currentTime {
                return currentTime.distance(to: workItem.deadline)
            }
            
            let workItem = timedWork.removeMax()
            // Enqueue the work to a worker thread
            if !run(workItem.work) {
                workItem.work()
                return 1
            }
        }
        return 0
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
                while let work = threadPool.workQueue.dequeue() {
                    work.work()
                    threadPool.handleTimedWork()
                }
                
                let sleepTime = threadPool.handleTimedWork()
                if _slowPath(sleepTime > 0) {
                    if sleepTime == 1 { continue }
                    _ = threadPool.semaphore.wait(timeout: .now() + .nanoseconds(sleepTime))
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
#endif