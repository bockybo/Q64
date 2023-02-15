import MetalKit


class util {
	
	class func sizeof<T>(_: T.Type) -> Int {
		return MemoryLayout<T>.stride
	}
	class func sizeof<T>(_: T) -> Int {
		return util.sizeof(T.self)
	}
//	class func offsetof<T>(_: T.Type, _ key: PartialKeyPath<T>) -> Int {
//		return MemoryLayout<T>.offset(of: key)!
//	}
//	class func offsetof<T>(_: T, _ key: PartialKeyPath<T>) -> Int {
//		return util.offsetof(T.self, key)
//	}

	class func url(_ path: String?, ext: String? = nil) -> URL? {
		return Bundle.main.url(forResource: path, withExtension: ext)
	}
	
}
