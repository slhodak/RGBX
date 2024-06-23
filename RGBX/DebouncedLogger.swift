import Foundation
import MetalKit

class DebouncedLogger {
    private var lastLogged = [String: TimeInterval]()
    private let debounceInterval: TimeInterval
    
    init(debounceInterval: TimeInterval = 5.0) {
        self.debounceInterval = debounceInterval
    }
    
    func log(_ type: String, _ message: String) {
        let lastLogTime = lastLogged[type]
        let currentTime = CACurrentMediaTime()
        
        if lastLogTime != nil {
            if currentTime - lastLogTime! <= debounceInterval {
                return
            }
        }
        
        print(message)
        lastLogged[type] = currentTime
    }
}

class Throttler {
    static let shared = Throttler()
    
    private var intervals: [String: CFTimeInterval] = [:]
    private var lastExecutionTimes: [String: CFTimeInterval] = [:]
    
    private init() {}
    
    func run(forKey key: String, every interval: CFTimeInterval = 1, block: @escaping () -> Void) {
        if self.intervals[key] == nil  {
            self.intervals[key] = interval
            self.lastExecutionTimes[key] = 0
        }
        
        let currentTime = CACurrentMediaTime()
        if let lastExecutionTime = self.lastExecutionTimes[key],
           currentTime - lastExecutionTime < interval {
            return
        }
        
        self.lastExecutionTimes[key] = currentTime
        block()
    }
}
