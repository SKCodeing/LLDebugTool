//
//  LLFunctionContainerView.m
//
//  Copyright (c) 2018 LLDebugTool Software Foundation (https://github.com/HDB-Li/LLDebugTool)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import "LLFunctionContainerView.h"
#import "UIView+LL_Utils.h"
#import "LLFunctionItemView.h"
#import "LLMacros.h"
#import "LLThemeManager.h"

@interface LLFunctionContainerView ()

@property (nonatomic, strong) NSMutableArray *itemViews;

@end

@implementation LLFunctionContainerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initial];
    }
    return self;
}

- (void)setDataArray:(NSArray<LLFunctionModel *> *)dataArray {
    if (_dataArray != dataArray) {
        _dataArray = dataArray;
        [self updateUI:dataArray];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    NSInteger count = 3;
    CGFloat itemWidth = self.LL_width / count;
    CGFloat itemHeight = 90;
    for (int i = 0; i < self.itemViews.count; i++) {
        NSInteger section = i / count;
        NSInteger row = i % count;
        LLFunctionItemView *view = self.itemViews[i];
        view.frame = CGRectMake(row * itemWidth, section * itemHeight, itemWidth, itemHeight);
    }
    self.LL_size = CGSizeMake(self.LL_width, [self LL_bottomView].LL_bottom);
}

#pragma mark - Primary
- (void)initial {
    self.backgroundColor = [LLThemeManager shared].containerColor;
    self.itemViews = [[NSMutableArray alloc] init];
    [self LL_setCornerRadius:5];
}

- (void)updateUI:(NSArray<LLFunctionModel *> *)dataArray {
    [self LL_removeAllSubviews];
    [self.itemViews removeAllObjects];
    for (int i = 0; i < dataArray.count; i++) {
        LLFunctionModel *model = dataArray[i];
        LLFunctionItemView *itemView = [[LLFunctionItemView alloc] initWithFrame:CGRectZero];
        [itemView LL_AddClickListener:self action:@selector(itemViewClicked:)];
        itemView.model = model;
        [self addSubview:itemView];
        [self.itemViews addObject:itemView];
    }
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)itemViewClicked:(UITapGestureRecognizer *)tap {
    UIView *view = tap.view;
    if ([view isKindOfClass:[LLFunctionItemView class]]) {
        LLFunctionItemView *itemView = (LLFunctionItemView *)view;
        [self.delegate llFunctionContainerView:self didSelectAt:itemView.model];
    }
}

@end
