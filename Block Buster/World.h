//
//  World.h
//  Block Buster
//
//  Created by Joao Santos on 07/08/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import Foundation;
#import "Block.h"

NS_ASSUME_NONNULL_BEGIN

@interface World : NSObject

+ (void)createWorldInNode:(SCNNode *)node;
+ (void)addBlockWithColor:(UIColor *)color;
+ (void)removeBlock:(Block *)block;
+ (void)rotateAroundAxis:(SCNVector3)axis angle:(float)angle;
+ (void)gatherUp;

@end

NS_ASSUME_NONNULL_END
