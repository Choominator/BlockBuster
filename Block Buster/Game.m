// Created by João Santos for project Block Buster.

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
    NSTimer __weak *_comboTimer, __weak *_levelTimer, __weak *_gatherTimer;
    NSDate *_comboDate, *_levelDate;
    NSTimeInterval _levelElapsedTime, _comboElapsedTime;
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
    _levelTime = MAX_LEVEL_DURATION - MIN_LEVEL_DURATION;
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSArray *colors = [randomSource arrayByShufflingObjectsInArray:COLORS];
    _colorQueue = [NSMutableArray arrayWithArray:colors];
    float angle = [randomSource nextUniform] * M_PI * 2.0 - M_PI;
    simd_quatf rotation = simd_quaternion(angle, simd_make_float3(0.0, 0.0, 1.0));
    simd_float3 direction = simd_normalize(simd_act(rotation, simd_make_float3(1.0, 0.0, 0.0)));
    simd_float3 axis = simd_make_float3(- direction[1], direction[0], 0.0);
    angle = [randomSource nextUniform] * M_PI * 2.0 - M_PI;
    _worldNode.simdWorldOrientation = simd_quaternion(angle, axis);
    [self fillWorld];
    void (^action)(NSTimer *) = ^(NSTimer *timer) {[gameNotificationCenter postNotificationName:GameOverNotification object:self];};
    _levelTimer = [NSTimer scheduledTimerWithTimeInterval:_levelTime + MIN_LEVEL_DURATION repeats:NO block:action];
    _levelDate = [NSDate date];
    _comboColor = [UIColor whiteColor];
    [gameNotificationCenter postNotificationName:GameShouldChangeBackgroundColorNotification object:self userInfo:@{@"Color": [UIColor whiteColor]}];
    [gameNotificationCenter addObserver:self selector:@selector(safeToFillWorld:) name:BlockSafeToFillWorldNotification object:nil];
    return self;
}

- (void)dealloc
{
    [Block reset];
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
    if (_gatherTimer)
        [_gatherTimer invalidate];
    void(^action)(NSTimer *) = ^(NSTimer *timer) {[self gatherUp];};
    _gatherTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:action];
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
    for (float x = - WORLD_SIZE / 2.0 + 0.5; x <= WORLD_SIZE / 2.0 - 1.5; x += 1.0) {
        for (float y = - WORLD_SIZE / 2.0 + 0.5; y <= WORLD_SIZE / 2.0 - 0.5; y += 1.0) {
            for (float z = - WORLD_SIZE / 2.0 + 0.5; z <= WORLD_SIZE / 2.0 - 0.5; z += 1.0) {
                simd_float3 position = simd_make_float3(x, y, z);
                if ([Block queryPosition:position]) continue;
                NSValue *value = [NSValue valueWithSCNVector3:SCNVector3Make(x, y, z)];
                [availablePositions addObject:value];
            }
        }
    }
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSUInteger choice = [randomSource nextIntWithUpperBound:availablePositions.count];
    SCNVector3 position = availablePositions[choice].SCNVector3Value;
    [Block createBlockWithColor:color inWorld:_worldNode atPosition:SCNVector3ToFloat3(position)];
    [_worldColors addObject:color];
    ++ _blockCount;
}

- (void)removeBlock:(Block *)block
{
    UIColor *color = block.color;
    [_worldColors removeObject:color];
    if (![_worldColors countForObject:color]) {
        _colorQueue[_colorQueueTail] = color;
        _colorQueueTail = (_colorQueueTail + 1) % _colorQueue.count;
    }
    -- _blockCount;
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
    simd_float3 worldMin = simd_make_float3(INFINITY, INFINITY, INFINITY);
    simd_float3 worldMax = simd_make_float3(-INFINITY, -INFINITY, -INFINITY);
    NSSet<Block *> *blocks = [Block blockSet];;
    for (Block *block in blocks) {
        simd_float3 position = block.position;
        worldMin = simd_min(position, worldMin);
        worldMax = simd_max(position, worldMax);
    }
    float squaredDistance = simd_distance_squared(worldMin, worldMax);
    if (squaredDistance == INFINITY)
        worldMax = worldMin = simd_make_float3(0.0, 0.0, 0.0);
    simd_float3 difference = worldMax - worldMin;
    simd_float3 center = worldMin + difference / 2.0;
    difference += 1.0;
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
    Block *block = [Block queryPosition:position];
    if (!block) return;
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
    scatteredBlock.position = simdPosition;
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
        if (_gatherTimer)
            [_gatherTimer fire];
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

- (float)uniformTime
{
    NSTimeInterval timeInterval = [_levelDate timeIntervalSinceNow];
    return - timeInterval / (MIN_LEVEL_DURATION + _levelTime);
}

@end
