import SwiftUI
import MetalKit

struct ContentView: View {
    let device: MTLDevice
    let metalView: MTKView
    
    var body: some View {
        VStack {
            Text("RGBX")
            MetalView(device: device, metalView: metalView)
        }
        .frame(width: 400, height: 400)
        .padding()
    }
}
