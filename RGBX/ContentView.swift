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
        VStack(alignment: .leading) {
            Picker("Fragment Shading Algorithm", selection: $renderer.fragmentAlgorithm) {
                ForEach(FragmentAlgorithm.allCases, id: \.self) { value in
                    Text(value.rawValue)
                }
            }
            .frame(width: 400)
            Text("Fragment Parameters - GPU")
            switch renderer.fragmentAlgorithm {
            case .fragment_algo_a:
                LabeledSlider(name: "Fragment 1",
                              value: $renderer.editableFragmentUniformsA.fragmentP1,
                              min: 1,
                              max: 1200*1200)
                LabeledSlider(name: "Fragment 2",
                              value: $renderer.editableFragmentUniformsA.fragmentP2,
                              min: 1,
                              max: 1200*1200)
                LabeledSlider(name: "Fragment 3",
                              value: $renderer.editableFragmentUniformsA.fragmentP3,
                              min: 1,
                              max: 1200*1200)
                LabeledSlider(name: "Param R",
                              value: $renderer.editableFragmentUniformsA.fragmentPr,
                              min: 0,
                              max: 7,
                              step: 1)
                LabeledSlider(name: "Param G",
                              value: $renderer.editableFragmentUniformsA.fragmentPg,
                              min: 0,
                              max: 7,
                              step: 1)
                LabeledSlider(name: "Param B",
                              value: $renderer.editableFragmentUniformsA.fragmentPb,
                              min: 0,
                              max: 7,
                              step: 1)
                
            case .fragment_algo_b:
                LabeledSlider(name: "Param X",
                              value: $renderer.editableFragmentUniformsB.fragmentX,
                              min: 0,
                              max: 7,
                              step: 1)
            }
            
            Text("Texture Parameters - CPU")
            Picker("Min Mag Filter", selection: $renderer.minMagFilter) {
                ForEach([MTLSamplerMinMagFilter.linear, MTLSamplerMinMagFilter.nearest], id: \.self) { value in
                    switch value {
                    case .linear:
                        Text("Linear")
                    case .nearest:
                        Text("Nearest")
                    @unknown default:
                        Text("unknown")
                    }
                }
            }
            .frame(width: 400)
            LabeledSlider(name: "Texture Scale", value: $renderer.textureParams.textureScale, min: 0.001, max: 2.0)
            LabeledSlider(name: "Texture 1", value: $renderer.textureParams.textureP1, min: 1, max: 32, step: 1)
            LabeledSlider(name: "Texture 2", value: $renderer.textureParams.textureP2, min: 1, max: 32, step: 1)
            LabeledSlider(name: "Texture 3", value: $renderer.textureParams.textureP3, min: 1, max: 255)
            LabeledSlider(name: "Texture 4", value: $renderer.textureParams.textureP4, min: 1, max: 255)
        }
    }
}
