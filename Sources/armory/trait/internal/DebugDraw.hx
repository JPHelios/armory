package armory.trait.internal;

#if arm_debug

import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.VertexData;
import kha.graphics4.Usage;
import kha.graphics4.ConstantLocation;
import kha.graphics4.CompareMode;
import kha.graphics4.CullMode;
import iron.math.Vec4;
import iron.math.Mat4;

class DebugDraw {

	static var inst:DebugDraw = null;

	public var color = 0xffff0000;
	public var strength = 0.02;

	var vertexBuffer:VertexBuffer;
	var indexBuffer:IndexBuffer;
	var pipeline:PipelineState;

	var vp:Mat4;
	var vpID:ConstantLocation;

	var vbData:kha.arrays.Float32Array;
	var ibData:kha.arrays.Uint32Array;

	static inline var maxLines = 300;
	static inline var maxVertices = maxLines * 4;
	static inline var maxIndices = maxLines * 6;
	var lines = 0;

	function new() {
		inst = this;
		
		var structure = new VertexStructure();
		structure.add("pos", VertexData.Float3);
		structure.add("col", VertexData.Float3);
		pipeline = new PipelineState();
		pipeline.inputLayout = [structure];
		#if arm_deferred
		pipeline.fragmentShader = kha.Shaders.line_deferred_frag;
		#else
		pipeline.fragmentShader = kha.Shaders.line_frag;
		#end
		pipeline.vertexShader = kha.Shaders.line_vert;
		pipeline.depthWrite = true;
		pipeline.depthMode = CompareMode.Less;
		pipeline.cullMode = CullMode.None;
		pipeline.compile();
		vpID = pipeline.getConstantLocation("VP");
		vp = Mat4.identity();

		vertexBuffer = new VertexBuffer(maxVertices, structure, Usage.DynamicUsage);
		indexBuffer = new IndexBuffer(maxIndices, Usage.DynamicUsage);
	}

	static var g:kha.graphics4.Graphics;

	public static function notifyOnRender(f:DebugDraw->Void) {
		if (inst == null) inst = new DebugDraw();
		iron.RenderPath.notifyOnContext("mesh", function(g4:kha.graphics4.Graphics, i:Int, len:Int) {
			g = g4;
			if (i == 0) inst.begin();
			f(inst);
			if (i == len - 1) inst.end();
		});
	}

	public function bounds(t:iron.object.Transform) {
		// corner1-8.applymat4(t.world);
		var x = t.worldx();
		var y = t.worldy();
		var z = t.worldz();
		var dx = t.dim.x / 2;
		var dy = t.dim.y / 2;
		var dz = t.dim.z / 2;
		
		line(x - dx, y - dy, z - dz, x + dx, y - dy, z - dz);
		line(x - dx, y + dy, z - dz, x + dx, y + dy, z - dz);
		line(x - dx, y - dy, z + dz, x + dx, y - dy, z + dz);
		line(x - dx, y + dy, z + dz, x + dx, y + dy, z + dz);

		line(x - dx, y - dy, z - dz, x - dx, y + dy, z - dz);
		line(x - dx, y - dy, z + dz, x - dx, y + dy, z + dz);
		line(x + dx, y - dy, z - dz, x + dx, y + dy, z - dz);
		line(x + dx, y - dy, z + dz, x + dx, y + dy, z + dz);

		line(x - dx, y - dy, z - dz, x - dx, y - dy, z + dz);
		line(x - dx, y + dy, z - dz, x - dx, y + dy, z + dz);
		line(x + dx, y - dy, z - dz, x + dx, y - dy, z + dz);
		line(x + dx, y + dy, z - dz, x + dx, y + dy, z + dz);
	}

	public function line(x1:Float, y1:Float, z1:Float, x2:Float, y2:Float, z2:Float) {
		
		if (lines >= maxLines) { end(); begin(); }

		var camera = iron.Scene.active.camera;
		var l = camera.right();
		l.add(camera.up());

		var i = lines * 24; // 4 * 6 (structure len)
		vbData.set(i + 0, x1);
		vbData.set(i + 1, y1);
		vbData.set(i + 2, z1);
		vbData.set(i + 3, 1.0);
		vbData.set(i + 4, 0.0);
		vbData.set(i + 5, 0.0);

		vbData.set(i + 6, x2);
		vbData.set(i + 7, y2);
		vbData.set(i + 8, z2);
		vbData.set(i + 9, 1.0);
		vbData.set(i + 10, 0.0);
		vbData.set(i + 11, 0.0);

		vbData.set(i + 12, x2 + strength * l.x);
		vbData.set(i + 13, y2 + strength * l.y);
		vbData.set(i + 14, z2 + strength * l.z);
		vbData.set(i + 15, 1.0);
		vbData.set(i + 16, 0.0);
		vbData.set(i + 17, 0.0);

		vbData.set(i + 18, x1 + strength * l.x);
		vbData.set(i + 19, y1 + strength * l.y);
		vbData.set(i + 20, z1 + strength * l.z);
		vbData.set(i + 21, 1.0);
		vbData.set(i + 22, 0.0);
		vbData.set(i + 23, 0.0);

		i = lines * 6;
		ibData[i + 0] = lines * 4 + 0;
		ibData[i + 1] = lines * 4 + 1;
		ibData[i + 2] = lines * 4 + 2;
		ibData[i + 3] = lines * 4 + 2;
		ibData[i + 4] = lines * 4 + 3;
		ibData[i + 5] = lines * 4 + 0;

		lines++;
	}

	function begin() {
		lines = 0;
		vbData = vertexBuffer.lock();
		ibData = indexBuffer.lock();
	}

	function end() {
		vertexBuffer.unlock();
		indexBuffer.unlock();
		
		g.setVertexBuffer(vertexBuffer);
		g.setIndexBuffer(indexBuffer);
		g.setPipeline(pipeline);
		var camera = iron.Scene.active.camera;
		vp.setFrom(camera.V);
		vp.multmat2(camera.P);
		g.setMatrix(vpID, vp.self);
		g.drawIndexedVertices(0, lines * 6);
	}
}

#end
