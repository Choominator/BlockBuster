//
//  GameDelegate.h
//  Block Buster
//
//  Created by Joao Santos on 11/08/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import UIKit;

@protocol GameDelegate <NSObject>

@property (weak, nonatomic) UIColor *comboColor;

- (void)scoreIncrement:(NSUInteger)increment;
- (void)gameOver;

@end
