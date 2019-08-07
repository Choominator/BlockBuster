//
//  ActionQueue.h
//  Block Buster
//
//  Created by Joao Santos on 07/08/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface ActionQueue : NSObject

+ (void)enqueueAction:(void (^)(void))action;

@end

NS_ASSUME_NONNULL_END
