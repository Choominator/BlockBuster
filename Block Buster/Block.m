//
//  Block.m
//  Block Buster
//
//  Created by Joao Santos on 31/07/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

#import "Block.h"

static SCNGeometry *commonGeometry;
static NSMutableDictionary<UIColor *, NSArray<SCNMaterial *> *> *unlitMaterials;
static NSMutableDictionary<UIColor *, NSArray<SCNMaterial *> *> *litMaterials;
static NSMutableDictionary<UIColor *, UIImage *> *emissionImages;
static NSMutableDictionary<UIColor *, UIImage *> *diffuseImages;

@interface Block()

- (SCNGeometry *)geometry;
- (NSArray<SCNMaterial *> *)unlitMaterials;
- (NSArray<SCNMaterial *> *)litMaterials;
- (SCNMaterial *)commonMaterial;
- (UIImage *)diffuseImage;
- (UIImage *)emissionImage;

@end

@implementation Block {
    NSArray<SCNMaterial *> *_litMaterials, *_unlitMaterials;
}

- (instancetype)initWithColor:(UIColor *) color
{
    self = [super init];
    if (!self) return nil;
    _color = color;
    self.geometry = [self geometry];
    return self;
}

+ (instancetype)blockWithColor:(UIColor *) color
{
    return [[Block alloc] initWithColor:color];
}

- (void)setLit:(BOOL)lit
{
    if (lit)
        self.geometry.materials = _litMaterials;
    else
        self.geometry.materials = _unlitMaterials;
    _lit = lit;
}

- (SCNGeometry *)geometry
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

@end
