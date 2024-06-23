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

struct FragmentUniformsB {
    var fragmentX: UInt8 = 1
    var useOriginalMaterial: Bool = true
    
    init() {}
    
    init(from editable: EditableFragmentUniformsB) {
        self.fragmentX = UInt8(editable.fragmentX)
        self.useOriginalMaterial = editable.useOriginalMaterial
    }
}

struct EditableFragmentUniformsB {
    var fragmentX: Float = 1
    var useOriginalMaterial: Bool = true
    
    func asStaticStruct() -> FragmentUniformsB {
        return FragmentUniformsB(from: self)
    }
}
