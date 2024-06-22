import SwiftUI
import MetalKit

struct ContentView: View {
    let device: MTLDevice
    let metalView: MTKView
    @StateObject var renderer: Renderer
    
    var body: some View {
        VStack {
            Text("RGBX")
            MetalView(device: device, metalView: metalView)
                .frame(width: 600, height: 600)
            LabeledSlider(name: "Texture Scale", value: $renderer.textureScale, min: 0.001, max: 2.0)
            LabeledSlider(name: "Parameter 1", value: $renderer.textureP1, min: 1, max: 32, step: 1)
            LabeledSlider(name: "Parameter 2", value: $renderer.textureP2, min: 1, max: 32, step: 1)
            LabeledSlider(name: "Parameter 3", value: $renderer.textureP3, min: 1, max: 255)
            LabeledSlider(name: "Parameter 4", value: $renderer.textureP4, min: 1, max: 255)
        }
        .frame(width: 800, height: 800)
        .padding()
    }
}
