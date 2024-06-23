import SwiftUI
import MetalKit

struct ContentView: View {
    let device: MTLDevice
    let metalView: MTKView
    var renderer: Renderer
    
    var body: some View {
        ScrollView {
            MetalView(device: device, metalView: metalView)
                .frame(width: 600, height: 600)
            AlgorithmParams(renderer: renderer)
        }
        .frame(width: 600)
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
                LabeledSlider(name: "Top Threshold",
                              value: $renderer.editableFragmentUniformsB.topThreshold,
                              min: 0,
                              max: 4)
                LabeledSlider(name: "Bottom Threshold",
                              value: $renderer.editableFragmentUniformsB.bottomThreshold,
                              min: 0,
                              max: 4)
                LabeledSlider(name: "Live R",
                              value: $renderer.editableFragmentUniformsB.liveColor.x)
                LabeledSlider(name: "Live G",
                              value: $renderer.editableFragmentUniformsB.liveColor.y)
                LabeledSlider(name: "Live B",
                              value: $renderer.editableFragmentUniformsB.liveColor.z)
                LabeledSlider(name: "Dead R",
                              value: $renderer.editableFragmentUniformsB.deadColor.x)
                LabeledSlider(name: "Dead G",
                              value: $renderer.editableFragmentUniformsB.deadColor.y)
                LabeledSlider(name: "Dead B",
                              value: $renderer.editableFragmentUniformsB.deadColor.z)
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
            
            LabeledSlider(name: "Texture Scale", value: $renderer.algorithmicTexture.params.textureScale, min: 0.001, max: 2.0)
            LabeledSlider(name: "Texture 1", value: $renderer.algorithmicTexture.params.textureP1, min: 1, max: 32, step: 1)
            LabeledSlider(name: "Texture 2", value: $renderer.algorithmicTexture.params.textureP2, min: 1, max: 32, step: 1)
            LabeledSlider(name: "Texture 3", value: $renderer.algorithmicTexture.params.textureP3, min: 1, max: 255)
            LabeledSlider(name: "Texture 4", value: $renderer.algorithmicTexture.params.textureP4, min: 1, max: 255)
        }
    }
}
