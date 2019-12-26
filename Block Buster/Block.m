// Created by João Santos for project Block Buster.

@import GameplayKit;

#import <objc/runtime.h>
#import "Block.h"

#define WORLD_SIZE 3

NSNotificationName const BlockSafeToFillWorldNotification = @"BlockSafeToFillWorld";
extern NSNotificationCenter *gameNotificationCenter;
static SCNGeometry *commonGeometry;
static NSMutableDictionary<UIColor *, NSArray<SCNMaterial *> *> *unlitMaterials, *litMaterials;
static NSMutableDictionary<UIColor *, UIImage *> *emissionImages;
static NSMutableDictionary<UIColor *, UIImage *> *diffuseImages;
static NSMutableDictionary<NSValue *, Block *> *blockPositions;
NSUInteger deadBlockCount;

@implementation Block {
    NSArray<SCNMaterial *> *_litMaterials, *_unlitMaterials;
    SCNNode *_node;
}

- (instancetype)initWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position
{
    self = [super init];
    if (!self) return nil;
    _color = color;
    _position = position;
    _alive = YES;
    _node = [SCNNode node];
    _node.geometry = [self setupGeometry];
    _node.simdPosition = position;
    objc_setAssociatedObject(_node, (__bridge void *) _node, self, OBJC_ASSOCIATION_ASSIGN);
    return self;
}

+ (void)createBlockWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position
{
    Block *block = [[Block alloc] initWithColor:color inWorld:world atPosition:position];
    if (!blockPositions)
        blockPositions = [NSMutableDictionary dictionaryWithCapacity:WORLD_SIZE * WORLD_SIZE * WORLD_SIZE];
    NSValue *value = [NSValue valueWithSCNVector3:SCNVector3FromFloat3(position)];
    assert(!blockPositions[value]);
    blockPositions[value] = block;
    [world addChildNode:block->_node];
    GKRandomSource *randomSource = [GKRandomSource sharedRandom];
    switch ([randomSource nextIntWithUpperBound:3]) {
        case 0: break;
        case 1: block->_node.simdOrientation = simd_quaternion(M_PI / 2.0, simd_make_float3(1.0, 0.0, 0.0)); break;
        case 2: block->_node.simdOrientation = simd_quaternion(M_PI / 2.0, simd_make_float3(0.0, 1.0, 0.0)); break;
    }
    SCNAnimation *animation = [block setupCreation];
    [block->_node addAnimation:animation forKey:nil];
}

+ (void)dismissBlock:(Block *)block
{
    ++ deadBlockCount;
    block->_alive = NO;
    SCNAnimationDidStopBlock animationActions = ^(SCNAnimation *animation, id<SCNAnimatable> receiver, BOOL completed) {
        block->_node.geometry = nil;
        -- deadBlockCount;
        SCNVector3 position = SCNVector3FromFloat3(block->_position);
        NSValue *value = [NSValue valueWithSCNVector3:position];
        blockPositions[value] = nil;
    };
    SCNAnimation *animation = [block setupDestruction];
    animation.animationDidStop = animationActions;
    [block->_node addAnimation:animation forKey:nil];
}

+ (Block *)blockForNode:(SCNNode *)node
{
    return objc_getAssociatedObject(node, (__bridge void *) node);
}

+ (void)reset
{
    deadBlockCount = 0;
    [blockPositions removeAllObjects];
}

+ (NSSet<Block *> *)blockSet;
{
    NSArray<Block *> *blockArray = [blockPositions allValues];
    NSSet<Block *> *blockSet = [NSSet setWithArray:blockArray];
    return blockSet;
}

+ (NSSet<NSValue *> *)positionSet
   {
       NSArray<NSValue *> *blockPositionArray = [blockPositions allKeys];
       NSSet<NSValue *> *blockPositionSet = [NSSet setWithArray:blockPositionArray];
       return blockPositionSet;
   }

+ (Block *)queryPosition:(simd_float3)position
{
    NSValue *value = [NSValue valueWithSCNVector3:SCNVector3FromFloat3(position)];
    return blockPositions[value];
}

- (void)dealloc
{
        if (!deadBlockCount)
            [gameNotificationCenter postNotificationName:BlockSafeToFillWorldNotification object:self];
    [_node removeFromParentNode];
}

- (void)setLit:(BOOL)lit
{
    if (lit)
        _node.geometry.materials = _litMaterials;
    else
        _node.geometry.materials = _unlitMaterials;
    _lit = lit;
}

- (void)setPosition:(simd_float3)position
{
    if (simd_equal(position, _position)) return;
    SCNVector3 oldPosition = SCNVector3FromFloat3(_position);
    SCNVector3 newPosition = SCNVector3FromFloat3(position);
    NSValue *oldValue = [NSValue valueWithSCNVector3:oldPosition];
    assert(blockPositions[oldValue]);
    NSValue *newValue = [NSValue valueWithSCNVector3:newPosition];
    assert(!blockPositions[newValue]);
    blockPositions[newValue] = blockPositions[oldValue];
    blockPositions[oldValue] = nil;
    _position = position;
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.5];
    _node.simdPosition = position;
    [SCNTransaction commit];
}

- (SCNGeometry *)setupGeometry
{
    NSArray<SCNMaterial *> *materials = [self unlitMaterials];
    _unlitMaterials = materials;
    _litMaterials = [self litMaterials];
    if (!commonGeometry)
        commonGeometry = [SCNBox boxWithWidth:1.0 height:1.0 length:1.0 chamferRadius:1.0 / 6.0];
    SCNGeometry *geometry = [commonGeometry copy];
    geometry.materials = materials;
    return geometry;
}

- (NSArray<SCNMaterial *> *)unlitMaterials
{
    if (!unlitMaterials)
        unlitMaterials = [NSMutableDictionary new];
    NSArray<SCNMaterial *> *materials = unlitMaterials[_color];
    if (materials) return materials;
    SCNMaterial *coloredMaterial = [self commonMaterial];
    coloredMaterial.diffuse.contents = [self diffuseImage];
    SCNMaterial *blackMaterial = [self commonMaterial];
    blackMaterial.diffuse.contents = [UIColor blackColor];
    materials = @[coloredMaterial, blackMaterial, coloredMaterial, blackMaterial, blackMaterial, blackMaterial];
    unlitMaterials[_color] = materials;
    _unlitMaterials = materials;
    return materials;
}

- (NSArray<SCNMaterial *> *)litMaterials
{
    if (!litMaterials)
        litMaterials = [NSMutableDictionary new];
    NSArray<SCNMaterial *> *materials = litMaterials[_color];
    if (materials) return materials;
    SCNMaterial *coloredMaterial = [self commonMaterial];
    coloredMaterial.diffuse.contents = [self diffuseImage];
    SCNMaterialProperty *property = coloredMaterial.emission;
    property.contents = [self emissionImage];
property.minificationFilter = SCNFilterModeNearest;
    property.magnificationFilter = SCNFilterModeNearest;
    SCNMaterial *blackMaterial = [self commonMaterial];
    blackMaterial.diffuse.contents = [UIColor blackColor];
    blackMaterial.emission.contents = [UIColor blackColor];
    materials = @[coloredMaterial, blackMaterial, coloredMaterial, blackMaterial, blackMaterial, blackMaterial];
    litMaterials[_color] = materials;
    _litMaterials = materials;
    return materials;
}

- (SCNMaterial *)commonMaterial
{
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelPhong;
    SCNMaterialProperty *property = material.diffuse;
    property.minificationFilter = SCNFilterModeNearest;
    property.magnificationFilter = SCNFilterModeNearest;
    material.specular.contents = [UIColor whiteColor];
    material.locksAmbientWithDiffuse = YES;
    material.shininess = 3.0;
    return material;
}

- (UIImage *)diffuseImage
{
    if (!diffuseImages)
        diffuseImages = [NSMutableDictionary new];
    UIImage *image = diffuseImages[_color];
    if (image) return image;
    UIColor *color = _color;
    UIGraphicsImageDrawingActions actions = ^(UIGraphicsImageRendererContext *context) {
        [[UIColor blackColor] setFill];
        CGRect bounds = context.format.bounds;
        [context fillRect:bounds];
        CGFloat red, green, blue;
        [color getRed:&red green:&green blue:&blue alpha:NULL];
        UIColor *fillColor = [UIColor colorWithRed:red * 0.6 green:green * 0.6 blue:blue * 0.6 alpha:1.0];
        [fillColor setFill];
        bounds = CGRectMake(bounds.origin.x + 1.0, bounds.origin.y + 1.0, bounds.size.width - 2.0, bounds.size.height - 2.0);
        [context fillRect:bounds];
    };
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(6.0, 6.0)];
    image = [renderer imageWithActions:actions];
    diffuseImages[color] = image;
    return image;
}

- (UIImage *)emissionImage
{
    if (!emissionImages)
        emissionImages = [NSMutableDictionary new];
    UIImage *image = emissionImages[_color];
    if (image) return image;
    UIColor *color = _color;
    UIGraphicsImageDrawingActions actions = ^(UIGraphicsImageRendererContext *context) {
        [[UIColor blackColor] setFill];
        CGRect bounds = context.format.bounds;
        [context fillRect:bounds];
        [color setFill];
        bounds = CGRectMake(bounds.origin.x + 1.0, bounds.origin.y + 1.0, bounds.size.width - 2.0, bounds.size.height - 2.0);
        [context fillRect:bounds];
    };
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(6.0, 6.0)];
    image = [renderer imageWithActions:actions];
    emissionImages[color] = image;
    return image;
}

- (SCNAnimation *)setupCreation
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"scale"];
    animation.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(0.0, 0.0, 0.0)];
    animation.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(1.0, 1.0, 1.0)];
    animation.duration = 0.5;
    animation.removedOnCompletion = YES;
    animation.usesSceneTimeBase = NO;
    return [SCNAnimation animationWithCAAnimation:animation];
}

- (SCNAnimation *)setupDestruction
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"scale"];
    animation.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(0.0, 0.0, 0.0)];
    animation.duration = 0.5;
    animation.removedOnCompletion = YES;
    animation.usesSceneTimeBase = NO;
    return [SCNAnimation animationWithCAAnimation:animation];
}

@end
