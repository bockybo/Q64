


struct Keybinds {
	typealias bind = ()->()
	
	var keydn: [Keystroke : bind] = [:]
	var keyup: [Keystroke : bind] = [:]
	var btndn: [Int : bind] = [:]
	var btnup: [Int : bind] = [:]
	var btndrag: [Int : bind] = [:]
	
}


enum Keystroke: UInt16, CaseIterable {
	
	case a = 0
	case s = 1
	case d = 2
	case f = 3
	case h = 4
	case g = 5
	case z = 6
	case x = 7
	case c = 8
	case v = 9
	case b = 11
	case q = 12
	case w = 13
	case e = 14
	case r = 15
	case y = 16
	case t = 17
	case o = 31
	case u = 32
	case i = 34
	case p = 35
	case k = 40
	case n = 45
	case m = 46
	
	case _1 = 18
	case _2 = 19
	case _3 = 20
	case _4 = 21
	case _6 = 22
	case _5 = 23
	case _9 = 25
	case _7 = 26
	case _8 = 28
	case _0 = 29
	
	case eql = 24
	case min = 27
	case ent = 36
	case tab = 48
	case del = 51
	case esc = 53
	case spc = 49
	
	case lt = 123
	case rt = 124
	case dn = 125
	case up = 126
	
}
