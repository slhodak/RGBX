import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    let logger = DebouncedLogger()
    var device: MTLDevice
    var view: MTKView
    var commandQueue: MTLCommandQueue
    var vertexDescriptor: MTLVertexDescriptor
    var pipelineStates: [FragmentAlgorithm: MTLRenderPipelineState] = [:]
    var samplerState: MTLSamplerState
    @Published var algorithmicTexture: AlgorithmicTexture
    @Published var minMagFilter: MTLSamplerMinMagFilter = .linear { didSet { shouldRemakeSamplerState = true } }
    var shouldRemakeSamplerState = false
    var useOriginalMaterial = true
    @Published var fragmentAlgorithm: FragmentAlgorithm = .fragment_algo_a
    @Published var editableFragmentUniformsA = EditableFragmentUniformsA()
    @Published var editableFragmentUniformsB = EditableFragmentUniformsB()
    var fragmentUniformsA: FragmentUniformsA = FragmentUniformsA()
    var fragmentUniformsB: FragmentUniformsB = FragmentUniformsB()
    var vertexUniforms: VertexUniforms = VertexUniforms()
    let plane = Plane()
    var previousFrame: MTLTexture
    
    init(device: MTLDevice, metalView: MTKView) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        view = metalView
        vertexDescriptor = Renderer.makeVertexDescriptor()
        pipelineStates = Renderer.makePipelineStates(device: device,
                                                     metalView: metalView,
                                                     vertexDescriptor: vertexDescriptor)
        samplerState = Renderer.makeSamplerState(device: device,
                                                 minMagFilter: .linear)
        algorithmicTexture = AlgorithmicTexture(device: device)
        previousFrame = Renderer.makeFrameTexture(device: device)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    static func makePipelineStates(device: MTLDevice, metalView: MTKView, vertexDescriptor: MTLVertexDescriptor) -> [FragmentAlgorithm: MTLRenderPipelineState] {
        return [
            .fragment_algo_a: Renderer.makePipelineState(device: device,
                                                         fragmentAlgorithm: .fragment_algo_a,
                                                         view: metalView,
                                                         vertexDescriptor: vertexDescriptor),
            .fragment_algo_b: Renderer.makePipelineState(device: device,
                                                         fragmentAlgorithm: .fragment_algo_b,
                                                         view: metalView,
                                                         vertexDescriptor: vertexDescriptor)
        ]
    }
    
    static func makeFrameTexture(device: MTLDevice) -> MTLTexture {
        let frameTextureDescriptor = Renderer.makeFrameTextureDescriptor()
        return device.makeTexture(descriptor: frameTextureDescriptor)!
    }
    
    static func makeFrameTextureDescriptor() -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1200, height: 1200, mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderWrite, .shaderRead]
        textureDescriptor.storageMode = .private
        return textureDescriptor
    }
    
    static func makeSamplerState(device: MTLDevice, minMagFilter: MTLSamplerMinMagFilter) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        /// There is a reason that changing these on the fly does not automatically result in a change to the way the pixels look,
        /// but I don't understand what it is yet.
        samplerDescriptor.minFilter = minMagFilter
        samplerDescriptor.magFilter = minMagFilter
        //samplerDescriptor.mipFilter = .linear
        samplerDescriptor.rAddressMode = .repeat
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        /// Position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        /// Texture Coordinates
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.size * 3
        vertexDescriptor.attributes[2].bufferIndex = 0
        /// Configure layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 5
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        return vertexDescriptor
    }
    
    static func makePipelineState(device: MTLDevice, fragmentAlgorithm: FragmentAlgorithm, view: MTKView, vertexDescriptor: MTLVertexDescriptor) -> MTLRenderPipelineState {
        let defaultLibrary = device.makeDefaultLibrary()!
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: fragmentAlgorithm.rawValue)
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    func copyToDrawable(source: MTLTexture, drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            fatalError("Failed to make blit command encoder")
        }
        
        blitEncoder.copy(from: source,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: drawable.texture.width,
                                             height: drawable.texture.height,
                                             depth: 1),
                         to: drawable.texture,
                         destinationSlice: 0,
                         destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        
        blitEncoder.endEncoding()
    }
    
    func setVertexUniforms() {
        vertexUniforms = VertexUniforms(textureScale: algorithmicTexture.params.textureScaleXY,
                                        shouldResize: useOriginalMaterial ? 1 : 0)
    }
    
    func setFragmentBytes(on renderEncoder: MTLRenderCommandEncoder) {
        /// Update this value in case it has changed
        editableFragmentUniformsA.useOriginalMaterial = useOriginalMaterial
        editableFragmentUniformsB.useOriginalMaterial = useOriginalMaterial
        
        switch fragmentAlgorithm {
        case .fragment_algo_a:
            fragmentUniformsA = editableFragmentUniformsA.asStaticStruct()
            renderEncoder.setFragmentBytes(&fragmentUniformsA,
                                           length: MemoryLayout<FragmentUniformsA>.stride,
                                           index: 0)
        case .fragment_algo_b:
            fragmentUniformsB = editableFragmentUniformsB.asStaticStruct()
            renderEncoder.setFragmentBytes(&fragmentUniformsB,
                                           length: MemoryLayout<FragmentUniformsB>.stride,
                                           index: 0)
        }
    }
    
    func attachOutputTexture(to renderPassDescriptor: MTLRenderPassDescriptor) {
        renderPassDescriptor.colorAttachments[0].texture = previousFrame
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    }
    
    func setSamplerState(on renderEncoder: MTLRenderCommandEncoder) {
        if shouldRemakeSamplerState {
            samplerState = Renderer.makeSamplerState(device: device, minMagFilter: minMagFilter)
            shouldRemakeSamplerState = false
        }
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
    }
    
    func setFragmentTexture(on renderEncoder: MTLRenderCommandEncoder) {
        if useOriginalMaterial {
            renderEncoder.setFragmentTexture(algorithmicTexture.material.texture, index: 0)
            useOriginalMaterial = false
        } else {
            renderEncoder.setFragmentTexture(previousFrame, index: 0)
        }
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        attachOutputTexture(to: renderPassDescriptor)
        
        if algorithmicTexture.hasChanged {
            algorithmicTexture.setTextureColorData(device: device, commandBuffer: commandBuffer)
            algorithmicTexture.hasChanged = false
            useOriginalMaterial = true
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        setVertexUniforms()
        setSamplerState(on: renderEncoder)
        renderEncoder.setRenderPipelineState(pipelineStates[fragmentAlgorithm]!)
        renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
        setFragmentBytes(on: renderEncoder)
        
        drawPlane(renderEncoder: renderEncoder)
        renderEncoder.endEncoding()
        
        copyToDrawable(source: previousFrame, drawable: drawable, commandBuffer: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func drawPlane(renderEncoder: MTLRenderCommandEncoder) {
        let vertexBuffer = device.makeBuffer(bytes: plane.vertices,
                                             length: plane.vertices.count * MemoryLayout<Vertex>.stride,
                                             options: .storageModeShared)
        let indexBuffer = device.makeBuffer(bytes: plane.indices,
                                            length: plane.indices.count * MemoryLayout<UInt16>.size,
                                            options: [])!
        
        setFragmentTexture(on: renderEncoder)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: plane.indices.count,
                                            indexType: .uint16,
                                            indexBuffer: indexBuffer,
                                            indexBufferOffset: 0)
    }
}

struct VertexUniforms {
    var textureScale: simd_float2 = simd_float2(1, 1)
    var shouldResize: Int = 0
}

struct Vertex {
    var position: (Float, Float, Float)
    var texCoords: (Float, Float)
}

struct Plane {
    let vertices: [Vertex] = [
        Vertex(position: (-1, -1, 0), texCoords: (0, 1)),
        Vertex(position: ( 1, -1, 0), texCoords: (1, 1)),
        Vertex(position: (-1,  1, 0), texCoords: (0, 0)),
        Vertex(position: ( 1,  1, 0), texCoords: (1, 0))
    ]
    
    let indices: [UInt16] = [
        0, 1, 2,
        2, 1, 3
    ]
}
