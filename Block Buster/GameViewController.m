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

@end

@implementation GameViewController {
    SCNNode *_cameraNode, *_worldNode;
    float _cameraDistance;
    Game *_game;
    SKLabelNode *_playLabel, *_fadingLabel;
    CGPoint _panLastTranslation;
    SKAction *_fadingAction;
    id<SCNSceneRenderer> _renderer;
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
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _renderer = (SCNView *) self.view;
    _renderer.scene = [self setupScene];
    _renderer.overlaySKScene = [self setupOverlay];
    self.comboColor = [UIColor whiteColor];
    [self updateToSize:self.view.bounds.size];
    _game = [Game gameWithWorldNode:_worldNode];
    _game.delegate = self;
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
        NSArray<SCNHitTestResult *> *results = [_renderer hitTest:point options:@{SCNHitTestBoundingBoxOnlyKey: @(YES), SCNHitTestOptionFirstFoundOnly: @(YES)}];
        if (!results.count) return;
        for (SCNHitTestResult *result in results) {
            [_game tapNode:result.node];
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
    _fadingLabel = [SKLabelNode labelNodeWithText:@"0"];
    _fadingLabel.fontColor = [UIColor whiteColor];
    _fadingLabel.fontSize = self.view.bounds.size.width * 0.6;
    _fadingLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _fadingLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _fadingLabel.hidden = YES;
    [_fadingLabel setScale:0.0];
    SKScene *scene = [SKScene sceneWithSize:size];
    scene.anchorPoint = CGPointMake(0.5, 0.5);
    scene.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
    [scene addChild:circle];
    [scene addChild:_playLabel];
    [scene addChild:_fadingLabel];
    SKAction *fadeInAction = [SKAction fadeInWithDuration:1.0];
    SKAction *fadeOutAction = [SKAction fadeOutWithDuration:1.0];
    SKAction *fadeAction = [SKAction sequence:@[fadeInAction, fadeOutAction]];
    SKAction *growAction = [SKAction scaleTo:1.0 duration:2.0];
    _fadingAction = [SKAction group:@[fadeAction, growAction]];
    return scene;
}

- (void)displayFadingString:(NSString *)string
{
    _fadingLabel.text = string;
    _fadingLabel.hidden = NO;
    void (^actions)(void) = ^{
        [self->_fadingLabel setScale:0.0];
        self->_fadingLabel.hidden = YES;
    };
    [_fadingLabel runAction:_fadingAction completion:actions];
}

- (void)displayScoreIncrement:(NSUInteger)increment
{
    NSString *string = [[NSString alloc] initWithFormat: @"%lu", (unsigned long) increment];
    [self displayFadingString:string];
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

@end
