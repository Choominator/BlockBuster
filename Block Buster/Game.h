//
//  Game.h
//  Block Buster
//
//  Created by Joao Santos on 27/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;

NS_ASSUME_NONNULL_BEGIN

@interface Game : NSObject

- (instancetype)initWithView:(UIView *)view;
+ (instancetype)gameWithView:(UIView *) view;

- (void)adjustCameraForSize:(CGSize) size;
- (void)rotateWorldByDelta:(CGPoint)delta;
- (void)tapWorldAtPoint:(CGPoint) point;

@end

NS_ASSUME_NONNULL_END
