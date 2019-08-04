//
//  Game.m
//  Block Buster
//
//  Created by Joao Santos on 27/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import GameplayKit;

#import "Block.h"
#import "Game.h"

#define COLORS @[[UIColor whiteColor], [UIColor redColor], [UIColor yellowColor], [UIColor greenColor], [UIColor cyanColor], [UIColor blueColor]]

#define CAMERA_FOV 60.0

#define WORLD_SIZE 5.0

#define MAX_COLORS_IN_WORLD 3
#define MAX_COMBO 5
#define MAX_BLOCKS_IN_WORLD 12

#define LEVEL_DURATION 30

@interface Game()

- (void)createScene;
- (void)startGame;
- (void)spawnBlockWithColor:(UIColor *)color;
- (NSArray<NSValue *> *)emptyNeighborsForPosition:(SCNVector3) position;
- (BOOL)isValidEmptyBlockPosition:(SCNVector3) position;
- (void)comboWithBlock:(Block *)block;
- (void)comboTimeout:(NSTimer *)timer;
- (void)despawnBlock:(Block *)block;
- (void)updateWorldTransform;

@end

@implementation Game {
    SCNView *_view;
    SCNNode *_worldNode, *_cameraNode;
    float _cameraDistance;
    NSMutableArray<Block *> *_comboBlocks;
    UIColor *_comboColor;
    NSMutableDictionary<UIColor *, NSNumber *> *_colorCounter;
    NSTimer __weak *_comboTimer;
}

- (instancetype)initWithView:(UIView *)view
{
    self =  [super init];
    if (!self) return nil;
    assert([view isKindOfClass:[SCNView class]]);
    _view =(SCNView *) view;
    _comboBlocks = [NSMutableArray arrayWithCapacity:MAX_COMBO];
    _colorCounter = [NSMutableDictionary new];
    _comboColor = [UIColor blackColor];
    _comboTimer = nil;
    [self createScene];
    [self startGame];
    return self;
}

+ (instancetype)gameWithView:(UIView *) view
{
    return [[Game alloc] initWithView:view];
}

- (void)adjustCameraForSize:(CGSize) size
{
    float aspectRatio;
    if (size.width > size.height) {
        _cameraNode.camera.projectionDirection = SCNCameraProjectionDirectionHorizontal;
        aspectRatio = size.height / size.width;
    } else {
        _cameraNode.camera.projectionDirection = SCNCameraProjectionDirectionVertical;
        aspectRatio = size.width / size.height;
    }
    float angle = atan(aspectRatio * tan(CAMERA_FOV / 180.0 * M_PI / 2.0));
    _cameraDistance = 1.0 / sin(angle);
    _cameraNode.position = SCNVector3Make(0.0, 0.0, _cameraDistance);
}

- (void)rotateWorldByDelta:(CGPoint) delta
{
    if (CGPointEqualToPoint(delta, CGPointZero))
        return;
    float inverseLength;
    CGSize size = _view.bounds.size;
    if (size.height > size.width)
        inverseLength = 1.0 / size.height;
    else
        inverseLength = 1.0 / size.width;
    simd_float3 axis = simd_make_float3(delta.y * inverseLength, delta.x * inverseLength, 0.0);
    float multiplier = simd_length(axis);
    float angle = multiplier * tan(CAMERA_FOV / 180.0 * M_PI / 2.0) * (_cameraDistance - 1.0) * 2.0;
    multiplier = 1.0 / multiplier;
    axis = simd_make_float3(axis[0] * multiplier, axis[1] * multiplier, axis[2] * multiplier);
    simd_quatf rotation = simd_quaternion(angle, axis);
    _worldNode.simdWorldOrientation = simd_normalize(simd_mul(rotation, _worldNode.simdWorldOrientation));
}

- (void)tapWorldAtPoint:(CGPoint) point
{
    NSArray<SCNHitTestResult *> *results = [_view hitTest:point options:@{SCNHitTestBoundingBoxOnlyKey: @(YES), SCNHitTestOptionFirstFoundOnly: @(YES)}];
    if (!results.count) return;
    for (SCNHitTestResult *result in results) {
        Block *block = [Block blockForNode:result.node];
        if (!block) return;;
            [self comboWithBlock:block];
    }
}

- (void)createScene
{
    SCNCamera *camera = [SCNCamera camera];
    camera.fieldOfView = CAMERA_FOV;
    SCNLight *light = [SCNLight light];
    light.type = SCNLightTypeOmni;
    light.color = [UIColor whiteColor];
    _cameraNode = [SCNNode node];
    _cameraNode.camera = camera;
    _cameraNode.light = light;
    [self adjustCameraForSize:_view.bounds.size];
    _worldNode = [SCNNode node];
    SCNScene *scene = [SCNScene scene];
    [scene.rootNode addChildNode:_cameraNode];
    [scene.rootNode addChildNode:_worldNode];
    _view.backgroundColor = [UIColor blackColor];
    _view.scene = scene;
}

- (void)startGame
{
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSArray<UIColor *> *colors = [randomSource arrayByShufflingObjectsInArray:COLORS];
    NSMutableArray<UIColor *> *mandatory = [NSMutableArray arrayWithCapacity:MAX_COLORS_IN_WORLD * 2];
    NSMutableArray<UIColor *> *optional = [NSMutableArray arrayWithCapacity:MAX_COLORS_IN_WORLD * (MAX_COMBO - 2)];
    for (NSUInteger index = 0; index < MAX_COLORS_IN_WORLD; ++ index) {
        UIColor *color = colors[index];
        [mandatory addObject:color];
        [mandatory addObject:color];
        for (NSUInteger combo = 2; combo < MAX_COMBO; ++ combo)
            [optional addObject:color];
    }
    NSArray<UIColor *> *randomMandatory = [randomSource arrayByShufflingObjectsInArray:mandatory];
    NSArray<UIColor *> *randomOptional = [randomSource arrayByShufflingObjectsInArray:optional];
    NSMutableArray<UIColor *> *randomColors = [NSMutableArray arrayWithCapacity:MAX_COLORS_IN_WORLD * 2 + (MAX_COMBO - 2) * MAX_COLORS_IN_WORLD];
    [randomColors addObjectsFromArray:randomMandatory];
    [randomColors addObjectsFromArray:randomOptional];
    for (NSUInteger index = 0; index < MAX_BLOCKS_IN_WORLD; ++ index)
        [self spawnBlockWithColor:randomColors[index]];
}

- (void)spawnBlockWithColor:(UIColor *)color
{
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    NSArray<SCNNode *> *blockNodes = [_worldNode childNodes];
    NSUInteger blockCount = blockNodes.count;
    SCNVector3 position = SCNVector3Make(0.0, 0.0, 0.0);
    if (blockCount) {
        BOOL foundSuitableNeighbor = NO;
        NSArray<NSValue *> *emptyBlocks;;
        while (!foundSuitableNeighbor) {
            NSUInteger pick = [randomSource nextIntWithUpperBound:blockCount];
            SCNNode *neighborBlock = blockNodes[pick];
            emptyBlocks = [self emptyNeighborsForPosition:neighborBlock.position];
            if (emptyBlocks.count)
                foundSuitableNeighbor = YES;
        }
        NSUInteger pick = [randomSource nextIntWithUpperBound:emptyBlocks.count];
        position = emptyBlocks[pick].SCNVector3Value;
    }
    NSNumber *number = _colorCounter[color];
    NSUInteger counter = number.unsignedIntegerValue;
    ++ counter;
    _colorCounter[color] = @(counter);
    [Block blockWithColor:color inWorld:_worldNode atPosition:SCNVector3ToFloat3(position)];
    [self updateWorldTransform];
}

- (NSArray<NSValue *> *)emptyNeighborsForPosition:(SCNVector3) position
{
    NSMutableArray *positions = [NSMutableArray arrayWithCapacity:6];
    SCNVector3 test;
    test = SCNVector3Make(position.x + 1.0, position.y, position.z);
    if ([self isValidEmptyBlockPosition:test])
        [positions addObject:[NSValue valueWithSCNVector3:test]];
        test = SCNVector3Make(position.x, position.y + 1.0, position.z);
    if ([self isValidEmptyBlockPosition:test])
        [positions addObject:[NSValue valueWithSCNVector3:test]];
    test = SCNVector3Make(position.x, position.y, position.z + 1.0);
    if ([self isValidEmptyBlockPosition:test])
        [positions addObject:[NSValue valueWithSCNVector3:test]];
    test = SCNVector3Make(position.x - 1.0, position.y, position.z);
    if ([self isValidEmptyBlockPosition:test])
        [positions addObject:[NSValue valueWithSCNVector3:test]];
    test = SCNVector3Make(position.x, position.y - 1.0, position.z);
    if ([self isValidEmptyBlockPosition:test])
        [positions addObject:[NSValue valueWithSCNVector3:test]];
    test = SCNVector3Make(position.x, position.y, position.z - 1.0);
    if ([self isValidEmptyBlockPosition:test])
        [positions addObject:[NSValue valueWithSCNVector3:test]];
    return positions;
}

- (BOOL)isValidEmptyBlockPosition:(SCNVector3) position
{
    SCNVector3 min, max;
    [_worldNode getBoundingBoxMin:&min max:&max];
    if (position.x > min.x + WORLD_SIZE) return NO;
    if (position.y > min.y + WORLD_SIZE) return NO;
    if (position.z > min.z + WORLD_SIZE) return NO;
    if (position.x <  max.x - WORLD_SIZE) return NO;
    if (position.y < max.y - WORLD_SIZE) return NO;
    if (position.z < max.z - WORLD_SIZE) return NO;
    NSArray <SCNNode *> *result = [_worldNode childNodes];
    for (SCNNode *node in result)
        if (SCNVector3EqualToVector3(position, node.position))
            return NO;
    return YES;
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
        for (Block *comboBlock in _comboBlocks)
            comboBlock.lit = NO;
        [_comboBlocks removeAllObjects];
        [_comboTimer invalidate];
        _comboColor = [UIColor blackColor];
        _view.backgroundColor = _comboColor;
        return;
    }
    [_comboBlocks addObject:block];
    _comboColor = block.color;
    CGFloat red, green, blue;
    [_comboColor getRed:&red green:&green blue:&blue alpha:NULL];
    _view.backgroundColor = [UIColor colorWithRed:red * 0.3 green:green * 0.3 blue:blue * 0.3 alpha:1.0];
    block.lit = YES;
    _comboTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(comboTimeout:) userInfo:nil repeats:NO];
}

- (void)comboTimeout:(NSTimer *)timer
{
    if (_comboBlocks.count == 1) {
        _comboBlocks[0].lit = NO;
        [_comboBlocks removeAllObjects];
    } else if (_comboBlocks.count > 1) {
        for (Block *block in _comboBlocks)
            [self despawnBlock:block];
        [_comboBlocks removeAllObjects];
    }
    _view.backgroundColor = [UIColor blackColor];
}

- (void)despawnBlock:(Block *)block
{
     UIColor *color = block.color;
    NSNumber *number = _colorCounter[color];
    NSUInteger counter = number.unsignedIntegerValue;
    -- counter;
    _colorCounter[color] = @(counter);
    if (counter == 1)
        [self spawnBlockWithColor:color];
    [Block dismissBlock:block];
    [self updateWorldTransform];
}

- (void)updateWorldTransform
{
    CGFloat radius;
    SCNVector3 center;
    [_worldNode getBoundingSphereCenter:&center radius:&radius];
    CGFloat scale = 1.0 / radius;
    _worldNode.scale = SCNVector3Make(scale, scale, scale);
    _worldNode.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z);
}

@end
