import SwiftUI
import MetalKit

struct MetalView: NSViewControllerRepresentable {
    let device: MTLDevice
    let metalView: MTKView
    
    func makeNSViewController(context: Context) -> some NSViewController {
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.device = device
        return MetalViewController(metalView: metalView)
    }
    
    func updateNSViewController(_ nsViewController: NSViewControllerType, context: Context) {
    }
}

class MetalViewController: NSViewController {
    var metalView: MTKView
    
    init(metalView: MTKView) {
        self.metalView = metalView
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(metalView)
        metalView.frame = view.bounds
        metalView.autoresizingMask = [.width, .height]
    }
}
