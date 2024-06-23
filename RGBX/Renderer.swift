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
    @Published var textureParams = TextureParams() { didSet { shouldSetTextureColorData = true } }
    @Published var minMagFilter: MTLSamplerMinMagFilter = .linear { didSet { shouldRemakeSamplerState = true } }
    var shouldSetTextureColorData = true
    var shouldRemakeSamplerState = false
    var usingOriginalMaterial = true
    @Published var fragmentAlgorithm: FragmentAlgorithm = .fragment_algo_a
    @Published var editableFragmentUniformsA = EditableFragmentUniformsA()
    @Published var editableFragmentUniformsB = EditableFragmentUniformsB()
    var fragmentUniformsA: FragmentUniformsA = FragmentUniformsA()
    var fragmentUniformsB: FragmentUniformsB = FragmentUniformsB()
    var material: Material
    let plane = Plane()
    var previousFrame: MTLTexture
    
    init(device: MTLDevice, metalView: MTKView) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        view = metalView
        vertexDescriptor = Renderer.makeVertexDescriptor()
        pipelineStates = [
            .fragment_algo_a: Renderer.makePipelineState(device: device,
                                                         fragmentAlgorithm: .fragment_algo_a,
                                                         view: metalView,
                                                         vertexDescriptor: vertexDescriptor),
            .fragment_algo_b: Renderer.makePipelineState(device: device,
                                                         fragmentAlgorithm: .fragment_algo_b,
                                                         view: metalView,
                                                         vertexDescriptor: vertexDescriptor)
        ]
        
        samplerState = Renderer.makeSamplerState(device: device,
                                                 minMagFilter: .linear)
        material = Renderer.makeMaterial(device: device)
        let frameTextureDescriptor = Renderer.makeFrameTextureDescriptor()
        previousFrame = device.makeTexture(descriptor: frameTextureDescriptor)!
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    static func makeMaterialTextureDescriptor() -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 300
        textureDescriptor.height = 300
        textureDescriptor.pixelFormat = .bgra8Unorm
        return textureDescriptor
    }
    
    static func makeFrameTextureDescriptor() -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1200, height: 1200, mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderWrite, .shaderRead]
        textureDescriptor.storageMode = .private
        return textureDescriptor
    }
    
    static func makeMaterial(device: MTLDevice) -> Material {
        let textureDescriptor = Renderer.makeMaterialTextureDescriptor()
        let texture = device.makeTexture(descriptor: textureDescriptor)
        let material = Material(texture: texture)
        return material
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
    
    func setTextureColorData(commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder: MTLBlitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
            fatalError("Failed to create blit encoder")
        }
        
        guard let texture = material.texture else { return }
        
        let pixelCount = texture.width * texture.height
        /// argb because byte order is bgra but my M1 is little-endian, so LSB goes first
        let opaque: UInt32      = 0b11111111_00000000_00000000_00000000
        var color: UInt32       = 0b00000000_00000000_00000000_00000000
        let colorMask: UInt32   = 0b00000000_11111111_11111111_11111111
        var colorData: [UInt32] = []
        
        for i in 0..<pixelCount {
            colorData.append(color)
            if i % Int(textureParams.textureP3) == 0 {
                color = color << UInt32(textureParams.textureP1)
            } else if i % Int(textureParams.textureP4) == 0 {
                color = color >> UInt32(textureParams.textureP2)
            }
            color = (color + 1) % colorMask
            color = color | opaque
        }
        
        let bufferSize = pixelCount * MemoryLayout<UInt32>.size
        let buffer = colorData.withUnsafeBytes { bytes in
            return device.makeBuffer(bytes: bytes.baseAddress!,
                                     length: bufferSize,
                                     options: [])
        }
        
        guard let buffer = buffer else {
            fatalError("Failed to create texture color data buffer")
        }
        
        let bytesPerRow = texture.width * MemoryLayout<UInt32>.size
        blitEncoder.copy(from: buffer,
                         sourceOffset: 0,
                         sourceBytesPerRow: bytesPerRow,
                         sourceBytesPerImage: bufferSize,
                         sourceSize: MTLSize(width: texture.width,
                                             height: texture.height,
                                             depth: 1),
                         to: material.texture!,
                         destinationSlice: 0, destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        
        blitEncoder.endEncoding()
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
    
    func setFragmentBytes(on renderEncoder: MTLRenderCommandEncoder) {
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
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        renderPassDescriptor.colorAttachments[0].texture = previousFrame
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
        
        if shouldSetTextureColorData {
            setTextureColorData(commandBuffer: commandBuffer)
            shouldSetTextureColorData = false
            usingOriginalMaterial = true
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        var vertexUniforms = VertexUniforms(textureScale: textureParams.textureScaleXY,
                                            shouldResize: usingOriginalMaterial ? 1 : 0)
        
        editableFragmentUniformsA.usingOriginalMaterial = usingOriginalMaterial
        editableFragmentUniformsB.usingOriginalMaterial = usingOriginalMaterial
        
        if shouldRemakeSamplerState {
            samplerState = Renderer.makeSamplerState(device: device, minMagFilter: minMagFilter)
            shouldRemakeSamplerState = false
        }
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
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
        
        if usingOriginalMaterial {
            renderEncoder.setFragmentTexture(material.texture, index: 0)
            usingOriginalMaterial = false
        } else {
            renderEncoder.setFragmentTexture(previousFrame, index: 0)
        }
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: plane.indices.count,
                                            indexType: .uint16,
                                            indexBuffer: indexBuffer,
                                            indexBufferOffset: 0)
    }
}

struct VertexUniforms {
    var textureScale: simd_float2
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

struct Material {
    var texture: MTLTexture?
}

struct TextureParams {
    var textureScale: Float = 1
    var textureScaleXY: simd_float2 {
        simd_float2(textureScale, textureScale)
    }
    var textureP1: Float = 1
    var textureP2: Float = 1
    var textureP3: Float = 1
    var textureP4: Float = 1
    var minMagFilter: MTLSamplerMinMagFilter = .linear
}

enum FragmentAlgorithm: String, CaseIterable {
    case fragment_algo_a
    case fragment_algo_b
}

struct FragmentUniformsA {
    var fragmentP1: Int32 = 1
    var fragmentP2: Int32 = 1
    var fragmentP3: Int32 = 1
    var fragmentPr: UInt8 = 1
    var fragmentPg: UInt8 = 1
    var fragmentPb: UInt8 = 1
    var usingOriginalMaterial: Bool = true
    
    init() {}
    
    init(from editable: EditableFragmentUniformsA) {
        self.fragmentP1 = Int32(editable.fragmentP1)
        self.fragmentP2 = Int32(editable.fragmentP2)
        self.fragmentP3 = Int32(editable.fragmentP3)
        self.fragmentPr = UInt8(editable.fragmentPr)
        self.fragmentPg = UInt8(editable.fragmentPg)
        self.fragmentPb = UInt8(editable.fragmentPb)
        self.usingOriginalMaterial = editable.usingOriginalMaterial
    }
}

struct EditableFragmentUniformsA {
    var fragmentP1: Float = 1
    var fragmentP2: Float = 1
    var fragmentP3: Float = 1
    var fragmentPr: Float = 1
    var fragmentPg: Float = 1
    var fragmentPb: Float = 1
    var usingOriginalMaterial: Bool = true
    
    func asStaticStruct() -> FragmentUniformsA {
        return FragmentUniformsA(from: self)
    }
}

struct FragmentUniformsB {
    var fragmentX: UInt8 = 1
    var usingOriginalMaterial: Bool = true
    
    init() {}
    
    init(from editable: EditableFragmentUniformsB) {
        self.fragmentX = UInt8(editable.fragmentX)
        self.usingOriginalMaterial = editable.usingOriginalMaterial
    }
}

struct EditableFragmentUniformsB {
    var fragmentX: Float = 1
    var usingOriginalMaterial: Bool = true
    
    func asStaticStruct() -> FragmentUniformsB {
        return FragmentUniformsB(from: self)
    }
}
