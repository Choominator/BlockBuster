//
//  Game.m
//  Block Buster
//
//  Created by Joao Santos on 27/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import GameplayKit;

#import "Game.h"
#import "Block.h"

#define COLORS @[[UIColor redColor], [UIColor yellowColor], [UIColor greenColor], [UIColor cyanColor], [UIColor blueColor]]

#define WORLD_SIZE 3
#define MAX_COLORS_IN_WORLD 3
#define MAX_BLOCKS_IN_WORLD 9
#define MAX_COMBO 5

#define MAX_LEVEL_DURATION 30
#define MIN_LEVEL_DURATION 10
#define COMBOS_PER_LEVEL 5

extern NSNotificationCenter *gameNotificationCenter;

NSNotificationName const GameShouldChangeBackgroundColorNotification = @"GameShouldChangeBackgroundColor";
NSNotificationName const GameScoreIncrementNotification = @"GameScoreIncrement";
NSNotificationName const GameOverNotification = @"GameOver";;

@implementation Game {
    NSMutableArray<Block *> *_comboBlocks;
    NSCountedSet<UIColor *> *_worldColors;
    NSTimer __weak *_comboTimer, __weak *_levelTimer;
    NSDate *_comboDate, *_levelDate;
    NSTimeInterval _levelElapsedTime, _comboElapsedTime;
    Block __weak *_worldBlocks[WORLD_SIZE][WORLD_SIZE][WORLD_SIZE];
    simd_float3 _worldMin, _worldMax;
    NSUInteger _blockCount, _colorQueueHead, _colorQueueTail, _comboCount;
    float _levelTime;
    NSMutableArray<UIColor *> *_colorQueue;
    SCNNode *_worldNode;
    UIColor *_comboColor;
}

- (instancetype)initWithWorldNode:(SCNNode *)node
{
    self =  [super init];
    if (!self) return nil;
    _worldNode = node;
    _comboBlocks = [NSMutableArray arrayWithCapacity:MAX_COMBO];
    _worldColors = [[NSCountedSet alloc] initWithCapacity:MAX_COLORS_IN_WORLD];
    _colorQueueHead = 0;
    _colorQueueTail = 0;
    _blockCount = 0;
    _levelTime = MAX_LEVEL_DURATION - MIN_LEVEL_DURATION;
    _comboCount = 0;
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSArray *colors = [randomSource arrayByShufflingObjectsInArray:COLORS];
    _colorQueue = [NSMutableArray arrayWithArray:colors];
    for (NSUInteger x = 0; x < WORLD_SIZE; ++ x)
        for (NSUInteger y = 0; y < WORLD_SIZE; ++ y)
            for (NSUInteger z = 0; z < WORLD_SIZE; ++ z)
                _worldBlocks[x][y][z] = nil;
    [self fillWorld];
    void (^action)(NSTimer *) = ^(NSTimer *timer) {[gameNotificationCenter postNotificationName:GameOverNotification object:self];};
    _levelTimer = [NSTimer scheduledTimerWithTimeInterval:_levelTime + MIN_LEVEL_DURATION repeats:NO block:action];
    _comboTimer = nil;
    _levelDate = [NSDate date];
    _comboDate = nil;
    _levelElapsedTime = 0.0;
    _comboElapsedTime = 0.0;
    _paused = NO;
    _comboColor = [UIColor whiteColor];
    [gameNotificationCenter postNotificationName:GameShouldChangeBackgroundColorNotification object:self userInfo:@{@"Color": [UIColor whiteColor]}];
    [gameNotificationCenter addObserver:self selector:@selector(safeToFillWorld:) name:BlockSafeToFillWorldNotification object:nil];
    return self;
}

- (void)dealloc
{
    NSArray<Block *> *allBlocks= [[Block blockSet] allObjects];
    for (Block *block in allBlocks)
        [self removeBlock:block];
    if (_comboTimer)
        [_comboTimer invalidate];
    if (_levelTimer)
        [_levelTimer invalidate];
    [gameNotificationCenter postNotificationName:GameShouldChangeBackgroundColorNotification object:self userInfo:@{@"Color": [UIColor blackColor]}];
}

+ (instancetype)gameWithWorldNode:(SCNNode *)node
{
    return [[Game alloc] initWithWorldNode:node];
}

- (void)tapNode:(SCNNode *)node
{
    Block *block = [Block blockForNode:node];
    if (!block || !block.alive) return;
    [self comboWithBlock:block];
}

- (void)fillWorld
{
    while (_worldColors.count < MAX_COLORS_IN_WORLD) {
        UIColor *color = _colorQueue[_colorQueueHead];
        _colorQueueHead = (_colorQueueHead + 1) % _colorQueue.count;
        [self addBlockWithColor:color];
    }
    NSMutableArray<UIColor *> *mandatoryColors = [NSMutableArray arrayWithCapacity:MAX_COLORS_IN_WORLD];
    NSMutableArray<UIColor *> *optionalColors = [NSMutableArray arrayWithCapacity:MAX_COMBO * (MAX_COLORS_IN_WORLD - 2)];
    for (UIColor *color in _worldColors) {
        if ([_worldColors countForObject:color] == 1)
            [mandatoryColors addObject:color];
        for (NSUInteger count = 2; count < MAX_COMBO; ++ count)
            [optionalColors addObject:color];
    }
    for (UIColor *color in mandatoryColors)
        [self addBlockWithColor:color];
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSArray<UIColor *> *shuffledColors = [randomSource arrayByShufflingObjectsInArray:optionalColors];
    for (NSUInteger index = 0; _blockCount < MAX_BLOCKS_IN_WORLD; ++ index)
        [self addBlockWithColor:shuffledColors[index]];
    [self gatherUp];
}

- (void)comboWithBlock:(Block *)block
{
    NSString *colorString;
    if (block.color == [UIColor whiteColor]) colorString = @"White";
    else if (block.color == [UIColor redColor]) colorString = @"Red";
    else if (block.color == [UIColor yellowColor]) colorString = @"Yellow";
    else if (block.color == [UIColor greenColor]) colorString = @"Green";
    else if (block.color == [UIColor cyanColor]) colorString = @"Cyan";
    else if (block.color == [UIColor blueColor]) colorString = @"Blue";
    else colorString = @"Unknown colored";
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, colorString);
    if (block.lit) return;
    if (block.color != _comboColor && _comboBlocks.count) {
        [gameNotificationCenter postNotificationName:GameScoreIncrementNotification object:self userInfo:@{@"Increment": @(0)}];
        for (Block *comboBlock in _comboBlocks)
            comboBlock.lit = NO;
        [_comboBlocks removeAllObjects];
        [_comboTimer invalidate];
        _comboDate = nil;
                                                                                              _comboColor = [UIColor whiteColor];
        [gameNotificationCenter postNotificationName:GameShouldChangeBackgroundColorNotification object:self userInfo:@{@"Color": _comboColor}];
        return;
    }
    [_comboBlocks addObject:block];
    _comboColor = block.color;
    [gameNotificationCenter postNotificationName:GameShouldChangeBackgroundColorNotification object:self userInfo:@{@"Color": _comboColor}];
    block.lit = YES;
    if (!_comboTimer)
        [_comboTimer invalidate];
    _comboTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(comboTimeout:) userInfo:nil repeats:NO];
    _comboDate = [NSDate date];
    if (_comboBlocks.count == [_worldColors countForObject:_comboColor])
        [_comboTimer fire];
}

- (void)comboTimeout:(NSTimer *)timer
{
    if (_comboBlocks.count == 1) {
        _comboBlocks[0].lit = NO;
        [_comboBlocks removeAllObjects];
    } else if (_comboBlocks.count > 1) {
        NSUInteger scoreIncrement = 1 << (_comboBlocks.count - 2);
        [gameNotificationCenter postNotificationName:GameScoreIncrementNotification object:self userInfo:@{@"Increment": @(scoreIncrement)}];
        for (Block *block in _comboBlocks)
            [self removeBlock:block];
        [_comboBlocks removeAllObjects];
        ++ _comboCount;
        if (_comboCount  == COMBOS_PER_LEVEL)
            [self levelUp];
    }
    _comboColor = [UIColor whiteColor];
    [gameNotificationCenter postNotificationName:GameShouldChangeBackgroundColorNotification object:self userInfo:@{@"Color": _comboColor}];
    _comboDate = nil;
}

- (void)addBlockWithColor:(UIColor *)color
{
    NSMutableArray<NSValue *> *availablePositions = [NSMutableArray arrayWithCapacity:WORLD_SIZE * WORLD_SIZE * WORLD_SIZE];
    for (NSUInteger x = 0; x < WORLD_SIZE; ++ x) {
        for (NSUInteger y = 0; y < WORLD_SIZE; ++ y) {
            for (NSUInteger z = 0; z < WORLD_SIZE; ++ z) {
                if (!_worldBlocks[x][y][z]) {
                    NSValue *value = [NSValue valueWithSCNVector3:SCNVector3Make(x - WORLD_SIZE / 2.0 + 0.5, y - WORLD_SIZE / 2.0 + 0.5, z - WORLD_SIZE / 2.0 + 0.5)];
                    [availablePositions addObject:value];
                }
            }
        }
    }
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSUInteger choice = [randomSource nextIntWithUpperBound:availablePositions.count];
    SCNVector3 position = availablePositions[choice].SCNVector3Value;
    NSUInteger x = position.x + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger y = position.y + WORLD_SIZE / 2.0 - 0.5;;
    NSUInteger z = position.z + WORLD_SIZE / 2.0 - 0.5;
    _worldBlocks[x][y][z] = [Block createBlockWithColor:color inWorld:_worldNode atPosition:SCNVector3ToFloat3(position)];
    [_worldColors addObject:color];
    ++ _blockCount;
}

- (void)removeBlock:(Block *)block
{
    UIColor *color = block.color;
    [_worldColors removeObject:color];
    if (![_worldColors countForObject:color]) {
        _colorQueue[_colorQueueTail] = color;
        _colorQueueTail = (_colorQueueTail + 1) % 5;
    }
    -- _blockCount;
    simd_float3 position = block.position;
    NSUInteger x = position[0] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger y = position[1] + WORLD_SIZE / 2.0 - 0.5;;
    NSUInteger z = position[2] + WORLD_SIZE / 2.0 - 0.5;
    _worldBlocks[x][y][z] = nil;
    [Block dismissBlock:block];
}

- (void)gatherUp
{
    NSSet<Block *> *allBlocks = [Block blockSet];
    if (!allBlocks.count) return;
    NSMutableSet<Block *> *scatteredBlocks = [NSMutableSet setWithSet:allBlocks];
    NSMutableSet<Block *> *gatheredBlocks = [NSMutableSet setWithCapacity:allBlocks.count];
    Block *centralBlock = [self randomBlockFromBlocks:allBlocks closestToPosition:simd_make_float3(0.0, 0.0, 0.0)];
    do {
        [gatheredBlocks removeAllObjects];
        [self blocksConnectedToPosition:centralBlock.position addToSet:gatheredBlocks];
        [scatteredBlocks minusSet:gatheredBlocks];
        float shortestDistanceSquared = INFINITY;
        Block *closestGatheredBlock = nil;
        Block *closestScatteredBlock = nil;
        for (Block *scatteredBlock in scatteredBlocks) {
            Block *gatheredBlock = [self randomBlockFromBlocks:gatheredBlocks closestToPosition:scatteredBlock.position];
            float distanceSquared = simd_distance_squared(scatteredBlock.position, gatheredBlock.position);
            if (distanceSquared < shortestDistanceSquared) {
                closestScatteredBlock = scatteredBlock;
                closestGatheredBlock = gatheredBlock;
                shortestDistanceSquared = distanceSquared;
            }
        }
        if (shortestDistanceSquared < INFINITY)
            [self moveScatteredBlock:closestScatteredBlock towardsGatheredBlock:closestGatheredBlock];
    } while (scatteredBlocks.count);
    [self updateTransform];
}

- (void)updateTransform
{
    simd_float3 worldMin = simd_make_float3(WORLD_SIZE / 2.0, WORLD_SIZE / 2.0, WORLD_SIZE / 2.0);
    simd_float3 worldMax = simd_make_float3(-WORLD_SIZE / 2.0, -WORLD_SIZE / 2.0, -WORLD_SIZE / 2.0);
    NSSet<Block *> *blocks = [Block blockSet];;
    for (Block *block in blocks) {
        simd_float3 position = block.position;
        worldMin = simd_min(simd_make_float3(position[0] - 0.5, position[1] - 0.5, position[2] - 0.5), worldMin);
        worldMax = simd_max(simd_make_float3(position[0] + 0.5, position[1] + 0.5, position[2] + 0.5), worldMax);
    }
    simd_float3 difference = simd_make_float3(worldMax[0] - worldMin[0], worldMax[1] - worldMin[1], worldMax[2] - worldMin[2]);
    simd_float3 center = simd_make_float3(worldMin[0] + difference[0] / 2.0, worldMin[1] + difference[1] / 2.0, worldMin[2] + difference[2] / 2.0);
    if (difference[0] == 0.0 && difference[1] == 0.0 && difference[2] == 0.0) return;
    float radius = simd_length(difference) / 2.0;
    float scale = 1.0 / radius * 0.98;
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.5];
    _worldNode.simdScale = simd_make_float3(scale, scale, scale);
    simd_float4 col0 = simd_make_float4(1.0, 0.0, 0.0, 0.0);
    simd_float4 col1 = simd_make_float4(0.0, 1.0, 0.0, 0.0);
    simd_float4 col2 = simd_make_float4(0.0, 0.0, 1.0, 0.0);
    simd_float4 col3 = simd_make_float4(center[0], center[1], center[2], 1.0);
    _worldNode.simdPivot = simd_matrix(col0, col1, col2, col3);
    [SCNTransaction commit];
}

- (Block *)randomBlockFromBlocks:(NSSet<Block *> *)blocks closestToPosition:(simd_float3) position;
{
    NSMutableArray<Block *> *closestBlocks = [NSMutableArray arrayWithCapacity:blocks.count];
    float shortestDistanceSquared = INFINITY;
    for (Block *block in blocks) {
        float distanceSquared = simd_distance_squared(position, block.position);
        if (distanceSquared < shortestDistanceSquared) {
            shortestDistanceSquared = distanceSquared;
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

- (void)blocksConnectedToPosition:(simd_float3)position addToSet:(NSMutableSet<Block *> *)set
{
    NSUInteger x = position[0] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger y = position[1] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger z = position[2] + WORLD_SIZE / 2.0 - 0.5;
    if (x > WORLD_SIZE - 1 || x < 0 || y > WORLD_SIZE - 1 || y < 0 || z > WORLD_SIZE - 1 || z < 0) return;
    if (!_worldBlocks[x][y][z]) return;
    Block *block = _worldBlocks[x][y][z];
    if ([set containsObject:block]) return;
    [set addObject:block];
    [self blocksConnectedToPosition:simd_make_float3(position[0] - 1.0, position[1], position[2]) addToSet:set];
    [self blocksConnectedToPosition:simd_make_float3(position[0], position[1] - 1.0, position[2]) addToSet:set];
    [self blocksConnectedToPosition:simd_make_float3(position[0], position[1], position[2] - 1.0) addToSet:set];
    [self blocksConnectedToPosition:simd_make_float3(position[0] + 1.0, position[1], position[2]) addToSet:set];
    [self blocksConnectedToPosition:simd_make_float3(position[0], position[1] + 1.0, position[2]) addToSet:set];
    [self blocksConnectedToPosition:simd_make_float3(position[0], position[1], position[2] + 1.0) addToSet:set];
}

- (void)moveScatteredBlock:(Block *)scatteredBlock towardsGatheredBlock:(Block *)gatheredBlock
{
    simd_float3 gatheredPosition = gatheredBlock.position;
    simd_float3 scatteredPosition = scatteredBlock.position;
    simd_float3 difference = simd_make_float3(scatteredPosition[0] - gatheredPosition[0], scatteredPosition[1] - gatheredPosition[1], scatteredPosition[2] - gatheredPosition[2]);
    simd_float3 absolute = simd_abs(difference);
    assert(simd_reduce_max(absolute));
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
    [self moveBlock:scatteredBlock toPosition:simdPosition];
}

- (void)moveBlock:(Block *)block toPosition:(simd_float3)newPosition
{
    simd_float3 oldPosition = block.position;
    if (simd_equal(oldPosition, newPosition)) return;
    NSUInteger oldX = oldPosition[0] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger oldY = oldPosition[1] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger oldZ = oldPosition[2] + WORLD_SIZE / 2.0 - 0.5;
    assert(_worldBlocks[oldX][oldY][oldZ]);
    assert(_worldBlocks[oldX][oldY][oldZ] == block);
    NSUInteger newX = newPosition[0] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger newY = newPosition[1] + WORLD_SIZE / 2.0 - 0.5;
    NSUInteger newZ = newPosition[2] + WORLD_SIZE / 2.0 - 0.5;
    assert(!_worldBlocks[newX][newY][newZ]);
    _worldBlocks[newX][newY][newZ] = block;
    _worldBlocks[oldX][oldY][oldZ] = nil;
    block.position = newPosition;
}

- (void)levelUp
{
    _comboCount = 0;
    _levelTime *= 0.9;
    [_levelTimer invalidate];
    void (^action)(NSTimer *) = ^(NSTimer *timer) {[gameNotificationCenter postNotificationName:GameOverNotification object:self];};
    _levelTimer = [NSTimer scheduledTimerWithTimeInterval:_levelTime + MIN_LEVEL_DURATION repeats:NO block:action];
    _levelDate = [NSDate date];
}

- (void)safeToFillWorld:(NSNotification *)notification
{
    [self fillWorld];
}

- (void)setPaused:(BOOL) paused
{
    if (!_paused && paused) {
        _paused = YES;
        _levelElapsedTime = - [_levelDate timeIntervalSinceNow];
        [_levelTimer invalidate];
        if (_comboDate) {
            _comboElapsedTime = - [_comboDate timeIntervalSinceNow];
            [_comboTimer invalidate];
        }
    } else if (_paused && !paused) {
        _paused = NO;
        _levelDate = [NSDate dateWithTimeIntervalSinceNow:- _levelElapsedTime];
        void (^actions)(NSTimer *) = ^(NSTimer *timer) {[gameNotificationCenter postNotificationName:GameOverNotification object:self];};
        _levelTimer = [NSTimer scheduledTimerWithTimeInterval:_levelTime + MIN_LEVEL_DURATION - _levelElapsedTime repeats:NO block:actions];
        if (_comboDate) {
            _comboDate = [NSDate dateWithTimeIntervalSinceNow:- _comboElapsedTime];
            _comboTimer = [NSTimer timerWithTimeInterval:0.5 - _comboElapsedTime target:self selector:@selector(comboTimeout:) userInfo:nil repeats:NO];
        }
    }
}

@end
