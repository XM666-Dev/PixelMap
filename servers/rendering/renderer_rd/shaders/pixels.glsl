#[compute]
#version 460

const uvec2 CHUNK_SIZE = {32, 32};

layout(local_size_x = CHUNK_SIZE.x, local_size_y = CHUNK_SIZE.y) in;

struct Pixel {
	uvec2 uvCoords;
	uvec2 uvSize;
	uint frames;
};

struct Cell {
	uint pixel_id;
	//vec4 color;
};

struct Chunk {
	Cell cells[CHUNK_SIZE.y][CHUNK_SIZE.x];
};
 
int floor_modulo(int x, int y) {
	int i = x % y;
	return i < 0 ? i + y : i;
}

ivec2 floor_modulo(ivec2 x, ivec2 y) {
	return ivec2(floor_modulo(x.x, y.x), floor_modulo(x.y, y.y));
}

layout(binding = 0) uniform sampler2D texPixelSet;
layout(binding = 1, std430) restrict readonly buffer BufPixelSet {
	Pixel pixels[];
};

layout(binding = 2) restrict writeonly uniform image2D imgMap;
layout(binding = 3, std140) uniform BufMap {
	ivec2 chunkCoords;
	uvec2 chunkExtents;
	uint time;
};

layout(binding = 4, std430) restrict readonly buffer BufChunks {
	Chunk chunks[];
};

void main() {
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	ivec2 cellCoords = chunkCoords * ivec2(CHUNK_SIZE) + coords;
	uint chunkIndex = gl_WorkGroupID.y * gl_NumWorkGroups.x + gl_WorkGroupID.x;
	Chunk chunk = chunks[chunkIndex];
	Cell cell = chunk.cells[gl_LocalInvocationID.y][gl_LocalInvocationID.x];
	Pixel pixel = pixels[cell.pixel_id];
	pixel = pixels[cell.pixel_id + time % pixel.frames];
	ivec2 uv = ivec2(pixel.uvCoords) + floor_modulo(cellCoords, ivec2(pixel.uvSize));
	vec4 color = texelFetch(texPixelSet, uv, 0);
	imageStore(imgMap, coords, color);
}