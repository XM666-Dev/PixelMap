#[compute]
#version 460

const uvec2 CHUNK_SIZE = uvec2(16, 16);

layout(local_size_x = CHUNK_SIZE.x, local_size_y = CHUNK_SIZE.y) in;

struct TileConst {
	uvec2 uvCoords;
	uvec2 uvSize;
	uint frames;
};//alignment = 6 bytes

struct Tile {
	uint type;
	//uvec4 color;
};

struct Chunk {
	Tile tiles[CHUNK_SIZE.y][CHUNK_SIZE.x];
};
 
//const
layout(binding = 0) uniform sampler2D tileSet;
layout(binding = 1, std430) restrict readonly buffer TileConsts {
	TileConst tileConsts[];
};

//input
layout(binding = 2, std140) uniform MapData {
	ivec2 chunkCoords;
	uint time;
};
layout(binding = 3, std430) restrict readonly buffer Chunks {
	Chunk chunks[];
};

//output
layout(binding = 4) restrict writeonly uniform image2D mapImage;

void main() {
	ivec2 drawCoords = ivec2(gl_GlobalInvocationID.xy);
	ivec2 cellCoords = chunkCoords * ivec2(CHUNK_SIZE) + drawCoords;
	uint chunkIndex = gl_WorkGroupID.y * gl_NumWorkGroups.x + gl_WorkGroupID.x;
	Chunk chunk = chunks[chunkIndex];
	Tile tile = chunk.tiles[gl_LocalInvocationID.y][gl_LocalInvocationID.x];
	TileConst tileConst = tileConsts[tile.type];
	tileConst = tileConsts[tile.type + time % tileConst.frames];
	ivec2 uv = ivec2(tileConst.uvCoords + cellCoords % tileConst.uvSize);
	vec4 color = texelFetch(tileSet, uv, 0);
	imageStore(mapImage, drawCoords, color);
}