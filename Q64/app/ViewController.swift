import MetalKit

class ViewController: NSViewController {
	var renderer: Renderer!
	var timer: Timer!

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
		
		view.colorPixelFormat			= cfg.color_fmt
		view.depthStencilPixelFormat	= cfg.depth_fmt
		view.preferredFramesPerSecond	= cfg.fps
		
		view.ctrl = Demo()
		self.timer = Timer(timeInterval: 1/cfg.tps, repeats: true) {
			_ in
			view.ctrl.tick()
		}
		
		self.renderer = Renderer()
		self.renderer.scene = view.ctrl.scene
		self.renderer.mtkView(view, drawableSizeWillChange: view.frame.size)
		view.delegate = self.renderer
		
	}
	
	override func viewWillAppear() {
		let win = self.view.window!
		win.acceptsMouseMovedEvents = true
	}
	
	override func viewDidAppear() {
		RunLoop.main.add(self.timer, forMode: .default)
	}
	override func viewWillDisappear() {
		self.timer.invalidate()
	}

}
