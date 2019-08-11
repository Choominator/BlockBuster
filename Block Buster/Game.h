//
//  Game.h
//  Block Buster
//
//  Created by Joao Santos on 27/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;

#import "GameDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface Game : NSObject

@property (weak, nonatomic) id<GameDelegate> delegate;

+ (instancetype)gameWithWorldNode:(SCNNode *)node;
- (void)tapNode:(SCNNode *)node;

@end

NS_ASSUME_NONNULL_END
