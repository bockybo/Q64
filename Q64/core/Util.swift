import MetalKit


class util {
	
	class func sizeof<T>(_: T.Type) -> Int {
		return MemoryLayout<T>.stride
	}
	class func sizeof<T>(_: T) -> Int {
		return util.sizeof(T.self)
	}
	
	class func url(_ path: String?, ext: String? = nil) -> URL? {
		return Bundle.main.url(forResource: path, withExtension: ext)
	}
	
}
