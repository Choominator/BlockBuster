// Created by João Santos for project Block Buster.

@import SceneKit;

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const GameShouldChangeBackgroundColorNotification;
extern NSNotificationName const GameScoreIncrementNotification;
extern  NSNotificationName const GameOverNotification;

@interface Game : NSObject

@property (nonatomic) BOOL paused;
@property (nonatomic, readonly) float uniformTime;

+ (instancetype)gameWithWorldNode:(SCNNode *)node;
- (void)tapNode:(SCNNode *)node;

@end

NS_ASSUME_NONNULL_END
