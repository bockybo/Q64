import MetalKit

class ViewController: NSViewController {
	var renderer: Renderer!

	override func viewDidLoad() {
		super.viewDidLoad()
		
		let device = MTLCreateSystemDefaultDevice()!
		
		let view = RenderView(
			frame: CGRect(origin: .zero, size: CGSize(
				width:  Config.win_w,
				height: Config.win_h
			)),
			device: device
		)
		
		self.view = view
		self.renderer = Renderer(device: device, scene: view.ctrl.scene)
		self.renderer.mtkView(view, drawableSizeWillChange: view.frame.size)
		view.delegate = self.renderer
		
	}

}
