//
//  Block.h
//  Block Buster
//
//  Created by Joao Santos on 31/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;

NS_ASSUME_NONNULL_BEGIN

@interface Block : NSObject

@property (nonatomic, readonly) UIColor *color;
@property (nonatomic) BOOL lit;

+ (void)createBlockWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position;
+ (void)dismissBlock:(Block *)block;
+ (Block *)blockForNode:(SCNNode *)node;

@end

NS_ASSUME_NONNULL_END
