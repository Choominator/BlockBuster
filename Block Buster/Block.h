// Created by João Santos for project Block Buster.

@import SceneKit;

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const BlockSafeToFillWorldNotification;

@interface Block : NSObject

@property (nonatomic, readonly) UIColor *color;
@property (nonatomic) BOOL lit;
@property (nonatomic) simd_float3 position;
@property (nonatomic, readonly) BOOL alive;

+ (void)createBlockWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position;
+ (void)dismissBlock:(Block *)block;
+ (void)reset;
+ (Block *)blockForNode:(SCNNode *)node;
+ (NSSet<Block *> *)blockSet;
+ (NSSet<NSValue *> *)positionSet;
+ (Block *)queryPosition:(simd_float3)position;

@end

NS_ASSUME_NONNULL_END
