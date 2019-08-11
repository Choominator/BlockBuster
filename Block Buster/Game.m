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
#import "GameDelegate.h"

#define COLORS @[[UIColor redColor], [UIColor yellowColor], [UIColor greenColor], [UIColor cyanColor], [UIColor blueColor]]

#define MAX_COLORS_IN_WORLD 3
#define MAX_COMBO 5
#define MAX_BLOCKS_IN_WORLD 9

#define LEVEL_DURATION 10

@interface Game()

- (instancetype)initWithWorldNode:(SCNNode *)node;
- (void)startGame;
- (void)comboWithBlock:(Block *)block;
- (void)comboTimeout:(NSTimer *)timer;

@end

@implementation Game {
    SCNNode *_cameraNode;
    float _cameraDistance;
    NSMutableArray<Block *> *_comboBlocks;
    UIColor *_comboColor;
    NSCountedSet<UIColor *> *_colorCounter;
    NSTimer __weak *_comboTimer;
}

- (instancetype)initWithWorldNode:(SCNNode *)node
{
    self =  [super init];
    if (!self) return nil;
    _comboBlocks = [NSMutableArray arrayWithCapacity:MAX_COMBO];
    _colorCounter = [[NSCountedSet alloc] initWithCapacity:MAX_COLORS_IN_WORLD];
    _comboColor = [UIColor whiteColor];
    _comboTimer = nil;
    [World worldInNode:node];
    [self startGame];
    return self;
}

+ (instancetype)gameWithWorldNode:(SCNNode *)node
{
    return [[Game alloc] initWithWorldNode:node];
}

- (void)tapNode:(SCNNode *)node
{
    Block *block = [Block blockForNode:node];
    if (!block.alive) return;
    [self comboWithBlock:block];
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
        _delegate.comboColor = [UIColor whiteColor];
        return;
    }
    [_comboBlocks addObject:block];
    _comboColor = block.color;
    _delegate.comboColor = _comboColor;
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
    _delegate.comboColor = [UIColor whiteColor];
}

@end
