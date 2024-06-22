import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    let logger = DebouncedLogger()
    var device: MTLDevice
    var view: MTKView
    var commandQueue: MTLCommandQueue
    var vertexDescriptor: MTLVertexDescriptor
    var pipelineState: MTLRenderPipelineState
    var samplerState: MTLSamplerState
    var textureDescriptor: MTLTextureDescriptor
    @Published var textureScale: Float = 1 { didSet { shouldSetTextureColorData = true } }
    @Published var textureP1: Float = 1 { didSet { shouldSetTextureColorData = true } }
    @Published var textureP2: Float = 1 { didSet { shouldSetTextureColorData = true } }
    @Published var textureP3: Float = 1 { didSet { shouldSetTextureColorData = true } }
    @Published var textureP4: Float = 1 { didSet { shouldSetTextureColorData = true } }
    var shouldSetTextureColorData = true
    @Published var fragmentP1: Float = 1
    @Published var fragmentP2: Float = 1
    @Published var fragmentPr: Float = 1
    @Published var fragmentPg: Float = 1
    @Published var fragmentPb: Float = 1
    var material: Material
    let plane = Plane()
    var previousFrame: MTLTexture?
    
    init(device: MTLDevice, metalView: MTKView) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        view = metalView
        vertexDescriptor = Renderer.makeVertexDescriptor()
        pipelineState = Renderer.makePipelineState(device: device,
                                                   view: metalView,
                                                   vertexDescriptor: vertexDescriptor)
        samplerState = Renderer.makeSamplerState(device: device)
        textureDescriptor = Renderer.makeTextureDescriptor()
        material = Renderer.makeMaterial(device: device, textureDescriptor: textureDescriptor)
        previousFrame = device.makeTexture(descriptor: textureDescriptor)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    static func makeTextureDescriptor() -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 300
        textureDescriptor.height = 300
        textureDescriptor.pixelFormat = .bgra8Unorm
        return textureDescriptor
    }
    
    static func makeMaterial(device: MTLDevice, textureDescriptor: MTLTextureDescriptor) -> Material {
        let texture = device.makeTexture(descriptor: textureDescriptor)
        let material = Material(texture: texture)
        return material
    }
    
    static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
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
    
    static func makePipelineState(device: MTLDevice, view: MTKView, vertexDescriptor: MTLVertexDescriptor) -> MTLRenderPipelineState {
        let defaultLibrary = device.makeDefaultLibrary()!
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragment_main")
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
        
        let pixelCount = textureDescriptor.width * textureDescriptor.height
        /// argb because byte order is bgra but my M1 is little-endian, so LSB goes first
        let opaque: UInt32      = 0b11111111_00000000_00000000_00000000
        var color: UInt32       = 0b00000000_00000000_00000000_00000000
        let colorMask: UInt32   = 0b00000000_11111111_11111111_11111111
        var colorData: [UInt32] = []
        
        for i in 0..<pixelCount {
            colorData.append(color)
            if i % Int(textureP3) == 0 {
                color = color << UInt32(textureP1)
            } else if i % Int(textureP4) == 0 {
                color = color >> UInt32(textureP2)
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
        
        let bytesPerRow = textureDescriptor.width * MemoryLayout<UInt32>.size
        blitEncoder.copy(from: buffer,
                         sourceOffset: 0,
                         sourceBytesPerRow: bytesPerRow,
                         sourceBytesPerImage: bufferSize,
                         sourceSize: MTLSize(width: textureDescriptor.width,
                                             height: textureDescriptor.height,
                                             depth: 1),
                         to: material.texture!,
                         destinationSlice: 0, destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        if shouldSetTextureColorData {
            setTextureColorData(commandBuffer: commandBuffer)
            shouldSetTextureColorData = false
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        var vertexUniforms = VertexUniforms(textureScale: simd_float2(textureScale, textureScale))
        var fragmentUniforms = FragmentUniforms(fragmentP1: UInt8(fragmentP1),
                                                fragmentP2: UInt8(fragmentP2),
                                                fragmentPr: UInt8(fragmentPr),
                                                fragmentPg: UInt8(fragmentPg),
                                                fragmentPb: UInt8(fragmentPb))
        
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
        renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
        drawPlane(renderEncoder: renderEncoder)
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        // TODO: Copy the contents of the render target to previousFrame texture
    }
    
    func drawPlane(renderEncoder: MTLRenderCommandEncoder) {
        let vertexBuffer = device.makeBuffer(bytes: plane.vertices,
                                             length: plane.vertices.count * MemoryLayout<Vertex>.stride,
                                             options: .storageModeShared)
        let indexBuffer = device.makeBuffer(bytes: plane.indices,
                                            length: plane.indices.count * MemoryLayout<UInt16>.size,
                                            options: [])!
        
        renderEncoder.setFragmentTexture(material.texture, index: 0)
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

struct FragmentUniforms {
    var fragmentP1: UInt8
    var fragmentP2: UInt8
    var fragmentPr: UInt8
    var fragmentPg: UInt8
    var fragmentPb: UInt8
}
