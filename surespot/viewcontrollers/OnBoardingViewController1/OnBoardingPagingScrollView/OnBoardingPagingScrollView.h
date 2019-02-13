//
//  PagingScrollView.h
//  GoGet
//
//  Created by Gevorg Karapetyan on 2/14/16.
//  Copyright © 2016 Gevorg Karapetyan. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PagingScrollViewDelegate <NSObject>

- (void)imageDidScrollToPage:(NSInteger)currentPage;
- (void)openNextView;

@end

@interface OnBoardingPagingScrollView : UIView

@property (strong, nonatomic) UIScrollView *imageScrollView;
@property (strong, nonatomic) UIPageControl *pageControl;

@property (nonatomic) BOOL isCurrentPageChanged;

@property (nonatomic) NSUInteger numberOfPages;
@property(nonatomic) NSInteger currentPage;

//@property (nonatomic, strong) NSMutableArray *imagesArr;
//@property (nonatomic, strong) NSArray *contentArray;

@property (nonatomic, strong) NSMutableArray *onBoardingViewDataModelsArray;

//@property (nonatomic, strong) NSMutableArray *categoriesArray;

@property (nonatomic, strong) id<PagingScrollViewDelegate> pagingScrollViewDelegate;

//- (void)configureScrollViewWithImages:(NSArray*)imagesArray andContent:(NSArray*)contentArray;
- (void)configureScrollViewWithViewDataModelsArray:(NSArray*)onBoardingViewDataModelsArray;

- (void)scrollToPage:(NSUInteger)pageNumber;

@end
