#[compute]
#version 460

const uvec2 QUADRANT_SIZE = {32, 32};

layout(local_size_x = QUADRANT_SIZE.x, local_size_y = QUADRANT_SIZE.y) in;

struct Pixel {
	uvec2 uvPosition;
	uvec2 uvSize;
	uint frames;
};

struct Cell {
	uint pixel_id;
	//vec4 color;
};

struct Quadrant {
	Cell cells[QUADRANT_SIZE.y][QUADRANT_SIZE.x];
};

layout(binding = 0) uniform sampler2D texPixelSet;
layout(binding = 1, std430) restrict readonly buffer BufPixelSet {
	Pixel pixels[];
};

layout(binding = 2) restrict writeonly uniform image2D imgMap;
layout(binding = 3, std140) uniform BufMap {
	uvec2 quadrantExtents;
	ivec2 quadrantPosition;
	uint time;
};

layout(binding = 4, std430) restrict readonly buffer BufQuadrants {
	Quadrant quadrants[];
};

void main() {
	ivec2 quadrantCoords = quadrantPosition + ivec2(gl_WorkGroupID.xy);
	uvec2 quadrantCoordsRender = uvec2(mod(quadrantCoords, quadrantExtents));
	uint quadrantIndexRender = quadrantCoordsRender.y * quadrantExtents.x + quadrantCoordsRender.x;
	Quadrant quadrant = quadrants[quadrantIndexRender];
	ivec2 cellCoords = quadrantCoords * ivec2(QUADRANT_SIZE) + ivec2(gl_LocalInvocationID.xy);
	ivec2 cellCoordsRender = ivec2(mod(cellCoords, quadrantExtents * QUADRANT_SIZE));
	Cell cell = quadrant.cells[gl_LocalInvocationID.y][gl_LocalInvocationID.x];
	Pixel pixel = pixels[cell.pixel_id];
	pixel = pixels[cell.pixel_id + time % pixel.frames];
	ivec2 uv = ivec2(pixel.uvPosition + cellCoords % pixel.uvSize);
	vec4 color = texelFetch(texPixelSet, uv, 0);
	imageStore(imgMap, cellCoordsRender, color);
}