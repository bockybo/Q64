import MetalKit

class ViewController: NSViewController {
	var renderer: Renderer!

	override func viewDidLoad() {
		super.viewDidLoad()
		let view = RenderView(
			frame: CGRect(origin: .zero, size: CGSize(
				width:  cfg.win_w,
				height: cfg.win_h
			)),
			device: lib.device
		)
		self.view = view
		self.renderer = Renderer(view)
	}
	
	override func viewWillAppear() {
		let win = self.view.window!
		win.acceptsMouseMovedEvents = true
	}

}
