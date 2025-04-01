#[compute]
#version 460

layout(constant_id = 0) const uint CHUNK_WIDTH = 32;
layout(constant_id = 1) const uint CHUNK_HEIGHT = 32;
layout(local_size_x = 32, local_size_y = 32) in;

struct Pixel {
	uvec2 uvPosition;
	uvec2 uvSize;
};

struct Cell {
	uint pixelIndex;
};

struct Chunk {
	Cell cells[CHUNK_HEIGHT][CHUNK_WIDTH];
};

layout(binding = 0) uniform sampler2D texPixelSet;
layout(binding = 1, std430) restrict readonly buffer BufPixelSet {
	Pixel pixels[];
};

layout(binding = 2) restrict writeonly uniform image2D imgMap;
layout(binding = 3, std140) uniform BufMap {
	ivec2 cellPosition;
	uint time;
};

layout(binding = 4, std430) restrict readonly buffer BufChunks {
	Chunk chunks[];
};

int posdiv(int a, int b) {
	if ((a < 0) != (b < 0))
		a -= b - 1;
	return a / b;
}
ivec2 posdiv(ivec2 a, ivec2 b) {
	return ivec2(posdiv(a.x, b.x), posdiv(a.y, b.y));
}

int posdivceil(int a, int b) {
	if ((a < 0) == (b < 0))
		a += b - 1;
	return a / b;
}
ivec2 posdivceil(ivec2 a, ivec2 b) {
	return ivec2(posdivceil(a.x, b.x), posdivceil(a.y, b.y));
}

int posmod(int a, int b) {
	int num = abs(a) % abs(b);
	if ((a < 0) != (b < 0) && num > 0)
		num = b - num;
	return num;
	//if (a < 0) {
	//	int num = -a % b;
	//	return b * int(num > 0) - num;
	//}
	//return a % b;
	//return a - b * posdiv(a, b);
}
ivec2 posmod(ivec2 a, ivec2 b) {
	return ivec2(posmod(a.x, b.x), posmod(a.y, b.y));
}

void main() {
	//int a = -31; int b = 31;
	//int c = 0;
	////-1 % 4 == 3
	////-2 % 4 == 2
	////-3 % 4 == 1
	////-4 % 4 == 0
	////-23 % 31 == 12
	////-22 % 31 == 13
	////-31 % 31 == 4
	////4294967265 % 31 == 4
	//// && posmod(a, b) == 8
	//if (posmod(a, b) == c) // is true
	////if (4294967265 == a)
	////if (-3 % 4 > 0) // is false
	//	{imageStore(imgMap, ivec2(gl_GlobalInvocationID.xy), vec4(1.0,0.0,0.0,1.0)); return;} else {return;}
	const uvec2 MAP_SIZE = imageSize(imgMap);
	const uvec2 CHUNK_SIZE = {CHUNK_WIDTH, CHUNK_HEIGHT};
	const uvec2 CHUNK_EXTENTS = posdivceil(ivec2(MAP_SIZE), ivec2(CHUNK_SIZE)) + 1;

	ivec2 cellCoords = cellPosition + ivec2(gl_GlobalInvocationID.xy);
	uvec2 cellCoordsLocal = posmod(cellCoords, ivec2(CHUNK_SIZE));
	ivec2 mapCoords = posmod(cellCoords, ivec2(MAP_SIZE));
	//if (mapCoords.y != 0){/*imageStore(imgMap, mapCoords, vec4(1.0,0.0,0.0,1.0)); return;*/}else{/*imageStore(imgMap, mapCoords, vec4(0.0,0.0,1.0,1.0)); return;*/}
	//if (MAP_SIZE == uvec2(961, 510)) {imageStore(imgMap, mapCoords, vec4(1.0,0.0,0.0,1.0)); return;} true
	//if (gl_GlobalInvocationID.x > MAP_SIZE.x || gl_GlobalInvocationID.y > MAP_SIZE.y) {imageStore(imgMap, ivec2(MAP_SIZE), vec4(1.0,0.0,0.0,1.0)); return;}
	ivec2 chunkCoords = posdiv(cellCoords, ivec2(CHUNK_SIZE));
	uvec2 chunkCoordsLocal = posmod(chunkCoords, ivec2(CHUNK_EXTENTS));
	uint chunkIndex = chunkCoordsLocal.y * CHUNK_EXTENTS.x + chunkCoordsLocal.x;
	Cell cell = chunks[chunkIndex].cells[cellCoordsLocal.y][cellCoordsLocal.x];
	Pixel pixel = pixels[cell.pixelIndex];
	uint frameOffset = time % (pixel.uvSize.x / pixel.uvSize.y) * pixel.uvSize.y;
	ivec2 uv = ivec2(pixel.uvPosition + uvec2(frameOffset, 0) + cellCoords % pixel.uvSize.y);
	vec4 color = texelFetch(texPixelSet, uv, 0);
	//if (mapCoords.y == 0 && chunkCoords.y== 0 && chunkCoordsLocal.y==0 && cellCoords.y==0 ) {color = vec4((double(time%100) / 100) ,0.0,0.0,1.0);}//Bug: 非零正数边界处单元格永不渲染
	//if (cellCoords.y==510 &&MAP_SIZE==uvec2(961, 510)) { mapCoords.y = 0;/*imageStore(imgMap, ivec2(0,0), vec4((double(time%100) / 100) ,0.0,0.0,1.0));return;*/ }//Bug: 非零正数边界处单元格永不渲染
	//渲染位置应该在510处出错
	imageStore(imgMap, mapCoords, color);
}
