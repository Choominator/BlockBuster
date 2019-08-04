//
//  GameViewController.m
//  Block Buster
//
//  Created by Joao Santos on 26/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

#import "GameViewController.h"
#import "Game.h"

@interface GameViewController()

- (void)panGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)tapGesture:(UIGestureRecognizer *)gestureRecognizer;

@end

@implementation GameViewController {
    Game *_game;
    CGPoint _panLastTranslation;
}

- (void)loadView
{
    self.view = [SCNView new];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _panLastTranslation = CGPointMake(0.0, 0.0);
    UIPanGestureRecognizer *panGestureRecognizer = [UIPanGestureRecognizer new];
    [panGestureRecognizer addTarget:self action:@selector(panGesture:)];
    [self.view addGestureRecognizer:panGestureRecognizer];
    for (NSUInteger touches = 1; touches <= 5; ++ touches) {
        UITapGestureRecognizer *tapGestureRecognizer = [UITapGestureRecognizer new];
        tapGestureRecognizer.numberOfTouchesRequired = touches;
        [tapGestureRecognizer addTarget:self action:@selector(tapGesture:)];
        [self.view addGestureRecognizer:tapGestureRecognizer];
    }
    _game = [Game gameWithView:self.view];
    self.view.isAccessibilityElement = YES;
    self.view.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.view.frame = self.view.window.bounds;
    self.view.accessibilityFrame = self.view.bounds;
    [_game adjustCameraForSize:self.view.bounds.size];
}


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [_game adjustCameraForSize:size];
    self.view.accessibilityFrame = self.view.bounds;
}

- (void)panGesture:(UIGestureRecognizer *)gestureRecognizer
{
    UIPanGestureRecognizer *panGestureRecognizer = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint translation = [panGestureRecognizer translationInView:self.view];
    CGPoint delta = CGPointMake(translation.x - _panLastTranslation.x, translation.y - _panLastTranslation.y);;
    if (panGestureRecognizer.state == UIGestureRecognizerStateEnded)
        _panLastTranslation = CGPointMake(0.0, 0.0);
    else
        _panLastTranslation = translation;
    [_game rotateWorldByDelta:delta];
}

- (void)tapGesture:(UIGestureRecognizer *)gestureRecognizer
{
    UITapGestureRecognizer *tapGestureRecognizer = (UITapGestureRecognizer *)gestureRecognizer;
    if (tapGestureRecognizer.state != UIGestureRecognizerStateEnded) return;
    NSUInteger touches = [tapGestureRecognizer numberOfTouches];
    for (NSUInteger touch = 0; touch < touches; ++ touch) {
        CGPoint point = [tapGestureRecognizer locationOfTouch:touch inView:self.view];
        [_game tapWorldAtPoint:point];
    }
}

@end
