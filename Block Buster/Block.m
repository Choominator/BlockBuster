//
//  Block.m
//  Block Buster
//
//  Created by Joao Santos on 31/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

#import <objc/runtime.h>
#import "Block.h"

static SCNGeometry *commonGeometry;
static NSMutableDictionary<UIColor *, NSArray<SCNMaterial *> *> *unlitMaterials;
static NSMutableDictionary<UIColor *, NSArray<SCNMaterial *> *> *litMaterials;
static NSMutableDictionary<UIColor *, UIImage *> *emissionImages;
static NSMutableDictionary<UIColor *, UIImage *> *diffuseImages;
static Block *blockList;

@interface Block()

- (instancetype)initWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position;
- (SCNGeometry *)setupGeometry;
- (NSArray<SCNMaterial *> *)unlitMaterials;
- (NSArray<SCNMaterial *> *)litMaterials;
- (SCNMaterial *)commonMaterial;
- (UIImage *)diffuseImage;
- (UIImage *)emissionImage;
- (SCNAnimation *)setupCreation;
- (SCNAnimation *)setupDestruction;
- (void)setupExplosion;

@end

@implementation Block {
    NSArray<SCNMaterial *> *_litMaterials, *_unlitMaterials;
    SCNNode *_node;
    Block *_next, __weak *_prev;
    SCNParticleSystem *_explosion;
}

- (instancetype)initWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position
{
    self = [super init];
    if (!self) return nil;
    _color = color;
    _node = [SCNNode node];
    _node.geometry = [self setupGeometry];
    _node.simdPosition = position;
    objc_setAssociatedObject(_node, (__bridge void *) _node, self, OBJC_ASSOCIATION_ASSIGN);
    [world addChildNode:_node];
    SCNAnimation *animation = [self setupCreation];
    [_node addAnimation:animation forKey:nil];
    [self setupExplosion];
    return self;
}

+ (void)createBlockWithColor:(UIColor *) color inWorld:(SCNNode *)world atPosition:(simd_float3)position
{
    Block *block = [[Block alloc] initWithColor:color inWorld:world atPosition:position];
    if (!blockList) {
        blockList = block;
        block->_next = block;
        block->_prev = block;
    } else {
        block->_next = blockList;
        block->_prev = blockList->_prev;
        block->_prev->_next = block;
        block->_next->_prev = block;
    }
    block->_alive = YES;
}

+ (void)dismissBlock:(Block *)block
{
    block->_alive = NO;
    void (^timerActions)(NSTimer *) = ^(NSTimer *timer) {
        if (blockList == block)
            blockList = block->_next;
        block->_prev->_next = block->_next;
        block->_next->_prev = block->_prev;
        block->_prev = nil;
        block->_next = nil;
        if (blockList == block)
            blockList = nil;
    };
    [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:NO block:timerActions];
    SCNAnimationDidStopBlock animationActions = ^(SCNAnimation *animation, id<SCNAnimatable> receiver, BOOL completed) {
        block->_node.geometry = nil;
        [block->_node addParticleSystem:block->_explosion];
    };
    SCNAnimation *animation = [block setupDestruction];
    animation.animationDidStop = animationActions;
    [block->_node addAnimation:animation forKey:nil];
}

+ (Block *)blockForNode:(SCNNode *)node
{
    return objc_getAssociatedObject(node, (__bridge void *) node);
}

- (void)dealloc
{
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
    SCNMaterial *material = [self commonMaterial];
    materials = @[material];
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
    SCNMaterial *material = [self commonMaterial];
    SCNMaterialProperty *property = material.emission;
    property.contents = [self emissionImage];
property.minificationFilter = SCNFilterModeNearest;
    property.magnificationFilter = SCNFilterModeNearest;
    materials = @[material];
    litMaterials[_color] = materials;
    _litMaterials = materials;
    return materials;
}

- (SCNMaterial *)commonMaterial
{
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelPhong;
    SCNMaterialProperty *property = material.diffuse;
    property.contents = [self diffuseImage];
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
    animation.duration = 1.0;
    animation.removedOnCompletion = YES;
    return [SCNAnimation animationWithCAAnimation:animation];
}

- (SCNAnimation *)setupDestruction
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"scale"];
    animation.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(1.0, 1.0, 1.0)];
    animation.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(0.0, 0.0, 0.0)];
    animation.duration = 1.0;
    animation.removedOnCompletion = YES;
    return [SCNAnimation animationWithCAAnimation:animation];
}

- (void)setupExplosion
{
    _explosion = [SCNParticleSystem particleSystem];
    _explosion.emissionDuration = 0.2;
    _explosion.birthRate = 50.0;
    _explosion.birthDirection = SCNParticleBirthDirectionRandom;
    _explosion.particleVelocity = 10.0;
    _explosion.particleLifeSpan = 0.1;
    _explosion.particleSize = 0.01;
    _explosion.particleColor = _color;
    _explosion.particleDiesOnCollision = YES;
    _explosion.sortingMode = SCNParticleSortingModeProjectedDepth;
    _explosion.local = YES;
}

@end
