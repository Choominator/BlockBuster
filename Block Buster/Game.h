//
//  Game.h
//  Block Buster
//
//  Created by Joao Santos on 27/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const GameShouldChangeBackgroundColorNotification;
extern NSNotificationName const GameScoreIncrementNotification;
extern  NSNotificationName const GameOverNotification;

@interface Game : NSObject

@property (nonatomic) BOOL paused;

+ (instancetype)gameWithWorldNode:(SCNNode *)node;
- (void)tapNode:(SCNNode *)node;

@end

NS_ASSUME_NONNULL_END
