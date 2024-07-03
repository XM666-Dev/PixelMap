#[compute]
#version 460

layout(local_size_x = 16, local_size_y = 16) in;

struct SpriteInfo {
	uvec2 uvOrigin;
	uvec2 uvSize;
	uint frames;
};//alignment = 6 bytes

struct Tile {
	uint spriteIndex;
	//uvec4 color;
	//uvec2 offset;
};

struct Chunk {
	Tile tiles[256];
};
 
//const
layout(binding = 0) uniform usampler2D tileSet;
layout(binding = 1, std430) restrict readonly buffer SpriteSheetInfo {
	SpriteInfo spriteInfos[];
};

//input
layout(binding = 2, std140) uniform MapData {
	ivec2 cellOrigin;
};
layout(binding = 3, std430) restrict readonly buffer ChunkData {
	Chunk chunks[];
};

//output
layout(binding = 4, rgba8ui) restrict writeonly uniform uimage2D mapImage;

void main() {
	ivec2 drawCoord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 cellCoord = cellOrigin + drawCoord;

	uint chunkIndex = gl_WorkGroupID.y * gl_NumWorkGroups.x + gl_WorkGroupID.x;
	Chunk chunk = chunks[chunkIndex];
	Tile tile = chunk.tiles[gl_LocalInvocationIndex];
	uint spriteIndex = tile.spriteIndex;
	SpriteInfo spriteInfo = spriteInfos[spriteIndex];
	uvec2 uvOrigin = spriteInfo.uvOrigin;
	uvec2 uvSize = spriteInfo.uvSize;
	ivec2 uv = ivec2(uvOrigin + cellCoord % uvSize);
	uvec4 color = texelFetch(tileSet, uv, 0);
	imageStore(mapImage, drawCoord, color);
}