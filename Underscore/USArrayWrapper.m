//
//  USArrayWrapper.m
//  Underscore
//
//  Created by Robert Böhnke on 5/13/12.
//  Copyright (C) 2012 Robert Böhnke
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "Underscore.h"

#import "USArrayWrapper.h"

@interface USArrayWrapper ()

- initWithArray:(NSArray *)array;

@property (readwrite, retain) NSArray *array;

@end

@implementation USArrayWrapper

#pragma mark Class methods

+ (USArrayWrapper *)wrap:(NSArray *)array;
{
    return [[USArrayWrapper alloc] initWithArray:[array copy]];
}

#pragma mark Lifecycle

- (id)init;
{
    return [super init];
}

- (id)initWithArray:(NSArray *)array;
{
    if (self = [super init]) {
        self.array = array;
    }
    return self;
}

@synthesize array = _array;

- (NSArray *)unwrap;
{
    return [self.array copy];
}

#pragma mark Underscore methods

- (id)first;
{
    return self.array.count ? [self.array objectAtIndex:0] : nil;
}

- (id)last;
{
    return self.array.lastObject;
}

- (USArrayWrapper *(^)(NSUInteger))head;
{
    return ^USArrayWrapper *(NSUInteger count) {
        NSRange    range     = NSMakeRange(0, MIN(self.array.count, count));
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
        NSArray    *result   = [self.array objectsAtIndexes:indexSet];

        return [[USArrayWrapper alloc] initWithArray:result];
    };
}

- (USArrayWrapper *(^)(NSUInteger))tail;
{
    return ^USArrayWrapper *(NSUInteger count) {
        NSRange range;
        if (count > self.array.count) {
            range = NSMakeRange(0, self.array.count);
        } else {
            range = NSMakeRange(self.array.count - count, count);
        }

        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
        NSArray    *result   = [self.array objectsAtIndexes:indexSet];

        return [[USArrayWrapper alloc] initWithArray:result];
    };
}

- (USArrayWrapper *)flatten;
{
    __block NSArray *(^flatten)(NSArray *) = ^NSArray *(NSArray *input) {
        NSMutableArray *result = [NSMutableArray array];

        for (id obj in input) {
            if ([obj isKindOfClass:[NSArray class]]) {
                [result addObjectsFromArray:flatten(obj)];
            } else {
                [result addObject:obj];
            }
        }

        return result;
    };

    return [USArrayWrapper wrap:flatten(self.array)];
}

- (USArrayWrapper *(^)(NSArray *))without;
{
    return ^USArrayWrapper *(NSArray *value) {
        return self.reject(^(id obj){
            return [value containsObject:obj];
        });
    };
}

- (USArrayWrapper *)shuffle;
{
    NSMutableArray *result = [self.array mutableCopy];

    for (NSInteger i = result.count - 1; i > 0; i--) {
        [result exchangeObjectAtIndex:arc4random() % (i + 1)
                    withObjectAtIndex:i];
    }

    return [[USArrayWrapper alloc] initWithArray:result];
}

- (id (^)(id, UnderscoreReduceBlock))reduce;
{
    return ^USArrayWrapper *(id memo, UnderscoreReduceBlock function) {
        for (id obj in self.array) {
            memo = function(memo, obj);
        }

        return memo;
    };
}

- (id (^)(id, UnderscoreReduceBlock))reduceRight;
{
    return ^USArrayWrapper *(id memo, UnderscoreReduceBlock function) {
        for (id obj in self.array.reverseObjectEnumerator) {
            memo = function(memo, obj);
        }

        return memo;
    };
}

- (USArrayWrapper *(^)(UnderscoreArrayIteratorBlock))each;
{
    return ^USArrayWrapper *(UnderscoreArrayIteratorBlock block) {
        // DISPATCH_QUEUE_CONCURRENT only works on OS X >= 10.7 / iOS 5
        dispatch_queue_t result_queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT);

        dispatch_apply(self.array.count, result_queue, ^(size_t i) {
            block([self.array objectAtIndex:i]);
        });

        dispatch_release(result_queue);

        return self;
    };
}

- (USArrayWrapper *(^)(UnderscoreArrayMapBlock))map;
{
    return ^USArrayWrapper *(UnderscoreArrayMapBlock block) {
        __block NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.array.count];
        dispatch_queue_t result_queue = dispatch_queue_create(NULL, NULL);

        dispatch_apply(self.array.count, result_queue, ^(size_t i) {
            [result addObject:block(i, [self.array objectAtIndex:i])];
        });

        dispatch_release(result_queue);

        return [[USArrayWrapper alloc] initWithArray:result];
    };
}

- (id (^)(UnderscoreTestBlock))find;
{
    return ^id (UnderscoreTestBlock test) {
        for (id obj in self.array) {
            if (test(obj)) {
                return obj;
            }
        }

        return nil;
    };
}

- (USArrayWrapper *(^)(UnderscoreTestBlock))filter;
{
    return ^USArrayWrapper *(UnderscoreTestBlock test) {
        return self.map(^id (id obj) {
            return test(obj) ? obj : nil;
        });
    };
}

- (USArrayWrapper *(^)(UnderscoreTestBlock))reject;
{
    return ^USArrayWrapper *(UnderscoreTestBlock test) {
        return self.filter(Underscore.negate(test));
    };
}

- (BOOL (^)(UnderscoreTestBlock))all;
{
    return ^BOOL (UnderscoreTestBlock test) {
        if (self.array.count == 0) {
            return NO;
        }

        BOOL result = YES;

        for (id obj in self.array) {
            if (!test(obj)) {
                return NO;
            }
        }

        return result;
    };
}

- (BOOL (^)(UnderscoreTestBlock))any;
{
    return ^BOOL (UnderscoreTestBlock test) {
        BOOL result = NO;

        for (id obj in self.array) {
            if (test(obj)) {
                return YES;
            }
        }

        return result;
    };
}

@end
