import SwiftUI
import MetalKit
import simd

@main
struct RGBXApp: App {
    let renderer: Renderer
    let metalView: MTKView
    let device: MTLDevice
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create system default Metal device")
        }
        
        self.device = device
        metalView = MTKView()
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = false
        renderer = Renderer(device: device, metalView: metalView)
        metalView.delegate = renderer
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(device: device, metalView: metalView, renderer: renderer)
        }.windowResizability(.contentSize)
    }
}
