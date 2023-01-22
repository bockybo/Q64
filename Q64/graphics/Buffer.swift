import MetalKit


class Buffer<T>: Renderable {
	var buf: MTLBuffer
	var num: Int = 0
	
	let mode: Mode
	let arg: Int
	enum Mode {
		case vtx
		case frg
	}
	
	init(_ device: MTLDevice, mode: Mode, arg: Int, cap: Int) {
		self.mode = mode
		self.arg = arg
		self.buf = device.makeBuffer(
			length: util.sizeof(T.self) * cap,
			options: [.storageModeShared]
		)!
	}
	convenience init(_ device: MTLDevice, mode: Mode, arg: Int, _ arr: [T]) {
		self.init(device, mode: mode, arg: arg, cap: arr.count)
		for t in arr {self.add(t)}
	}
	
	var full: Bool {return self.buf.length <= self.num * util.sizeof(T.self)}
	var ptr: UnsafeMutablePointer<T> {
		return self.buf.contents().assumingMemoryBound(to: T.self)
	}
	
	func add(_ t: T) {
		if self.full {return}
		self.ptr[self.num] = t
		self.num += 1
	}
	
	func render(enc: MTLRenderCommandEncoder) {
		if self.mode == .vtx {
			enc.setVertexBuffer(self.buf, offset: 0, index: self.arg)
			enc.setVertexBytes(&self.num, length: util.sizeof(Int.self), index: self.arg + 1)
		} else {
			enc.setFragmentBuffer(self.buf, offset: 0, index: self.arg)
			enc.setFragmentBytes(&self.num, length: util.sizeof(Int.self), index: self.arg + 1)
		}
	}
	
}
