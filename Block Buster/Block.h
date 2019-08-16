//
//  Block.h
//  Block Buster
//
//  Created by Joao Santos on 31/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const BlockSafeToFillWorldNotification;

@interface Block : NSObject

@property (nonatomic, readonly) UIColor *color;
@property (nonatomic) BOOL lit;
@property (nonatomic, readonly) BOOL alive;
@property (nonatomic) simd_float3 position;

+ (instancetype)createBlockWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position;
+ (void)dismissBlock:(Block *)block;
+ (Block *)blockForNode:(SCNNode *)node;
+ (NSSet<Block *> *)blockSet;

@end

NS_ASSUME_NONNULL_END
