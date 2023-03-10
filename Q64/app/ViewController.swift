import MetalKit


class ViewController: NSViewController {
	var drawview: MTKView!
	var ctrlview: CtrlView!
	var renderer: Renderer!
	var scene: Scene!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.scene = Scene(materials: cfg.meta.materials)
		self.ctrlview = CtrlView()
		self.ctrlview.ctrl = cfg.meta.init(scene: self.scene)
		
		self.drawview = MTKView(frame: self.view.frame, device: lib.device)
		self.renderer = Renderer(self.drawview, scene: self.scene)
		self.drawview.delegate = self.renderer
		self.drawview.preferredFramesPerSecond = cfg.fps
		self.drawview.colorPixelFormat = Renderer.fmt_color
		self.drawview.depthStencilPixelFormat = Renderer.fmt_depth
		if #available(macOS 13.0, *) {
			self.drawview.depthStencilStorageMode = .memoryless
		}
		
		self.view.addSubview(self.ctrlview)
		self.view.addSubview(self.drawview)
		self.view.frame.size = CGSize(width: cfg.win_w, height: cfg.win_h)
		
		self.drawview.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			self.drawview.topAnchor.constraint(equalTo: self.view.topAnchor),
			self.drawview.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
			self.drawview.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
			self.drawview.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
		])
		
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		let win = self.ctrlview.window!
		win.acceptsMouseMovedEvents = true
		self.ctrlview.start(tps: cfg.tps, scene: self.scene)
	}
	override func viewWillDisappear() {
		super.viewWillDisappear()
		self.ctrlview.stop()
	}
	
}
