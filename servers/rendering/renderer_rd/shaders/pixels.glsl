#[compute]
#version 460

const uvec2 CHUNK_SIZE = {32, 32};

layout(local_size_x = CHUNK_SIZE.x, local_size_y = CHUNK_SIZE.y) in;

struct Pixel {
	uvec2 uvPosition;
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

layout(binding = 0) uniform sampler2D texPixelSet;
layout(binding = 1, std430) restrict readonly buffer BufPixelSet {
	Pixel pixels[];
};

layout(binding = 2) restrict writeonly uniform image2D imgMap;
layout(binding = 3, std140) uniform BufMap {
	uvec2 renderExtents;
	ivec2 renderPosition;
	uint time;
};

layout(binding = 4, std430) restrict readonly buffer BufChunks {
	Chunk chunks[];
};

void main() {
	ivec2 chunkCoords = ivec2(renderPosition + gl_WorkGroupID.xy);
	uvec2 renderCoords = uvec2(mod(chunkCoords, renderExtents));
	uint renderIndex = renderCoords.y * renderExtents.x + renderCoords.x;
	ivec2 cellCoords = ivec2(chunkCoords * CHUNK_SIZE + gl_LocalInvocationID.xy);
	ivec2 coords = ivec2(renderCoords * CHUNK_SIZE + gl_LocalInvocationID.xy);
	Cell cell = chunks[renderIndex].cells[gl_LocalInvocationID.y][gl_LocalInvocationID.x];
	Pixel pixel = pixels[cell.pixel_id + time % pixels[cell.pixel_id].frames];
	ivec2 uv = ivec2(pixel.uvPosition + cellCoords % pixel.uvSize);
	vec4 color = texelFetch(texPixelSet, uv, 0);
	imageStore(imgMap, coords, color);
}
