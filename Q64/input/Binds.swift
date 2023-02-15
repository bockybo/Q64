

struct Binds {
	
	typealias keybind = (
		dn: (()->())?,
		up: (()->())?)
	typealias btnbind = (
		dn: ((float2)->())?,
		up: ((float2)->())?)
	typealias ptrbind = (float2)->()
	
	
	var key: [Keystroke : keybind] = [:]
	var btn: [Int : btnbind] = [:]
	var ptr: [Int : ptrbind] = [:]
	
}
