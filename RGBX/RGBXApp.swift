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
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true
        metalView.colorPixelFormat = .bgra8Unorm
        renderer = Renderer(device: device, metalView: metalView)
        metalView.delegate = renderer
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(device: device, metalView: metalView)
        }.windowResizability(.contentSize)
    }
}

class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice
    var view: MTKView
    var commandQueue: MTLCommandQueue
    var vertexDescriptor: MTLVertexDescriptor
    var pipelineState: MTLRenderPipelineState
    let plane = Plane()
    
    init(device: MTLDevice, metalView: MTKView) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        view = metalView
        vertexDescriptor = Renderer.makeVertexDescriptor()
        pipelineState = Renderer.makePipelineState(device: device,
                                                   view: metalView,
                                                   vertexDescriptor: vertexDescriptor)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        /// Position
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        /// Normal
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        /// Color
        vertexDescriptor.attributes[2].format = .float3
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.size * 6
        vertexDescriptor.attributes[2].bufferIndex = 0
        /// Configure layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 9
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
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        drawPlane(renderEncoder: renderEncoder)
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func drawPlane(renderEncoder: MTLRenderCommandEncoder) {
        var vertexUniforms = VertexUniforms(viewProjectionMatrix: matrix_identity_float4x4,
                                            modelMatrix: plane.modelMatrix,
                                            normalMatrix: plane.normalMatrix)
        renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
        
        let vertexBuffer = device.makeBuffer(bytes: plane.vertices,
                                             length: plane.vertices.count * MemoryLayout<Vertex>.stride,
                                             options: .storageModeShared)
        let indexBuffer = device.makeBuffer(bytes: plane.indices,
                                            length: plane.indices.count * MemoryLayout<UInt16>.size,
                                            options: [])!
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: plane.indices.count,
                                            indexType: .uint16,
                                            indexBuffer: indexBuffer,
                                            indexBufferOffset: 0)
    }
}

struct VertexUniforms {
    var viewProjectionMatrix: simd_float4x4
    var modelMatrix: simd_float4x4
    var normalMatrix: simd_float3x3
}

struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

struct Plane {
    let vertices: [Vertex] = [
        Vertex(position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(1, 0, 0, 1)),
        Vertex(position: SIMD3<Float>( 1, -1, 0), color: SIMD4<Float>(0, 1, 0, 1)),
        Vertex(position: SIMD3<Float>(-1,  1, 0), color: SIMD4<Float>(0, 0, 1, 1)),
        Vertex(position: SIMD3<Float>( 1,  1, 0), color: SIMD4<Float>(1, 0, 0, 1))
    ]
    
    let indices: [UInt16] = [
        0, 1, 2,
        2, 1, 3
    ]
    
    let modelMatrix = matrix_identity_float4x4
    let normalMatrix = matrix_identity_float3x3
}
