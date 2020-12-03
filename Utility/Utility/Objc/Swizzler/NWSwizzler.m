//
//  NWSwizzler.m
//  Utility
//
//  Created by Tian on 2020/10/30.
//

#import "NWSwizzler.h"

#import <objc/runtime.h>

#define MIN_ARGS 2
#define MAX_ARGS 5

#define FIND_SWIZZLE \
NWSwizzlingOnClass *swizzlingOnClass = fb_findSwizzle(self, _cmd); \
NWSwizzle *swizzle = swizzlingOnClass.bindingSwizzle;

#define REMOVE_SELECTOR \
[NWSwizzler object:self ofClass:swizzlingOnClass.bindingClass removeSelector:_cmd];

@interface NWSwizzle : NSObject

@property (nonatomic, assign) Class class;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) IMP originalMethod;
@property (nonatomic, assign) uint numArgs;
@property (nonatomic, copy) NSMapTable *blocks;

- (instancetype)initWithBlock:(swizzleBlock)aBlock
                        named:(NSString *)aName
                     forClass:(Class)aClass
                     selector:(SEL)aSelector
               originalMethod:(IMP)aMethod
                  withNumArgs:(uint)numArgs;
@end

@interface NWSwizzlingOnClass : NSObject

@property NWSwizzle *bindingSwizzle;
@property Class bindingClass;

- (instancetype)initWithSwizzle:(NWSwizzle *)aSwizzle
                          class:(Class)aClass;
@end

@interface NWSwizzler ()

+ (void)object:(id)anObject ofClass:(Class)aClass addSelector:(SEL)aSelector;
+ (void)object:(id)anObject ofClass:(Class)aClass removeSelector:(SEL)aSelector;
+ (BOOL)object:(id)anObject ofClass:(Class)aClass isCallingSelector:(SEL)aSelector;

@end

static NSMapTable *swizzles;
static NSMutableSet<NSString *> *selectorCallingSet;
static dispatch_queue_t swizzleQueue;

static NWSwizzlingOnClass *fb_findSwizzle(id self, SEL _cmd) {
    Method aMethod = class_getInstanceMethod([self class], _cmd);
    Class this_class = [self class];
    NWSwizzle *swizzle = nil;
    
    if (![NWSwizzler object:self ofClass:this_class isCallingSelector:_cmd]) {
        swizzle = (NWSwizzle *)[swizzles objectForKey:MAPTABLE_ID(aMethod)];
    }
    
    while (!swizzle && class_getSuperclass(this_class)) {
        this_class = class_getSuperclass(this_class);
        aMethod = class_getInstanceMethod(this_class, _cmd);
        
        if (![NWSwizzler object:self ofClass:this_class isCallingSelector:_cmd]) {
            swizzle = (NWSwizzle *)[swizzles objectForKey:MAPTABLE_ID(aMethod)];
        }
    }
    
    if (swizzle) {
        [NWSwizzler object:self ofClass:this_class addSelector:_cmd];
    }
    NWSwizzlingOnClass *swizzlingOnClass = [[NWSwizzlingOnClass alloc] initWithSwizzle:swizzle class:this_class];
    return swizzlingOnClass;
}

static void fb_swizzledMethod_2(id self, SEL _cmd) {
    FIND_SWIZZLE;
    if (swizzle) {
        ((void (*)(id, SEL))swizzle.originalMethod)(self, _cmd);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        swizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd);
        }
        REMOVE_SELECTOR;
    }
}

static void fb_swizzledMethod_3(id self, SEL _cmd, id arg) {
    FIND_SWIZZLE;
    if (swizzle) {
        ((void (*)(id, SEL, id))swizzle.originalMethod)(self, _cmd, arg);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        swizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg);
        }
        REMOVE_SELECTOR;
    }
}

static void fb_swizzledMethod_4(id self, SEL _cmd, id arg, id arg2) {
    FIND_SWIZZLE;
    if (swizzle) {
        ((void (*)(id, SEL, id, id))swizzle.originalMethod)(self, _cmd, arg, arg2);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        swizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg, arg2);
        }
        REMOVE_SELECTOR;
    }
}

static void fb_swizzledMethod_5(id self, SEL _cmd, id arg, id arg2, id arg3) {
    FIND_SWIZZLE;
    if (swizzle) {
        ((void (*)(id, SEL, id, id, id))swizzle.originalMethod)(self, _cmd, arg, arg2, arg3);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        swizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg, arg2, arg3);
        }
        REMOVE_SELECTOR;
    }
}

static void fb_swizzleMethod_4_io(id self, SEL _cmd, NSInteger arg, id arg2) {
    FIND_SWIZZLE;
    if (swizzle) {
        ((void (*)(id, SEL, NSInteger, id))swizzle.originalMethod)(self, _cmd, arg, arg2);
        
        NSEnumerator *blocks = [swizzle.blocks objectEnumerator];
        swizzleBlock block;
        while ((block = [blocks nextObject])) {
            block(self, _cmd, arg, arg2);
        }
        REMOVE_SELECTOR;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"

static void (*nw_swizzledMethods[MAX_ARGS - MIN_ARGS + 1])() = {fb_swizzledMethod_2, fb_swizzledMethod_3, fb_swizzledMethod_4, fb_swizzledMethod_5};

#pragma clang diagnostic pop

@implementation NWSwizzler

+ (void)initialize {
    swizzles = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory
                                                   | NSPointerFunctionsOpaquePersonality)
                                     valueOptions:(NSPointerFunctionsStrongMemory
                                                   | NSPointerFunctionsObjectPointerPersonality)];
    selectorCallingSet = [NSMutableSet set];
    swizzleQueue = dispatch_queue_create("com.xxxx.swizzler", DISPATCH_QUEUE_SERIAL);
    [NWSwizzler resolveConflict];
}

+ (void)resolveConflict {
    Class swizzler = objc_lookUpClass("MPSwizzler");
    if (swizzler) {
        Method method = class_getClassMethod(swizzler, @selector(swizzleSelector:onClass:withBlock:named:));
        Method newMethod = class_getClassMethod(self, @selector(swizzleSelector:onClass:withBlock:named:));
        method_setImplementation(method, method_getImplementation(newMethod));
    }
}

+ (void)printSwizzles {
    NSEnumerator *en = [swizzles objectEnumerator];
    NWSwizzle *swizzle;
    while ((swizzle = (NWSwizzle *)[en nextObject])) {
        NSLog(@"%@", swizzle);
    }
}

+ (NWSwizzle *)swizzleForMethod:(Method)aMethod {
    return (NWSwizzle *)[swizzles objectForKey:MAPTABLE_ID(aMethod)];
}

+ (void)removeSwizzleForMethod:(Method)aMethod {
    [swizzles removeObjectForKey:MAPTABLE_ID(aMethod)];
}

+ (void)setSwizzle:(NWSwizzle *)swizzle forMethod:(Method)aMethod {
    [swizzles setObject:swizzle forKey:MAPTABLE_ID(aMethod)];
}

+ (BOOL)isLocallyDefinedMethod:(Method)aMethod onClass:(Class)aClass {
    uint count;
    BOOL isLocal = NO;
    Method *methods = class_copyMethodList(aClass, &count);
    for (NSUInteger i = 0; i < count; i++) {
        if (aMethod == methods[i]) {
            isLocal = YES;
            break;
        }
    }
    free(methods);
    return isLocal;
}

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(swizzleBlock)aBlock named:(NSString *)aName {
    dispatch_async(swizzleQueue, ^{
        @try {
            Method aMethod = class_getInstanceMethod(aClass, aSelector);
            if (aMethod) {
                uint numArgs = method_getNumberOfArguments(aMethod);
                if (numArgs >= MIN_ARGS && numArgs <= MAX_ARGS) {
                    BOOL isLocal = [NWSwizzler isLocallyDefinedMethod:aMethod onClass:aClass];
                    IMP swizzledMethod = (IMP)nw_swizzledMethods[numArgs - 2];
                    // Check whether the first parameter is integer
                    if (4 == numArgs) {
                        char *type = method_copyArgumentType(aMethod, 2);
                        NSString *firstType = [NSString stringWithCString:type encoding:NSUTF8StringEncoding];
                        NSString *integerTypes = @"islq";
                        if ([integerTypes containsString:firstType.lowercaseString]) {
                            swizzledMethod = (IMP)fb_swizzleMethod_4_io;
                        }
                        free(type);
                    }
                    
                    NWSwizzle *swizzle = [NWSwizzler swizzleForMethod:aMethod];
                    
                    if (isLocal) {
                        if (!swizzle) {
                            IMP originalMethod = method_getImplementation(aMethod);
                            
                            // Replace the local implementation of this method with the swizzled one
                            method_setImplementation(aMethod, swizzledMethod);
                            
                            // Create and add the swizzle
                            swizzle = [[NWSwizzle alloc] initWithBlock:aBlock named:aName forClass:aClass selector:aSelector originalMethod:originalMethod withNumArgs:numArgs];
                            [NWSwizzler setSwizzle:swizzle forMethod:aMethod];
                        } else {
                            [swizzle.blocks setObject:aBlock forKey:aName];
                        }
                    } else {
                        IMP originalMethod = swizzle ? swizzle.originalMethod : method_getImplementation(aMethod);
                        
                        // Add the swizzle as a new local method on the class.
                        if (!class_addMethod(aClass, aSelector, swizzledMethod, method_getTypeEncoding(aMethod))) {
                            return;
                        }
                        // Now re-get the Method, it should be the one we just added.
                        Method newMethod = class_getInstanceMethod(aClass, aSelector);
                        if (aMethod == newMethod) {
                            return;
                        }
                        
                        NWSwizzle *newSwizzle = [[NWSwizzle alloc] initWithBlock:aBlock named:aName forClass:aClass selector:aSelector originalMethod:originalMethod withNumArgs:numArgs];
                        [NWSwizzler setSwizzle:newSwizzle forMethod:newMethod];
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"Fail to swizzle selector. Exception reason: %@", exception.reason);
        }
    });
}

+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass {
    Method aMethod = class_getInstanceMethod(aClass, aSelector);
    NWSwizzle *swizzle = [NWSwizzler swizzleForMethod:aMethod];
    if (swizzle) {
        method_setImplementation(aMethod, swizzle.originalMethod);
        [NWSwizzler removeSwizzleForMethod:aMethod];
    }
}

/*
 Remove the named swizzle from the given class/selector. If aName is nil, remove all
 swizzles for this class/selector
 */
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass named:(NSString *)aName {
    @try {
        Method aMethod = class_getInstanceMethod(aClass, aSelector);
        NWSwizzle *swizzle = [NWSwizzler swizzleForMethod:aMethod];
        if (swizzle) {
            if (aName) {
                [swizzle.blocks removeObjectForKey:aName];
            }
            if (!aName || swizzle.blocks.count == 0) {
                method_setImplementation(aMethod, swizzle.originalMethod);
                [NWSwizzler removeSwizzleForMethod:aMethod];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Fail to remove the named swizzle from given class/selector. Exception reason: %@", exception.reason);
    }
}

+ (void)object:(id)anObject ofClass:(Class)aClass addSelector:(SEL)aSelector {
    NSString *objectClassSelectorString = [NSString stringWithFormat:@"%p %@ %@", anObject, NSStringFromClass(aClass), NSStringFromSelector(aSelector)];
    @synchronized(selectorCallingSet) {
        [selectorCallingSet addObject:objectClassSelectorString];
    }
}

+ (void)object:(id)anObject ofClass:(Class)aClass removeSelector:(SEL)aSelector {
    NSString *objectClassSelectorString = [NSString stringWithFormat:@"%p %@ %@", anObject, NSStringFromClass(aClass), NSStringFromSelector(aSelector)];
    @synchronized(selectorCallingSet) {
        [selectorCallingSet removeObject:objectClassSelectorString];
    }
}

+ (BOOL)object:(id)anObject ofClass:(Class)aClass isCallingSelector:(SEL)aSelector {
    NSString *objectClassSelectorString = [NSString stringWithFormat:@"%p %@ %@", anObject, NSStringFromClass(aClass), NSStringFromSelector(aSelector)];
    if ([selectorCallingSet containsObject:objectClassSelectorString]) {
        return YES;
    }
    return NO;
}

@end

@implementation NWSwizzle

- (instancetype)init {
    if (self = [super init]) {
        self.blocks = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsStrongMemory
                                                          | NSPointerFunctionsObjectPersonality)
                                            valueOptions:(NSPointerFunctionsStrongMemory
                                                          | NSPointerFunctionsObjectPointerPersonality)];
    }
    return self;
}

- (instancetype)initWithBlock:(swizzleBlock)aBlock
                        named:(NSString *)aName
                     forClass:(Class)aClass
                     selector:(SEL)aSelector
               originalMethod:(IMP)aMethod
                  withNumArgs:(uint)numArgs {
    if (self = [self init]) {
        self.class = aClass;
        self.selector = aSelector;
        self.numArgs = numArgs;
        self.originalMethod = aMethod;
        [_blocks setObject:aBlock forKey:aName];
    }
    return self;
}

- (NSString *)description {
    NSString *descriptors = @"";
    NSString *key;
    NSEnumerator *keys = [_blocks keyEnumerator];
    while ((key = [keys nextObject])) {
        descriptors = [descriptors stringByAppendingFormat:@"\t%@ : %@\n", key, [_blocks objectForKey:key]];
    }
    return [NSString stringWithFormat:@"Swizzle on %@::%@ [\n%@]", NSStringFromClass(self.class),
            NSStringFromSelector(self.selector), descriptors];
}

@end

@implementation NWSwizzlingOnClass

- (instancetype)initWithSwizzle:(NWSwizzle *)aSwizzle
                          class:(Class)aClass {
    if (self = [super init]) {
        self.bindingSwizzle = aSwizzle;
        self.bindingClass = aClass;
    }
    return self;
}

@end
