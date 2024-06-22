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
