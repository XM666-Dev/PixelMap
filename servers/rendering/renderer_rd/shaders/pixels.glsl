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
	uint pixel_index;
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

void main() {
	const uvec2 MAP_SIZE = imageSize(imgMap);
	const uvec2 CHUNK_SIZE = {CHUNK_WIDTH, CHUNK_HEIGHT};
	const uvec2 CHUNK_EXTENTS = uvec2(ceil(vec2(MAP_SIZE) / vec2(CHUNK_SIZE)));

	ivec2 cellCoords = cellPosition + ivec2(gl_GlobalInvocationID.xy);
	uvec2 cellCoordsLocal = uvec2(mod(cellCoords, CHUNK_SIZE));
	ivec2 mapCoords = ivec2(mod(cellCoords, MAP_SIZE));
	ivec2 chunkCoords = ivec2(floor(vec2(cellCoords) / vec2(CHUNK_SIZE)));
	uvec2 chunkCoordsLocal = uvec2(mod(chunkCoords, CHUNK_EXTENTS));
	uint chunkIndex = chunkCoordsLocal.y * CHUNK_EXTENTS.x + chunkCoordsLocal.x;
	Cell cell = chunks[chunkIndex].cells[cellCoordsLocal.y][cellCoordsLocal.x];
	Pixel pixel = pixels[cell.pixel_index];
	uint frameOffset = time % (pixel.uvSize.x / pixel.uvSize.y) * pixel.uvSize.y;
	ivec2 uv = ivec2(pixel.uvPosition + uvec2(frameOffset, 0) + cellCoords % pixel.uvSize.y);
	vec4 color = texelFetch(texPixelSet, uv, 0);
	imageStore(imgMap, mapCoords, color);
}
