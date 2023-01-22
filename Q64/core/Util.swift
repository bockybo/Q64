

class util {
	
	class func sizeof<T>(_: T.Type) -> Int {
		return MemoryLayout<T>.stride
	}
	class func alignof<T>(_: T.Type) -> Int {
		return MemoryLayout<T>.alignment
	}
	
}
