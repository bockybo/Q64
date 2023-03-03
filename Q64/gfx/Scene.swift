import MetalKit


class Scene {
	var models: [String : Model]
	var lights: [Light] = [Light()]
	
	init(_ models: [String : Model] = [:]) {
		self.models = models
	}
	
	var cam = Camera()
	var sun: Light {
		get {return self.lights[0]}
		set(light) {self.lights[0] = light}
	}
	
	var mdls: [Scene.MDL] = []
	var lgts: [Scene.LGT] {return self.lights.map {$0.lgt}}
	
	subscript(name: String) -> Model? {
		get {return self.models[name]}
		set(model) {self.models[name] = model}
	}
	var nid: Int {
		return self.models.values.reduce(0) {$0 + $1.nid}
	}
	var ids: Range<Int> {return 0..<self.nid}
	
	struct SCN {
		var ctm: float4x4 = .idt
		var inv: float4x4 = .idt
		var pos: float3 = float3(0)
	}
	struct LGT {
		var ctm: float4x4 = .idt
		var hue: float3 = float3(1)
		var pos: float3 = float3(0)
		var dir: float3 = float3(0)
		var rad: float = float(0)
		var fov: float = float(0)
	}
	struct MDL {
		init(_ ctm: float4x4 = .idt) {
			self.ctm = ctm
		}
		var ctm: float4x4 = .idt {didSet {
			let inv = self.ctm.inverse.transpose
			self.inv[0] = inv[0].xyz
			self.inv[1] = inv[1].xyz
			self.inv[2] = inv[2].xyz
		}}
		var inv: float3x3 = .idt
	}
	
}

struct Model {
	var iid: Int
	var nid: Int
	var meshes: [MTKMesh]
	var props: Props
	
	init(iid: Int, nid: Int = 1, meshes: [MTKMesh] = [], props: Props = Props()) {
		self.iid = iid
		self.nid = nid
		self.meshes = meshes
		self.props = props
	}
	init(iid: Int, nid: Int = 1, mesh: MTKMesh, props: Props = Props()) {
		self.init(iid: iid, nid: nid, meshes: [mesh], props: props)
	}
	
	var ids: Range<Int> {return self.iid..<self.iid+self.nid}
	
	struct Props {
		var alb: MTLTexture? = nil
		var nml: MTLTexture? = nil
		var rgh: MTLTexture? = nil
		var mtl: MTLTexture? = nil
		var  ao: MTLTexture? = nil
		var emm: MTLTexture? = nil
	}
	
}

struct Light {
	var hue = normalize(float3(1))
	
	var src = float3(0)
	var dst = float3(0)
	
	var dir: float3 {
		get {return normalize(self.dst - self.src)}
		set(dir) {
			self.dst = self.src + dir * length(self.dst - self.src)
		}
	}
	
	var rad: float = 0
	var fov: float = 0
	var is_directional:	Bool {return self.rad == 0}
	var is_positional:	Bool {return !self.is_directional}
	var is_point:		Bool {return self.is_positional && self.fov == 0}
	var is_spot:		Bool {return self.is_positional && self.fov != 0}
	
	var p0 = float3(-100, -100, 0.1)
	var p1 = float3(+100, +100, 1e4)
	
	var proj: float4x4 {
		if self.is_directional {
			return .ortho(
				p0: self.p0,
				p1: self.p1)
		} else if self.is_spot {
			return .persp(
				fov: self.fov * 2,
				asp: 1,
				z0: self.p0.z,
				z1: self.rad * 2)
		} else {
			return .idt // TODO: what's the point light matrix??
		}
		
	}
	
	var view: float4x4 {return .look(dst: self.dst, src: self.src)}
	var ctm: float4x4 {return self.proj * self.view.inverse}
	var lgt: Scene.LGT {
		return .init(
			ctm: self.ctm,
			hue: self.hue,
			pos: self.src,
			dir: self.dir,
			rad: self.rad,
			fov: self.fov
		)
	}
	
}

struct Camera {
	
	var res: uint2 = uint2(0)
	var fov: float = 65 * .pi/180
	var z0: float = 0.1
	var z1: float = 1e3
	
	var asp: float {return float(self.res.x)/float(self.res.y)}
	var proj: float4x4 {
		return .persp(
			fov: self.fov,
			asp: self.asp,
			z0: self.z0,
			z1: self.z1
		)
	}
	
	var pos = float3(0)
	var rot = float3(0)
	var mag = float3(1)
	var view: float4x4 {
		var view = float4x4.pos(self.pos) * .mag(self.mag)
		view *= .zrot(self.rot.z)
		view *= .yrot(self.rot.y)
		view *= .xrot(self.rot.x)
		return view
	}
	
	var ctm: float4x4 {return self.proj * self.view.inverse}
	
	var scn: Scene.SCN {
		let ctm = self.ctm
		var inv = ctm.inverse
		inv *= .pos(float3(-1, 1, 0))
		inv *= .mag(float3(float2(2, -2) / float2(self.res), 1))
		return .init(
			ctm: ctm,
			inv: inv,
			pos: self.pos
		)
	}
	
}
