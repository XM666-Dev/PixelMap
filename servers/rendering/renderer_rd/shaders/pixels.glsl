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
	uvec2 cellCoordsLocal = cellCoords % CHUNK_SIZE;
	ivec2 mapCoords = cellCoords % ivec2(MAP_SIZE);
	ivec2 chunkCoords = cellCoords / ivec2(CHUNK_SIZE);
	uvec2 chunkCoordsLocal = chunkCoords % CHUNK_EXTENTS;
	uint chunkIndex = chunkCoordsLocal.y * CHUNK_EXTENTS.x + chunkCoordsLocal.x;
	Cell cell = chunks[chunkIndex].cells[cellCoordsLocal.y][cellCoordsLocal.x];
	Pixel pixel = pixels[cell.pixel_index];
	uint frameOffset = time % (pixel.uvSize.x / pixel.uvSize.y) * pixel.uvSize.y;
	ivec2 uv = ivec2(pixel.uvPosition + uvec2(frameOffset, 0) + cellCoords % pixel.uvSize.y);
	vec4 color = texelFetch(texPixelSet, uv, 0);
	imageStore(imgMap, mapCoords, color);

	//ivec2 coords = gl_GlobalInvocationID.xy;
	//ivec2 mapSize = textureSize(imgMap);
	//ivec2 offset = cellPosition % mapSize;
	//ivec2 cellCoords = cellPosition + coords.x;
	//if (coords.x < offset.x) {
	//	cellCoords.x += cellPosition.x - offset.x + mapSize.x;
	//}
	// - offset + coords
	//gl_GlobalInvocationID - 绘制的xy
	//gl_NumWorkGroups * gl_WorkGroupSize - 绘制的cell大小
	//cellPosition - 绘制的cell世界起始位置
	//cellCoords = 
	//cellCoords % textureSize(imgMap) == coords
	//(cellCoords - coords) % textureSize(imgMap) == {0, 0}
	//(cellCoords - coords) - (cellCoords - coords) / size * size
	//cellCoords  == cellPosition / mapSize * mapSize + coords

	//ivec2 cellCoords = cellPosition + coords;
	//ivec2 chunkCoords = cellCoords / CHUNK_SIZE;
	//ivec2 chunkCoordsLocal = chunkCoords % chunkExtents;

	//ivec2 chunkCoords = ivec2(gl_GlobalInvocationID.xy / CHUNK_SIZE) + renderPosition;
	//uvec2 chunkCoordsLocal = uvec2(chunkCoords % renderExtents);
	//uint chunkIndex = chunkCoordsLocal.y * renderExtents.x + chunkCoordsLocal.x;
	//ivec2 cellCoords = ivec2(renderPosition * CHUNK_SIZE + gl_GlobalInvocationID.xy);
	//ivec2 coords = ivec2(chunkCoordsLocal * CHUNK_SIZE + gl_LocalInvocationID.xy);
	//Cell cell = chunks[chunkIndex].cells[gl_LocalInvocationID.y][gl_LocalInvocationID.x];
	//Pixel pixel = pixels[cell.pixel_index];
	//uint frameOffset = time % (pixel.uvSize.x / pixel.uvSize.y) * pixel.uvSize.y;
	//ivec2 uv = ivec2(pixel.uvPosition + uvec2(frameOffset, 0) + cellCoords % pixel.uvSize.y);
	//vec4 color = texelFetch(texPixelSet, uv, 0);
	//imageStore(imgMap, coords, color);
}
