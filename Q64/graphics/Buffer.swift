import MetalKit


class Buffer<T> {
	var mtl: MTLBuffer
	var num: Int = 0
	
	init(_ len: Int) {
		self.mtl = lib.device.makeBuffer(
			length: util.sizeof(T.self) * len,
			options: [.storageModeShared])!
	}
	init(_ arr: [T]) {
		self.mtl = lib.device.makeBuffer(
			bytes: arr,
			length: util.sizeof(T.self) * arr.count,
			options: [.storageModeShared])!
	}
	
	var full: Bool {return self.num * util.sizeof(T.self) >= self.mtl.length}
	var ptr: UnsafeMutablePointer<T> {
		return self.mtl.contents().assumingMemoryBound(to: T.self)
	}
	
	func add(_ t: T) {
		if self.full {return}
		self[self.num] = t
		self.num += 1
	}
	subscript(i: Int) -> T {
		get {return self.ptr[i]}
		set(t) {self.ptr[i] = t}
	}

}
