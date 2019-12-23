//
//  GameViewController.m
//  Block Buster
//
//  Created by Joao Santos on 26/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

@import SceneKit;

#import "GameViewController.h"
#import "Game.h"

extern NSNotificationCenter *gameNotificationCenter;

#define CAMERA_FIELD_OF_VIEW 30.0

@implementation GameViewController {
    SCNNode *_cameraNode, *_worldNode;
    float _cameraDistance;
    Game *_game;
    SKLabelNode *_playLabel, *_scoreIncrementLabel, *_scoreLabel, *_gameOverLabel, *_pauseLabel;
    SKShapeNode *_pieShape;
    CGPoint _panLastTranslation;
    SKAction *_fadeInAction, *_fadeOutAction, *_scoreIncrementAction;
    id<SCNSceneRenderer> _renderer;
    NSUInteger _score;
    BOOL _ignoreTaps;
    SCNLight *_cameraLight;
    CGSize _size;
}

- (void)loadView
{
    self.view = [SCNView new];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
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
    _size = self.view.bounds.size;
    _renderer = (SCNView *) self.view;
    _renderer.scene = [self setupScene];
    _renderer.overlaySKScene = [self setupOverlay];
    _renderer.overlaySKScene.delegate = self;
    _renderer.scene.background.contents = [UIColor blackColor];
    [self updateToSize:self.view.bounds.size];
    [gameNotificationCenter addObserver:self selector:@selector(shouldChangeBackgroundColor:) name:GameShouldChangeBackgroundColorNotification object:nil];
    [gameNotificationCenter addObserver:self selector:@selector(scoreIncrement:) name:GameScoreIncrementNotification object:nil];
    [gameNotificationCenter addObserver:self selector:@selector(gameOver:) name:GameOverNotification object:nil];
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
    _size = size;
}

- (void)panGesture:(UIGestureRecognizer *)gestureRecognizer
{
    if (!_game || _paused) return;
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
    if (_size.height > _size.width)
        inverseLength = 1.0 / _size.height;
    else
        inverseLength = 1.0 / _size.width;
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
        if (_game && !_paused) {
            NSArray<SCNHitTestResult *> *results = [_renderer hitTest:point options:@{SCNHitTestBoundingBoxOnlyKey: @(YES), SCNHitTestOptionFirstFoundOnly: @(YES)}];
            if (results.count)
                for (SCNHitTestResult *result in results)
                    [_game tapNode:result.node];
        }
        if (_ignoreTaps) return;
        point = CGPointMake(point.x - _size.width / 2.0, _size.height - point.y - _size.height / 2.0);
        SKNode *node = [_renderer.overlaySKScene nodeAtPoint:point];
        if (node == _playLabel) {
            if (!_paused)
                [self startGame];
            else
                self.paused = NO;
        } else if (node == _gameOverLabel) {
            [self displayScore];
        } else if (node == _scoreLabel) {
            [self resetGame];
        } else if (node == _pauseLabel) {
            if (_paused)
                [self resetGame];
            else
                self.paused = YES;
        }
    }
}

- (SCNScene *)setupScene
{
    SCNCamera *camera = [SCNCamera camera];
    camera.fieldOfView = CAMERA_FIELD_OF_VIEW;
    _cameraLight = [SCNLight light];
    _cameraLight.color = [UIColor whiteColor];
    _cameraLight.type = SCNLightTypeOmni;
    _cameraNode = [SCNNode node];
    _cameraNode.camera = camera;
    _cameraNode.light = _cameraLight;
    _worldNode = [SCNNode node];
    SCNScene *scene = [SCNScene scene];
    [scene.rootNode addChildNode:_cameraNode];
    [scene.rootNode addChildNode:_worldNode];
    return scene;
}

- (SKScene *)setupOverlay
{
    SKShapeNode *circle = [SKShapeNode shapeNodeWithCircleOfRadius:_size.width * 0.49];
    circle.lineWidth = 2.0;
    circle.strokeColor = [UIColor whiteColor];
    circle.glowWidth = 4.0;
    circle.antialiased = YES;
    _playLabel = [SKLabelNode labelNodeWithText:@"▶"];
    _playLabel.fontColor = [UIColor whiteColor];
    _playLabel.fontSize = _size.width * 0.2;
    _playLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _playLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _playLabel.hidden = YES;
    _pauseLabel = [SKLabelNode labelNodeWithText:@"⏸"];
    _pauseLabel.fontColor = [UIColor whiteColor];
    _pauseLabel.fontSize = _size.width * 0.2;
    _pauseLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _pauseLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _pauseLabel.position = CGPointMake(0.0, _size.width * 0.6);
    _pauseLabel.hidden = YES;
    _scoreIncrementLabel = [SKLabelNode labelNodeWithText:@"0"];
    _scoreIncrementLabel.fontColor = [UIColor whiteColor];
    _scoreIncrementLabel.fontSize = _size.width * 0.6;
    _scoreIncrementLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _scoreIncrementLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _scoreIncrementLabel.hidden = YES;
    [_scoreIncrementLabel setScale:0.0];
    [_scoreIncrementLabel setAlpha:0.0];
    _scoreLabel = [SKLabelNode labelNodeWithText:@"0"];
    _scoreLabel.fontColor = [UIColor whiteColor];
    _scoreLabel.fontSize = _size.width * 0.2;
    _scoreLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _scoreLabel.hidden = YES;
    _gameOverLabel = [SKLabelNode labelNodeWithText:@"Game Over"];
    _gameOverLabel.fontColor = [UIColor whiteColor];
    _gameOverLabel.fontSize = _size.width * 0.2;
    _gameOverLabel.preferredMaxLayoutWidth = _size.width * 0.6;
    _gameOverLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _gameOverLabel.numberOfLines = 2;
    _gameOverLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    _gameOverLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    _gameOverLabel.hidden = YES;
    SKScene *scene = [SKScene sceneWithSize:_size];
    scene.anchorPoint = CGPointMake(0.5, 0.5);
    scene.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0];
    [scene addChild:circle];
    [scene addChild:_playLabel];
    [scene addChild:_scoreIncrementLabel];
    [scene addChild:_scoreLabel];
    [scene addChild:_gameOverLabel];
    [scene addChild:_pauseLabel];
    _fadeInAction = [SKAction fadeInWithDuration:0.5];
    _fadeOutAction = [SKAction fadeOutWithDuration:0.5];
    SKAction *fadeAction = [SKAction sequence:@[_fadeInAction, _fadeOutAction]];
    SKAction *growAction = [SKAction scaleTo:1.0 duration:1.0];
    _scoreIncrementAction = [SKAction group:@[fadeAction, growAction]];
    return scene;
}

- (void)scoreIncrement:(NSNotification *)notification
{
    NSNumber *number = notification.userInfo[@"Increment"];
    NSUInteger increment = number.unsignedIntegerValue;
    _score += increment;
    NSString *text;
    if (increment)
    text = [[NSString alloc] initWithFormat: @"%lu", (unsigned long) increment];
    else
        text = @"✕";
    _scoreIncrementLabel.text = text;
    _scoreIncrementLabel.hidden = NO;
    void (^actions)(void) = ^{
        self->_scoreIncrementLabel.hidden = YES;
        self->_scoreLabel.scale = 0.0;
    };
    [_scoreIncrementLabel runAction:_scoreIncrementAction completion:actions];
}

- (void)shouldChangeBackgroundColor:(NSNotification *)notification
{
    UIColor *color = notification.userInfo[@"Color"];
    CGFloat red, green, blue;
    assert([color getRed:&red green:&green blue:&blue alpha:NULL]);
    UIColor *dimmedColor = [UIColor colorWithRed:red * 0.4 green:green * 0.4 blue:blue * 0.4 alpha:1.0];;
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.25];
    _renderer.scene.background.contents = dimmedColor;
    [SCNTransaction commit];
}

- (void)gameOver:(NSNotification *)notification
{
    _game = nil;
    void (^completion)(void) = ^{
        self->_pauseLabel.hidden = YES;
        self->_ignoreTaps = NO;
    };
    [_pauseLabel runAction:_fadeOutAction completion:completion];
    _ignoreTaps = YES;
    _gameOverLabel.hidden = NO;
    [_gameOverLabel runAction:_fadeInAction];
    _renderer.playing = NO;
}

- (void)displayScore
{
    void (^completion)(void) = ^{
        self->_scoreLabel.text = [[NSString alloc] initWithFormat:@"%lu", (unsigned long) self->_score];
        self->_scoreLabel.hidden = NO;
        [self->_scoreLabel runAction:self->_fadeInAction];
        self->_ignoreTaps = NO;
    };
    [_gameOverLabel runAction:_fadeOutAction completion:completion];
    _ignoreTaps = YES;
}

- (void)resetGame
{
    _score = 0;
    if (!_game) {
        if (!_scoreLabel.hidden) {
            void (^completion)(void) = ^{
                self->_scoreLabel.hidden = YES;
                self->_ignoreTaps = NO;
                [self->_playLabel runAction:self->_fadeInAction];
                self->_playLabel.hidden = NO;
            };
            [_scoreLabel runAction:_fadeOutAction completion:completion];
            _ignoreTaps = YES;
        } else
            _playLabel.hidden = NO;
    } else {
        _game = nil;
        _renderer.playing = NO;
        _paused = NO;
        _cameraLight.color = [UIColor whiteColor];
        void (^completion)(void) = ^{
            self->_pauseLabel.hidden = YES;
            self->_ignoreTaps = NO;
        };
        [_pauseLabel runAction:_fadeOutAction completion:completion];
        _ignoreTaps = YES;
    }
}

- (void)startGame
{
    void (^completion)(void) = ^{
        self->_renderer.playing = YES;
        self->_game = [Game gameWithWorldNode:self->_worldNode];
        self->_playLabel.hidden = YES;
        self->_ignoreTaps = NO;
    };
    [_playLabel runAction:_fadeOutAction completion:completion];
    _ignoreTaps = YES;
    _pauseLabel.hidden = NO;
    [_pauseLabel runAction:_fadeInAction];
    _pauseLabel.text = @"⏸";
}

- (void)setPaused:(BOOL) paused
{
    if (!_paused && paused) {
        if (!_game) return;
        _cameraLight.color = [UIColor blackColor];
        _game.paused = YES;
        _renderer.playing = NO;
        _paused = YES;
        _playLabel.hidden = NO;
        [_playLabel runAction:_fadeInAction];
        _pauseLabel.text = @"↷";
    } else if (_paused && !paused) {
        _cameraLight.color = [UIColor whiteColor];
        _renderer.playing = YES;
        _paused = NO;
        _pauseLabel.text = @"⏸";
        _ignoreTaps = YES;
        void (^completion)(void) = ^{
            self->_ignoreTaps = NO;
            self->_playLabel.hidden = YES;
                if (self->_game) self->_game.paused = NO;
        };
        [_playLabel runAction:_fadeOutAction completion:completion];
    }
}

- (void)update:(NSTimeInterval) currentTime forScene:(SKScene *) scene
{
    if (_game)
        [self displayPieWithUniform:_game.uniformTime];
    else
        [self displayPieWithUniform:1.0];
}

- (void)displayPieWithUniform:(float)uniform
{
    if (_pieShape)
        [_pieShape removeFromParent];
    if (uniform == 1.0 || uniform == 0.0) return;
    CGFloat radius = _size.width * 0.1;
    CGFloat startAngle = M_PI / 2.0;
    CGFloat endAngle = fmod(M_PI / 2.0 + uniform * M_PI * 2.0, M_PI * 2.0);
    UIBezierPath NS_VALID_UNTIL_END_OF_SCOPE *bezierPath = [UIBezierPath bezierPath];
    [bezierPath addArcWithCenter:CGPointZero radius:radius startAngle:startAngle endAngle:endAngle clockwise:NO];
    [bezierPath addLineToPoint:CGPointZero];
    [bezierPath closePath];
    CGPathRef path = [bezierPath CGPath];
    _pieShape = [SKShapeNode shapeNodeWithPath:path centered:YES];
    _pieShape.fillColor = [UIColor whiteColor];
    _pieShape.position = CGPointMake(0.0, - _size.width * 0.6);
    _pieShape.xScale = -1.0;
    [_renderer.overlaySKScene addChild:_pieShape];
}

@end
