//
//  Game.m
//  Block Buster
//
//  Created by Joao Santos on 27/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import GameplayKit;

#import "Game.h"
#import "World.h"
#import "Block.h"
#import "ActionQueue.h"

#define COLORS @[[UIColor redColor], [UIColor yellowColor], [UIColor greenColor], [UIColor cyanColor], [UIColor blueColor]]

#define CAMERA_FOV 30.0

#define MAX_COLORS_IN_WORLD 3
#define MAX_COMBO 5
#define MAX_BLOCKS_IN_WORLD 9

#define LEVEL_DURATION 30

@interface Game()

- (instancetype)initWithView:(UIView *)view;
- (void)createScene;
- (void)startGame;
- (void)comboWithBlock:(Block *)block;
- (void)comboTimeout:(NSTimer *)timer;

@end

@implementation Game {
    SCNView *_view;
    SCNNode *_cameraNode;
    float _cameraDistance;
    NSMutableArray<Block *> *_comboBlocks;
    UIColor *_comboColor;
    NSCountedSet<UIColor *> *_colorCounter;
    NSTimer __weak *_comboTimer;
}

- (instancetype)initWithView:(UIView *)view
{
    self =  [super init];
    if (!self) return nil;
    assert([view isKindOfClass:[SCNView class]]);
    _view =(SCNView *) view;
    _comboBlocks = [NSMutableArray arrayWithCapacity:MAX_COMBO];
    _colorCounter = [[NSCountedSet alloc] initWithCapacity:MAX_COLORS_IN_WORLD];
    _comboColor = [UIColor whiteColor];
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
    float angle = multiplier * tan(CAMERA_FOV / 180.0 * M_PI / 2.0) * (_cameraDistance - 1.0) * 4.0;
    multiplier = 1.0 / multiplier;
    axis = simd_make_float3(axis[0] * multiplier, axis[1] * multiplier, axis[2] * multiplier);
    [World rotateAroundAxis:SCNVector3FromFloat3(axis) angle:angle];
}

- (void)tapWorldAtPoint:(CGPoint) point
{
    NSArray<SCNHitTestResult *> *results = [_view hitTest:point options:@{SCNHitTestBoundingBoxOnlyKey: @(YES), SCNHitTestOptionFirstFoundOnly: @(YES)}];
    if (!results.count) return;
    for (SCNHitTestResult *result in results) {
        Block *block = [Block blockForNode:result.node];
        if (!block || !block.alive) return;;
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
    SCNScene *scene = [SCNScene scene];
    [scene.rootNode addChildNode:_cameraNode];
    [World createWorldInNode:scene.rootNode];
    _view.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
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
                      for (NSUInteger index = 0; index < MAX_BLOCKS_IN_WORLD; ++ index) {
        [World addBlockWithColor:randomColors[index]];
                          [_colorCounter addObject:randomColors[index]];
                      }
    [World gatherUp];
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
        _comboColor = [UIColor whiteColor];
        _view.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        return;
    }
    [_comboBlocks addObject:block];
    _comboColor = block.color;
    CGFloat red, green, blue;
    [_comboColor getRed:&red green:&green blue:&blue alpha:NULL];
    _view.backgroundColor = [UIColor colorWithRed:red * 0.5 green:green * 0.5 blue:blue * 0.5 alpha:1.0];
    block.lit = YES;
    if (!_comboTimer)
        _comboTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(comboTimeout:) userInfo:nil repeats:NO];
}

- (void)comboTimeout:(NSTimer *)timer
{
    if (_comboBlocks.count == 1) {
        _comboBlocks[0].lit = NO;
        [_comboBlocks removeAllObjects];
    } else if (_comboBlocks.count > 1) {
        for (Block *block in _comboBlocks) {
            [World removeBlock:block];
            [_colorCounter removeObject:_comboColor];
        }
        [_comboBlocks removeAllObjects];
        NSUInteger counter = [_colorCounter countForObject:_comboColor];
        if (counter == 1) {
            [World addBlockWithColor:_comboColor];
            [_colorCounter addObject:_comboColor];
        }
        void (^action)(void) = ^{
            [World gatherUp];
        };
        [ActionQueue enqueueAction:action];
    }
    _comboColor = [UIColor whiteColor];
    _view.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
}

@end
