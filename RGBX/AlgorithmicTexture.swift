import MetalKit
import simd

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

class AlgorithmicTexture: ObservableObject {
    @Published var params: TextureParams = TextureParams() { didSet { hasChanged = true } }
    var material = Material()
    @Published var hasChanged: Bool = true
    
    init(device: MTLDevice) {
        material = AlgorithmicTexture.makeMaterial(device: device)
    }
    
    static func makeMaterialTextureDescriptor() -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 300
        textureDescriptor.height = 300
        textureDescriptor.pixelFormat = .bgra8Unorm
        return textureDescriptor
    }
    
    static func makeMaterial(device: MTLDevice) -> Material {
        let textureDescriptor = AlgorithmicTexture.makeMaterialTextureDescriptor()
        let texture = device.makeTexture(descriptor: textureDescriptor)
        let material = Material(texture: texture)
        return material
    }
    
    func setTextureColorData(device: MTLDevice, commandBuffer: MTLCommandBuffer) {
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
            if i % Int(params.textureP3) == 0 {
                color = color << UInt32(params.textureP1)
            } else if i % Int(params.textureP4) == 0 {
                color = color >> UInt32(params.textureP2)
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
}
