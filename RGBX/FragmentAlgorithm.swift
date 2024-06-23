import simd

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
    var useOriginalMaterial: Bool = true
    
    init() {}
    
    init(from editable: EditableFragmentUniformsA) {
        self.fragmentP1 = Int32(editable.fragmentP1)
        self.fragmentP2 = Int32(editable.fragmentP2)
        self.fragmentP3 = Int32(editable.fragmentP3)
        self.fragmentPr = UInt8(editable.fragmentPr)
        self.fragmentPg = UInt8(editable.fragmentPg)
        self.fragmentPb = UInt8(editable.fragmentPb)
        self.useOriginalMaterial = editable.useOriginalMaterial
    }
}

struct EditableFragmentUniformsA {
    var fragmentP1: Float = 1
    var fragmentP2: Float = 1
    var fragmentP3: Float = 1
    var fragmentPr: Float = 1
    var fragmentPg: Float = 1
    var fragmentPb: Float = 1
    var useOriginalMaterial: Bool = true
    
    func asStaticStruct() -> FragmentUniformsA {
        return FragmentUniformsA(from: self)
    }
}


/// There's no need to distinguish between the editable struct and the one passed to the gpu,
/// but this is the pattern in case we want to use values that aren't easily passed to UI elements,
/// like UInt8 with Sliders
struct FragmentUniformsB {
    var topThreshold: Float = 3
    var bottomThreshold: Float = 3
    var liveColor: simd_float3 = simd_float3(1, 1, 1)
    var deadColor: simd_float3 = simd_float3(0, 0, 0)
    var useOriginalMaterial: Bool = true
    
    init() {}
    
    init(from editable: EditableFragmentUniformsB) {
        self.topThreshold = editable.topThreshold
        self.bottomThreshold = editable.bottomThreshold
        self.liveColor = simd_float3(editable.liveColor.x, editable.liveColor.y, editable.liveColor.z)
        self.deadColor = simd_float3(editable.deadColor.x, editable.deadColor.y, editable.deadColor.z)
        self.useOriginalMaterial = editable.useOriginalMaterial
    }
}

struct EditableFragmentUniformsB {
    var topThreshold: Float = 3
    var bottomThreshold: Float = 1
    var liveColor = simd_float3(1, 1, 1)
    var deadColor = simd_float3(0, 0, 0)
    var useOriginalMaterial: Bool = true
    
    func asStaticStruct() -> FragmentUniformsB {
        return FragmentUniformsB(from: self)
    }
}
