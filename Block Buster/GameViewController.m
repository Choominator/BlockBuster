//
//  GameViewController.m
//  Block Buster
//
//  Created by Joao Santos on 26/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;
@import SpriteKit;

#import "GameViewController.h"
#import "Game.h"

#define CAMERA_FIELD_OF_VIEW 30.0

@interface GameViewController()

- (void)updateToSize:(CGSize)size;
- (void)panGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)tapGesture:(UIGestureRecognizer *)gestureRecognizer;
- (SCNScene *)setupScene;
- (SKScene *)setupOverlay;
- (void)displayScore;
- (void)resetGame;
- (void)startGame;

@end

@implementation GameViewController {
    SCNNode *_cameraNode, *_worldNode;
    float _cameraDistance;
    Game *_game;
    SKLabelNode *_playLabel, *_scoreIncrementLabel, *_scoreLabel, *_gameOverLabel;
    CGPoint _panLastTranslation;
    SKAction *_fadeInAction, *_fadeOutAction, *_scoreIncrementAction;
    id<SCNSceneRenderer> _renderer;
    NSUInteger _score;
    BOOL _ignoreTaps;
}

- (void)loadView
{
    self.view = [SCNView new];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _panLastTranslation = CGPointZero;;
    UIPanGestureRecognizer *panGestureRecognizer = [UIPanGestureRecognizer new];
    [panGestureRecognizer addTarget:self action:@selector(panGesture:)];
    [self.view addGestureRecognizer:panGestureRecognizer];
    for (NSUInteger touches = 1; touches <= 5; ++ touches) {
        UITapGestureRecognizer *tapGestureRecognizer = [UITapGestureRecognizer new];
        tapGestureRecognizer.numberOfTouchesRequired = touches;
        [tapGestureRecognizer addTarget:self action:@selector(tapGesture:)];
        [self.view addGestureRecognizer:tapGestureRecognizer];
    }
    self.view.isAccessibilityElement = YES;
    self.view.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
    _ignoreTaps = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _renderer = (SCNView *) self.view;
    _renderer.scene = [self setupScene];
    _renderer.overlaySKScene = [self setupOverlay];
    self.comboColor = [UIColor blackColor];
    [self updateToSize:self.view.bounds.size];
    [self resetGame];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self updateToSize:size];
}

- (void)updateToSize:(CGSize)size
{
    self.view.frame = self.view.window.bounds;
    self.view.accessibilityFrame = self.view.bounds;
    float aspectRatio;
    if (size.width > size.height) {
        _cameraNode.camera.projectionDirection = SCNCameraProjectionDirectionHorizontal;
        aspectRatio = size.height / size.width;
    } else {
        _cameraNode.camera.projectionDirection = SCNCameraProjectionDirectionVertical;
        aspectRatio = size.width / size.height;
    }
    float angle = atan(aspectRatio * tan(CAMERA_FIELD_OF_VIEW / 180.0 * M_PI / 2.0));
    _cameraDistance = 1.0 / sin(angle);
    _cameraNode.simdPosition = simd_make_float3(0.0, 0.0, _cameraDistance);
}

- (void)panGesture:(UIGestureRecognizer *)gestureRecognizer
{
    if (!_game) return;
    UIPanGestureRecognizer *panGestureRecognizer = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint translation = [panGestureRecognizer translationInView:self.view];
    CGPoint delta = CGPointMake(translation.x - _panLastTranslation.x, translation.y - _panLastTranslation.y);;
    if (panGestureRecognizer.state == UIGestureRecognizerStateEnded)
        _panLastTranslation = CGPointZero;
    else
        _panLastTranslation = translation;
    if (CGPointEqualToPoint(delta, CGPointZero))
        return;
    float inverseLength;
    CGSize size = self.view.bounds.size;
    if (size.height > size.width)
        inverseLength = 1.0 / size.height;
    else
        inverseLength = 1.0 / size.width;
    simd_float3 axis = simd_make_float3(delta.y * inverseLength, delta.x * inverseLength, 0.0);
    float multiplier = simd_length(axis);
    float angle = multiplier * tan(CAMERA_FIELD_OF_VIEW / 180.0 * M_PI / 2.0) * (_cameraDistance - 1.0) * 4.0;
    multiplier = 1.0 / multiplier;
    axis = simd_make_float3(axis[0] * multiplier, axis[1] * multiplier, axis[2] * multiplier);
    simd_quatf simdRotation = simd_quaternion(angle, axis);
    simd_quatf simdOrientation = _worldNode.simdWorldOrientation;
    simdOrientation = simd_mul(simdRotation, simdOrientation);
    simdOrientation = simd_normalize(simdOrientation);
    _worldNode.simdWorldOrientation = simdOrientation;
}

- (void)tapGesture:(UIGestureRecognizer *)gestureRecognizer
{
    UITapGestureRecognizer *tapGestureRecognizer = (UITapGestureRecognizer *)gestureRecognizer;
    if (tapGestureRecognizer.state != UIGestureRecognizerStateEnded) return;
    NSUInteger touches = [tapGestureRecognizer numberOfTouches];
    for (NSUInteger touch = 0; touch < touches; ++ touch) {
        CGPoint point = [tapGestureRecognizer locationOfTouch:touch inView:self.view];
        if (_game) {
            NSArray<SCNHitTestResult *> *results = [_renderer hitTest:point options:@{SCNHitTestBoundingBoxOnlyKey: @(YES), SCNHitTestOptionFirstFoundOnly: @(YES)}];
            if (!results.count) return;
            for (SCNHitTestResult *result in results)
                [_game tapNode:result.node];
        } else {
            if (_ignoreTaps) return;
            CGSize size = self.view.bounds.size;
            point.x -= size.width / 2.0;
            point.y = size.height - point.y - size.height / 2.0;
            SKNode *node = [_renderer.overlaySKScene nodeAtPoint:point];
            if (node == _playLabel) {
                void(^actions)(void) = ^{
                    [self startGame];
                    self->_playLabel.hidden = YES;
                    self->_ignoreTaps = NO;
                };
                [_playLabel runAction:_fadeOutAction completion:actions];
                _ignoreTaps = YES;
            } else if (node == _gameOverLabel) {
                void (^actions)(void) = ^{
                    self->_gameOverLabel.hidden = YES;
                    [self displayScore];
                    self->_ignoreTaps = NO;
                };
                [_gameOverLabel runAction:_fadeOutAction completion:actions];
                _ignoreTaps = YES;
            } else if (node == _scoreLabel) {
                void (^actions)(void) = ^{
                    self->_scoreLabel.hidden = YES;
                    [self resetGame];
                    self->_ignoreTaps = NO;
                };
                [_scoreLabel runAction:_fadeOutAction completion:actions];
                _ignoreTaps = YES;
            }
        }
    }
}

- (SCNScene *)setupScene
{
    SCNCamera *camera = [SCNCamera camera];
    camera.fieldOfView = CAMERA_FIELD_OF_VIEW;
    SCNLight *light = [SCNLight light];
    light.color = [UIColor whiteColor];
    light.type = SCNLightTypeOmni;
    _cameraNode = [SCNNode node];
    _cameraNode.camera = camera;
    _cameraNode.light = light;
    _worldNode = [SCNNode node];
    SCNScene *scene = [SCNScene scene];
    [scene.rootNode addChildNode:_cameraNode];
    [scene.rootNode addChildNode:_worldNode];
    return scene;
}

- (SKScene *)setupOverlay
{
    CGSize size = self.view.bounds.size;
    SKShapeNode *circle = [SKShapeNode shapeNodeWithCircleOfRadius:size.width * 0.49];
    circle.lineWidth = 2.0;
    circle.strokeColor = [UIColor whiteColor];
    circle.glowWidth = 4.0;
    circle.antialiased = YES;
    _playLabel = [SKLabelNode labelNodeWithText:@"▷"];
    _playLabel.fontColor = [UIColor whiteColor];
    _playLabel.fontSize = self.view.bounds.size.width * 0.6;
    _playLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _playLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _playLabel.hidden = YES;
    _scoreIncrementLabel = [SKLabelNode labelNodeWithText:@"0"];
    _scoreIncrementLabel.fontColor = [UIColor whiteColor];
    _scoreIncrementLabel.fontSize = self.view.bounds.size.width * 0.6;
    _scoreIncrementLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _scoreIncrementLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _scoreIncrementLabel.hidden = YES;
    [_scoreIncrementLabel setScale:0.0];
    [_scoreIncrementLabel setAlpha:0.0];
    _scoreLabel = [SKLabelNode labelNodeWithText:@"0"];
    _scoreLabel.fontColor = [UIColor whiteColor];
    _scoreLabel.fontSize = self.view.bounds.size.width * 0.2;
    _scoreLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _scoreLabel.hidden = YES;
    _gameOverLabel = [SKLabelNode labelNodeWithText:@"Game Over"];
    _gameOverLabel.fontColor = [UIColor whiteColor];
    _gameOverLabel.fontSize = self.view.bounds.size.width * 0.1;
    _gameOverLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _gameOverLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _gameOverLabel.hidden = YES;
    SKScene *scene = [SKScene sceneWithSize:size];
    scene.anchorPoint = CGPointMake(0.5, 0.5);
    scene.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
    [scene addChild:circle];
    [scene addChild:_playLabel];
    [scene addChild:_scoreIncrementLabel];
    [scene addChild:_scoreLabel];
    [scene addChild:_gameOverLabel];
    _fadeInAction = [SKAction fadeInWithDuration:0.5];
    _fadeOutAction = [SKAction fadeOutWithDuration:0.5];
    SKAction *fadeAction = [SKAction sequence:@[_fadeInAction, _fadeOutAction]];
    SKAction *growAction = [SKAction scaleTo:1.0 duration:1.0];
    _scoreIncrementAction = [SKAction group:@[fadeAction, growAction]];
    return scene;
}

- (void)scoreIncrement:(NSUInteger)increment
{
    _score += increment;
    NSString *text;
    if (increment)
    text = [[NSString alloc] initWithFormat: @"%lu", (unsigned long) increment];
    else
        text = @"✕";
    _scoreIncrementLabel.text = text;
    _scoreIncrementLabel.hidden = NO;
    void (^actions)(void) = ^{self->_scoreIncrementLabel.hidden = YES;};
    [_scoreIncrementLabel runAction:_scoreIncrementAction completion:actions];
}

- (void)setComboColor:(UIColor *)comboColor
{
    CGFloat red, green, blue;
    assert([comboColor getRed:&red green:&green blue:&blue alpha:NULL]);
    UIColor *dimmedColor = [UIColor colorWithRed:red * 0.4 green:green * 0.4 blue:blue * 0.4 alpha:1.0];;
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.25];
    _renderer.scene.background.contents = dimmedColor;
    [SCNTransaction commit];
    _comboColor = comboColor;
}

- (void)gameOver
{
    _game = nil;
    _gameOverLabel.hidden = NO;
    [_gameOverLabel runAction:_fadeInAction];
}

- (void)displayScore
{
    _scoreLabel.text = [[NSString alloc] initWithFormat:@"%lu", (unsigned long) _score];
    _scoreLabel.hidden = NO;
    [_scoreLabel runAction:_fadeInAction];
}

- (void)resetGame
{
    _score = 0;
    _playLabel.hidden = NO;
    [_playLabel runAction:_fadeInAction];
}

- (void)startGame
{
    _score = 0;
    _game = [Game gameWithWorldNode:_worldNode];
    _game.delegate = self;
}

@end
