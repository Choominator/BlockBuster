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

static Block __weak *worldBlocks[4][4][4];
static SCNNode *worldNode;
static SCNVector3 worldMin, worldMax;

@interface World()

+ (void)updateTransform;
+ (void)recomputeBoundingBox;

@end

@implementation World

+ (void)createWorldInNode:(SCNNode *)node
{
    worldNode = [SCNNode node];
    [node addChildNode:worldNode];
}

+ (void)addBlockWithColor:(UIColor *)color
{
    NSMutableArray<NSValue *> *availablePositions = [NSMutableArray arrayWithCapacity:125];
    for (NSUInteger x = 0; x < 4; ++ x) {
        for (NSUInteger y = 0; y < 4; ++ y) {
            for (NSUInteger z = 0; z < 4; ++ z) {
                if (!worldBlocks[x][y][z]) {
                    NSValue *value = [NSValue valueWithSCNVector3:SCNVector3Make(x - 1.5, y - 1.5, z - 1.5)];
                    [availablePositions addObject:value];
                }
            }
        }
    }
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSUInteger pick = [randomSource nextIntWithUpperBound:availablePositions.count];
    SCNVector3 position = availablePositions[pick].SCNVector3Value;
    NSUInteger x = position.x + 1.5;
    NSUInteger y = position.y + 1.5;
    NSUInteger z = position.z + 1.5;
    worldBlocks[x][y][z] = [Block createBlockWithColor:color inWorld:worldNode atPosition:SCNVector3ToFloat3(position)];
    [World updateTransform];
}

+ (void)removeBlock:(Block *)block
{
    [Block dismissBlock:block];
    [World updateTransform];
}

+ (void)rotateAroundAxis:(SCNVector3)axis angle:(float)angle
{
    simd_float3 simdAxis = simd_make_float3(axis.x, axis.y, axis.z);
    simd_quatf simdRotation = simd_quaternion(angle, simdAxis);
    simd_quatf simdOrientation = worldNode.simdWorldOrientation;
    simdOrientation = simd_mul(simdRotation, simdOrientation);
    simdOrientation = simd_normalize(simdOrientation);
    worldNode.simdWorldOrientation = simdOrientation;
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
    for (NSUInteger x = 0; x < 4; ++ x) {
        for (NSUInteger y = 0; y < 4; ++ y) {
            for (NSUInteger z = 0; z < 4; ++ z) {
                if (!worldBlocks[x][y][z]) continue;
                SCNVector3 position = SCNVector3Make(x - 1.5, y - 1.5, z - 1.5);
                if (position.x - 0.5 < worldMin.x) worldMin.x = position.x - 0.5;
                if (position.y - 0.5 < worldMin.y) worldMin.y = position.y - 0.5;
                if (position.z - 0.5 < worldMin.z) worldMin.z = position.z - 0.5;
                if (position.x + 0.5 > worldMax.x) worldMax.x = position.x + 0.5;
                if (position.y + 0.5 > worldMax.y) worldMax.y = position.y + 0.5;
                if (position.z + 0.5 > worldMax.z) worldMax.z = position.z + 0.5;
            }
        }
    }
}

@end
