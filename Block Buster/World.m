//
//  World.m
//  Block Buster
//
//  Created by Joao Santos on 07/08/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;
@import GameplayKit;
#import "World.h"
#import "Block.h"
#import "ActionQueue.h"

#define WORLD_SIZE 3

static Block __weak *worldBlocks[WORLD_SIZE][WORLD_SIZE][WORLD_SIZE];
static SCNNode *worldNode;
static SCNVector3 worldMin, worldMax;

@interface World()

+ (void)updateTransform;
+ (void)recomputeBoundingBox;
+ (Block *)randomCentralBlockFromBlocks:(NSArray<Block *> *)blocks;
+ (NSMutableSet<Block *> *)blocksConnectedToBlock:(Block *)block;
+ (void)blocksConnectedToPosition:(simd_float3)position notInSet:(NSMutableSet<Block *> *)set;
+ (void)connectScatteredBlocks:(NSMutableSet<Block *> *)scatteredBlocks toGatheredBlocks:(NSMutableSet<Block *> *)gatheredBlocks;
+ (void)moveScatteredBlock:(Block *)scatteredBlock towardsGatheredBlock:(Block *)gatheredBlock;

@end

@implementation World

+ (void)worldInNode:(SCNNode *)node
{
    worldNode = node;
}

+ (void)addBlockWithColor:(UIColor *)color
{
    NSMutableArray<NSValue *> *availablePositions = [NSMutableArray arrayWithCapacity:WORLD_SIZE * WORLD_SIZE * WORLD_SIZE];
    for (NSUInteger x = 0; x < WORLD_SIZE; ++ x) {
        for (NSUInteger y = 0; y < WORLD_SIZE; ++ y) {
            for (NSUInteger z = 0; z < WORLD_SIZE; ++ z) {
                if (!worldBlocks[x][y][z]) {
                    NSValue *value = [NSValue valueWithSCNVector3:SCNVector3Make(x - WORLD_SIZE / 2.0 + 0.5, y - WORLD_SIZE/ 2.0 + 0.5, z - WORLD_SIZE / 2.0 + 0.5)];
                    [availablePositions addObject:value];
                }
            }
        }
    }
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSUInteger choice = [randomSource nextIntWithUpperBound:availablePositions.count];
    SCNVector3 position = availablePositions[choice].SCNVector3Value;
    NSUInteger x = position.x + 1.5;
    NSUInteger y = position.y + 1.5;
    NSUInteger z = position.z + 1.5;
    worldBlocks[x][y][z] = [Block createBlockWithColor:color inWorld:worldNode atPosition:SCNVector3ToFloat3(position)];
}

+ (void)removeBlock:(Block *)block
{
    [Block dismissBlock:block];
}

+ (void)updateTransform
{
    [World recomputeBoundingBox];
    if (SCNVector3EqualToVector3(worldMin, SCNVector3Zero) && SCNVector3EqualToVector3(worldMax, SCNVector3Zero)) return;
    SCNVector3 difference = SCNVector3Make(worldMax.x - worldMin.x, worldMax.y - worldMin.y, worldMax.z - worldMin.z);
    SCNVector3 center = SCNVector3Make(worldMin.x + difference.x / 2.0, worldMin.y + difference.y / 2.0, worldMin.z + difference.z / 2.0);
    CGFloat radius = sqrt(difference.x * difference.x + difference.y * difference.y + difference.z * difference.z) / 2.0;
    CGFloat scale = 1.0 / radius;
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.5];
    worldNode.scale = SCNVector3Make(scale, scale, scale);
    worldNode.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z);
    [SCNTransaction commit];
}

+ (void)recomputeBoundingBox
{
    NSArray<Block *> *blocks = [Block allBlocks];;
    for (Block *block in blocks) {
        simd_float3 position = block.position;
        if (position[0] - 0.5 < worldMin.x) worldMin.x = position[0] - 0.5;
        if (position[1] - 0.5 < worldMin.y) worldMin.y = position[1] - 0.5;
        if (position[2] - 0.5 < worldMin.z) worldMin.z = position[2] - 0.5;
        if (position[0] + 0.5 > worldMax.x) worldMax.x = position[0] + 0.5;
        if (position[1] + 0.5 > worldMax.y) worldMax.y = position[1] + 0.5;
        if (position[2] + 0.5 > worldMax.z) worldMax.z = position[2] + 0.5;
    }
}

+ (void)gatherUp
{
    [World updateTransform];
    NSArray<Block *> *blocks = [Block allBlocks];
    if (blocks.count < 2) return;
    Block *centralBlock = [World randomCentralBlockFromBlocks:blocks];
        NSMutableSet<Block *> *gatheredBlocks = [World blocksConnectedToBlock:centralBlock];
    NSMutableSet<Block *> *scatteredBlocks = [NSMutableSet new];
    for (Block *block in blocks) {
        assert(block.alive);
        if (![gatheredBlocks containsObject:block])
            [scatteredBlocks addObject:block];
    }
    if (!scatteredBlocks.count) return;
    [World connectScatteredBlocks:scatteredBlocks toGatheredBlocks:gatheredBlocks];
    [World updateTransform];
}

+ (Block *)randomCentralBlockFromBlocks:(NSArray<Block *> *)blocks
{
    NSMutableArray<Block *> *closestBlocks = [NSMutableArray arrayWithCapacity:WORLD_SIZE * WORLD_SIZE * WORLD_SIZE];
    float shortestDistanceSquared = +INFINITY;
    for (Block *block in blocks) {
        float distanceSquared = simd_length_squared(block.position);
        if (distanceSquared < shortestDistanceSquared) {
            [closestBlocks removeAllObjects];
            [closestBlocks addObject:block];
        } else if (distanceSquared == shortestDistanceSquared)
            [closestBlocks addObject:block];
    }
    if (closestBlocks.count > 1) {
        GKRandomSource *randomSource = [GKRandomSource sharedRandom];
        NSUInteger choice = [randomSource nextIntWithUpperBound:closestBlocks.count];
        return closestBlocks[choice];
    }
    return closestBlocks[0];
}

+ (NSMutableSet<Block *> *)blocksConnectedToBlock:(Block *)block
{
    NSMutableSet<Block *> *connectedBlocks = [NSMutableSet new];
    simd_float3 position = block.position;
    [World blocksConnectedToPosition:position notInSet:connectedBlocks];
    return connectedBlocks;
}

+ (void)blocksConnectedToPosition:(simd_float3)position notInSet:(NSMutableSet<Block *> *)set
{
    NSUInteger x = position[0] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger y = position[1] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger z = position[2] + WORLD_SIZE / 2.0 - 0.5;
    if (x > WORLD_SIZE - 1 || x < 0 || y > WORLD_SIZE - 1 || y < 0 || z > WORLD_SIZE - 1 || z < 0) return;
    if (!worldBlocks[x][y][z]) return;
    Block *block = worldBlocks[x][y][z];
    if ([set containsObject:block]) return;
    [set addObject:block];
    [World blocksConnectedToPosition:simd_make_float3(position[0] - 1.0, position[1], position[2]) notInSet:set];
    [World blocksConnectedToPosition:simd_make_float3(position[0], position[1] - 1.0, position[2]) notInSet:set];
    [World blocksConnectedToPosition:simd_make_float3(position[0], position[1], position[2] - 1.0) notInSet:set];
    [World blocksConnectedToPosition:simd_make_float3(position[0] + 1.0, position[1], position[2]) notInSet:set];
    [World blocksConnectedToPosition:simd_make_float3(position[0], position[1] + 1.0, position[2]) notInSet:set];
    [World blocksConnectedToPosition:simd_make_float3(position[0], position[1], position[2] + 1.0) notInSet:set];
}

+ (void)connectScatteredBlocks:(NSMutableSet<Block *> *)scatteredBlocks toGatheredBlocks:(NSMutableSet<Block *> *)gatheredBlocks
{
    while (scatteredBlocks.count) {
        Block *closestGatheredBlock = nil, *closestScatteredBlock = nil;
        float shortestDistanceSquared = +INFINITY;
        for (Block *scatteredBlock in scatteredBlocks) {
            for (Block *gatheredBlock in gatheredBlocks) {
                float distanceSquared = simd_distance_squared(scatteredBlock.position, gatheredBlock.position);
                if (distanceSquared < shortestDistanceSquared) {
                    closestGatheredBlock = gatheredBlock;
                    closestScatteredBlock = scatteredBlock;
                    shortestDistanceSquared = distanceSquared;
                }
            }
        }
        [gatheredBlocks addObject:closestScatteredBlock];
        [scatteredBlocks removeObject:closestScatteredBlock];
        [World moveScatteredBlock:closestScatteredBlock towardsGatheredBlock:closestGatheredBlock];;
    }
}

+ (void)moveScatteredBlock:(Block *)scatteredBlock towardsGatheredBlock:(Block *)gatheredBlock
{
    simd_float3 gatheredPosition = gatheredBlock.position;
    simd_float3 scatteredPosition = scatteredBlock.position;
    simd_float3 difference = simd_make_float3(scatteredPosition[0] - gatheredPosition[0], scatteredPosition[1] - gatheredPosition[1], scatteredPosition[2] - gatheredPosition[2]);
    simd_float3 absolute = simd_abs(difference);
    float max = simd_reduce_max(absolute);
    NSMutableArray<NSValue *> *adjacentPositions = [NSMutableArray arrayWithCapacity:3];
    if (absolute[0] == max) {
        simd_float3 position = simd_make_float3(gatheredPosition[0] + difference[0] / absolute[0], gatheredPosition[1], gatheredPosition[2]);
        SCNVector3 vector = SCNVector3FromFloat3(position);
        NSValue *value = [NSValue valueWithSCNVector3:vector];
        [adjacentPositions addObject:value];
    }
    if (absolute[1] == max) {
        simd_float3 position = simd_make_float3(gatheredPosition[0], gatheredPosition[1] + difference[1] / absolute[1], gatheredPosition[2]);
        SCNVector3 vector = SCNVector3FromFloat3(position);
        NSValue *value = [NSValue valueWithSCNVector3:vector];
        [adjacentPositions addObject:value];
    }
    if (absolute[2] == max) {
        simd_float3 position = simd_make_float3(gatheredPosition[0], gatheredPosition[1], gatheredPosition[2] + difference[2] / absolute[2]);
        SCNVector3 vector = SCNVector3FromFloat3(position);
        NSValue *value = [NSValue valueWithSCNVector3:vector];
        [adjacentPositions addObject:value];
    }
    NSValue *value;
    if (adjacentPositions.count > 1) {
        GKRandomSource *randomSource = [GKRandomSource sharedRandom];
        NSUInteger choice = [randomSource nextIntWithUpperBound:adjacentPositions.count];
        value = adjacentPositions[choice];
    } else
        value = adjacentPositions[0];
    SCNVector3 position = value.SCNVector3Value;
    simd_float3 simdPosition = SCNVector3ToFloat3(position);
    [World moveBlock:scatteredBlock toPosition:simdPosition];
}

+ (void)moveBlock:(Block *)block toPosition:(simd_float3)newPosition
{
    simd_float3 oldPosition = block.position;
    if (simd_equal(oldPosition, newPosition)) return;
    NSUInteger oldX = oldPosition[0] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger oldY = oldPosition[1] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger oldZ = oldPosition[2] + WORLD_SIZE / 2.0 - 0.5;
    assert(worldBlocks[oldX][oldY][oldZ]);
    assert(worldBlocks[oldX][oldY][oldZ] == block);
    NSUInteger newX = newPosition[0] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger newY = newPosition[1] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger newZ = newPosition[2] + WORLD_SIZE / 2.0 - 0.5;
    assert(!worldBlocks[newX][newY][newZ]);
    worldBlocks[newX][newY][newZ] = block;
    worldBlocks[oldX][oldY][oldZ] = nil;
    block.position = newPosition;
}

@end
