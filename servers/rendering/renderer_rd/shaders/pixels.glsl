#[compute]
#version 460

layout(local_size_x = 32, local_size_y = 32) in;

const uvec2 CHUNK_SIZE = {32, 32};

struct Pixel {
	uvec2 uvPosition;
	uvec2 uvSize;
};

struct Cell {
	uint pixelIndex;
};

struct Chunk {
	Cell cells[CHUNK_SIZE.y][CHUNK_SIZE.x];
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

int bitAbs(int x) {
	return x < 0 ? ~x : x;
}

int inv(int a, int b) {
	return b - a - 1;
}

int posDiv(int a, int b) {
	if ((a < 0) != (b < 0))
		a -= b - 1;
	return a / b;
}
ivec2 posDiv(ivec2 a, ivec2 b) {
	return ivec2(posDiv(a.x, b.x), posDiv(a.y, b.y));
}

int posDivCeil(int a, int b) {
	if ((a < 0) == (b < 0))
		a += b - 1;
	return a / b;
}
ivec2 posDivCeil(ivec2 a, ivec2 b) {
	return ivec2(posDivCeil(a.x, b.x), posDivCeil(a.y, b.y));
}

int posMod(int a, int b) {
	int num = bitAbs(a) % abs(b);
	if ((a < 0) != (b < 0))
		num = inv(num, b);
	return num;
}
ivec2 posMod(ivec2 a, ivec2 b) {
	return ivec2(posMod(a.x, b.x), posMod(a.y, b.y));
}

uint hash(ivec2 a) {
    uint seed = uint(a.x) * 1664525u + uint(a.y) * 1013904223u;
    seed ^= seed >> 16;
    seed *= 2246822519u;
    seed ^= seed >> 13;
    seed *= 3266489917u;
    seed ^= seed >> 16;
    return seed;
}
ivec2 cellTransform(ivec2 coord, ivec2 size, int bits) {
	ivec2 uv = posMod(coord, size);
	uint h = hash(posDiv(coord, size)) & bits;
	if ((h & 1 << 0) != 0)
		uv.x = inv(uv.x, size.x);
	if ((h & 1 << 1) != 0)
		uv.y = inv(uv.y, size.y);
	if ((h & 1 << 2) != 0)
		uv = uv.yx;
	return uv;
}

void main() {
	uvec2 mapSize = imageSize(imgMap);
	if (any(greaterThanEqual(gl_GlobalInvocationID.xy, mapSize))) return;
	uvec2 chunkExtents = posDivCeil(ivec2(mapSize), ivec2(CHUNK_SIZE)) + 1;
	ivec2 cellCoord = cellPosition + ivec2(gl_GlobalInvocationID.xy);
	uvec2 cellCoordLocal = posMod(cellCoord, ivec2(CHUNK_SIZE));
	ivec2 chunkCoord = posDiv(cellCoord, ivec2(CHUNK_SIZE));
	uvec2 chunkCoordLocal = posMod(chunkCoord, ivec2(chunkExtents));
	uint chunkIndex = chunkCoordLocal.y * chunkExtents.x + chunkCoordLocal.x;
	Cell cell = chunks[chunkIndex].cells[cellCoordLocal.y][cellCoordLocal.x];
	Pixel pixel = pixels[cell.pixelIndex];
	ivec2 uv = ivec2(pixel.uvPosition);
	uv.x += int(time % (pixel.uvSize.x / pixel.uvSize.y) * pixel.uvSize.y);
	uv += cellTransform(cellCoord, ivec2(pixel.uvSize.y), 7);
	vec4 color = texelFetch(texPixelSet, uv, 0);
	ivec2 mapCoord = posMod(cellCoord, ivec2(mapSize));
	imageStore(imgMap, mapCoord, color);
}
