//
//  GameViewController.h
//  Block Buster
//
//  Created by Joao Santos on 26/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import UIKit;

#import "GameDelegate.h"

@interface GameViewController : UIViewController <GameDelegate>

@property (weak, nonatomic) UIColor *comboColor;

- (void)scoreIncrement:(NSUInteger)increment;
- (void)gameOver;

@end
