//
//  Block.h
//  Block Buster
//
//  Created by Joao Santos on 31/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;

NS_ASSUME_NONNULL_BEGIN

@interface Block : SCNNode

@property (nonatomic, readonly) UIColor *color;
@property (nonatomic) BOOL lit;

- (instancetype)initWithColor:(UIColor *) color;
+ (instancetype)blockWithColor:(UIColor *) color;

@end

NS_ASSUME_NONNULL_END
