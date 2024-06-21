import MetalKit
import simd

class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice
    var view: MTKView
    var commandQueue: MTLCommandQueue
    var vertexDescriptor: MTLVertexDescriptor
    var pipelineState: MTLRenderPipelineState
    var samplerState: MTLSamplerState
    var textureDescriptor: MTLTextureDescriptor
    var material: Material
    let plane = Plane()
    
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
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    static func makeTextureDescriptor() -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 256
        textureDescriptor.height = 256
        textureDescriptor.pixelFormat = .bgra8Unorm
        return textureDescriptor
    }
    
    static func makeMaterial(device: MTLDevice, textureDescriptor: MTLTextureDescriptor) -> Material {
//        let textureLoader = MTKTextureLoader(device: device)
//        let options: [MTKTextureLoader.Option: Any] = [
//            .generateMipmaps: true,
//            .SRGB: true,
//        ]
//        let baseColorTexture = try? textureLoader.newTexture(name: "neon_purple_grid",
//                                                             scaleFactor: 1,
//                                                             bundle: nil,
//                                                             options: options)
//        let material = Material(baseColorTexture: baseColorTexture)
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        let material = Material(texture: texture)
        return material
    }
    
    static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
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
        var colorData = [RGBAPixel](repeating: RGBAPixel(b: 255, g: 0, r: 0, a: 255), count: pixelCount)
        
        let bufferSize = textureDescriptor.width * textureDescriptor.height * MemoryLayout<RGBAPixel>.size
        let buffer = colorData.withUnsafeBytes { bytes in
            return device.makeBuffer(bytes: bytes.baseAddress!,
                                     length: bufferSize,
                                     options: [])
        }
        
        guard let buffer = buffer else {
            fatalError("Failed to create texture color data buffer")
        }
        
        let bytesPerRow = textureDescriptor.width * MemoryLayout<RGBAPixel>.size
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
        
        setTextureColorData(commandBuffer: commandBuffer)
    
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        renderEncoder.setRenderPipelineState(pipelineState)
        drawPlane(renderEncoder: renderEncoder)
        renderEncoder.endEncoding()
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
        
        renderEncoder.setFragmentTexture(material.texture, index: 0)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: plane.indices.count,
                                            indexType: .uint16,
                                            indexBuffer: indexBuffer,
                                            indexBufferOffset: 0)
    }
}

struct Vertex {
    var position: (Float, Float, Float)
    var texCoords: (Float, Float)
}

struct Plane {
    let vertices: [Vertex] = [
        Vertex(position: (-0.9, -0.9, 0), texCoords: (0, 1)),
        Vertex(position: ( 0.9, -0.9, 0), texCoords: (1, 1)),
        Vertex(position: (-0.9,  0.9, 0), texCoords: (0, 0)),
        Vertex(position: ( 0.9,  0.9, 0), texCoords: (1, 0))
    ]
    
    let indices: [UInt16] = [
        0, 1, 2,
        2, 1, 3
    ]
}

struct Material {
    var texture: MTLTexture?
}

struct RGBAPixel {
    var b: UInt8
    var g: UInt8
    var r: UInt8
    var a: UInt8
}
