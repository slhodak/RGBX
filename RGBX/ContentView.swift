import SwiftUI
import MetalKit

struct ContentView: View {
    let device: MTLDevice
    let metalView: MTKView
    var renderer: Renderer
    
    var body: some View {
        VStack {
            MetalView(device: device, metalView: metalView)
                .frame(width: 600, height: 600)
            AlgorithmParams(renderer: renderer)
        }
        .frame(width: 800, height: 1000)
        .padding()
    }
}

struct AlgorithmParams: View {
    @StateObject var renderer: Renderer
    
    var body: some View {
        Picker("Fragment Shading Algorithm", selection: $renderer.fragmentAlgorithm) {
            ForEach(FragmentAlgorithm.allCases, id: \.self) { value in
                Text(value.rawValue)
            }
        }
        .frame(width: 400)
        Text("Fragment Parameters - GPU")
        switch renderer.fragmentAlgorithm {
        case .fragment_algo_a:
            LabeledSlider(name: "Fragment 1", value: $renderer.fragmentP1, min: 1, max: 1200*1200)
            LabeledSlider(name: "Fragment 2", value: $renderer.fragmentP2, min: 1, max: 1200*1200)
            LabeledSlider(name: "Fragment 3", value: $renderer.fragmentP3, min: 1, max: 1200*1200)
            LabeledSlider(name: "Param R", value: $renderer.fragmentPr, min: 0, max: 7, step: 1)
            LabeledSlider(name: "Param G", value: $renderer.fragmentPg, min: 0, max: 7, step: 1)
            LabeledSlider(name: "Param B", value: $renderer.fragmentPb, min: 0, max: 7, step: 1)
        case .fragment_algo_b:
            LabeledSlider(name: "Param X", value: $renderer.fragmentX, min: 0, max: 7, step: 1)
        }

        Text("Texture Parameters - CPU")
        LabeledSlider(name: "Texture Scale", value: $renderer.textureScale, min: 0.001, max: 2.0)
        LabeledSlider(name: "Texture 1", value: $renderer.textureP1, min: 1, max: 32, step: 1)
        LabeledSlider(name: "Texture 2", value: $renderer.textureP2, min: 1, max: 32, step: 1)
        LabeledSlider(name: "Texture 3", value: $renderer.textureP3, min: 1, max: 255)
        LabeledSlider(name: "Texture 4", value: $renderer.textureP4, min: 1, max: 255)
    }
}
