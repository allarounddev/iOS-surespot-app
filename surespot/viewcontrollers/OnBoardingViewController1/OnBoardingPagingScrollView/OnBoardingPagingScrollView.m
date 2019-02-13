//
//  PagingScrollView.m
//  GoGet
//
//  Created by Gevorg Karapetyan on 2/14/16.
//  Copyright © 2016 Gevorg Karapetyan. All rights reserved.
//

#import "OnBoardingPagingScrollView.h"
#import "OnBoardingSingleView.h"
#import "OnBoardingSingleViewDataModel.h"

#define SLIDER_VIEW_TAG 34252

@interface OnBoardingPagingScrollView() <UIScrollViewDelegate>

@end

@implementation OnBoardingPagingScrollView

- (void)configureScrollViewWithViewDataModelsArray:(NSArray*)onBoardingViewDataModelsArray
{
    _onBoardingViewDataModelsArray = [NSMutableArray arrayWithArray:onBoardingViewDataModelsArray];
    [self configureImageScrollView];
}

- (void)scrollToPage:(NSUInteger)pageNumber
{
    _pageControl.currentPage = pageNumber;
    CGRect frame = _imageScrollView.frame;
    frame.origin.x = frame.size.width * pageNumber;
    frame.origin.y = 0;
    [_imageScrollView scrollRectToVisible:frame animated:YES];
}


#pragma mark - ScrollView
- (void)configureImageScrollView
{
    
    _numberOfPages = _onBoardingViewDataModelsArray.count;
    
    for (UIView *view in _imageScrollView.subviews) {
        [view removeFromSuperview];
    }
    [self initScrollView];
    [self updateScrollView];
    [self changePage: nil];
}

- (void)initScrollView
{
    // view controllers are created lazily in the meantime, load the array with
    // placeholders which will be replaced on demand
    
    if(!_imageScrollView) {
        _imageScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [self addSubview:_imageScrollView];
    }
    // a page is the width of the scroll view
    _imageScrollView.pagingEnabled = YES;
    _imageScrollView.contentSize = CGSizeMake(_imageScrollView.frame.size.width * _numberOfPages, _imageScrollView.frame.size.height);
    _imageScrollView.showsHorizontalScrollIndicator = NO;
    _imageScrollView.showsVerticalScrollIndicator = NO;
    _imageScrollView.scrollsToTop = NO;
    _imageScrollView.delegate = self;
    _imageScrollView.bounces = NO;
    
    //    mPageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 430, 320, 50)];
    //    pageControl.center = CGPointMake(160.0f, 430.0f);
    if(!_pageControl) {
        _pageControl = [[UIPageControl alloc] init];
        [self addSubview:_pageControl];
    }
    
    [_pageControl setCurrentPageIndicatorTintColor:[UIColor whiteColor]];
    _pageControl.numberOfPages = _numberOfPages;
    _pageControl.currentPage = 0;
//    _pageControl.hidden = YES;
    
    [_pageControl setFrame:CGRectMake((self.frame.size.width - 20 * _numberOfPages ) /2, self.frame.size.height - 147, _numberOfPages * 20, 37)];
    
    //    UIImage *image = [UIImage imageNamed:@"heart_button.png"];
    //    UIGraphicsBeginImageContext( CGSizeMake(_pageControl.frame.size.width, _pageControl.frame.size.height) );
    //    [image drawInRect:CGRectMake(0,0,_pageControl.frame.size.width,_pageControl.frame.size.height)];
    //    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    //    UIGraphicsEndImageContext();
    //
    //    [_pageControl setBackgroundColor:[UIColor colorWithPatternImage:newImage]];
    
    [_pageControl addTarget:self action:@selector(changePage:) forControlEvents:UIControlEventValueChanged];
    
    [self loadScrollViewWithPage:_pageControl.currentPage];
    [self loadScrollViewWithPage:_pageControl.currentPage+1];
    
}

- (void)updateScrollView
{
    if (_numberOfPages < _pageControl.numberOfPages)
    {
        _imageScrollView.contentSize = CGSizeMake(_imageScrollView.frame.size.width * _numberOfPages, _imageScrollView.frame.size.height);
        _imageScrollView.contentOffset = CGPointMake(_imageScrollView.frame.size.width * (_numberOfPages-1), 0);
        _pageControl.currentPage = _numberOfPages-1;
        [self loadScrollViewWithPage:_pageControl.currentPage-1];
        [self loadScrollViewWithPage:_pageControl.currentPage];
        [self loadScrollViewWithPage:_pageControl.currentPage+1];
    } else {
        if (_numberOfPages > _pageControl.numberOfPages) {
            _numberOfPages = _pageControl.numberOfPages;
            [self initScrollView];
        } else {
            
            
            [self loadScrollViewWithPage:_pageControl.currentPage-1];
            [self loadScrollViewWithPage:_pageControl.currentPage];
            [self loadScrollViewWithPage:_pageControl.currentPage+1];
        }
    }
}

- (void)loadScrollViewWithPage:(NSInteger)page
{
    if(page < 0 || page >= _pageControl.numberOfPages) {
        return;
    }
    
    OnBoardingSingleView *onBoardingSingleView = (OnBoardingSingleView*)[_imageScrollView viewWithTag:page+SLIDER_VIEW_TAG];
    
    if(!onBoardingSingleView) {
        CGRect frame = _imageScrollView.frame;
        frame.origin.x = frame.size.width * page;
        frame.origin.y = 0;
        
        onBoardingSingleView = [[OnBoardingSingleView alloc] initOnBoardingSingleViewWithFrame:frame];
        onBoardingSingleView.userInteractionEnabled = YES;
        onBoardingSingleView.frame = frame;
        [onBoardingSingleView layoutSubviews];
        [onBoardingSingleView layoutIfNeeded];
        
        [onBoardingSingleView setTag:page + SLIDER_VIEW_TAG];
        [onBoardingSingleView.actionButton setTag:page + SLIDER_VIEW_TAG];
        // add the controller's view to the scroll view
        //    add image view
        
        
        
        if(page < [_onBoardingViewDataModelsArray count] && [_onBoardingViewDataModelsArray count]) {
//            NSString *imageName = [_imagesArr objectAtIndex:page];
//            [sliderImageView setImage:[UIImage imageNamed:imageName]];
//            [sliderImageView sd_setImageWithURL:[NSURL URLWithString:imageURL] placeholderImage:nil];
            
            
            [_imageScrollView addSubview:onBoardingSingleView];
        }
    }
    
    OnBoardingSingleViewDataModel *onBoardingSingleViewDataModel = [_onBoardingViewDataModelsArray objectAtIndex:page];
    
    [onBoardingSingleView.actionButton addTarget:self action:@selector(actionButtonDidSelected:) forControlEvents:UIControlEventTouchDown];
    
    [onBoardingSingleView configureForOnBoardingSingleViewDataModel:onBoardingSingleViewDataModel];
    
    [_imageScrollView setIndicatorStyle:UIScrollViewIndicatorStyleDefault];
}

- (void)actionButtonDidSelected:(UIButton*)actionButton
{
    OnBoardingSingleViewDataModel *onBoardingSingleViewDataModel = [_onBoardingViewDataModelsArray objectAtIndex:actionButton.tag - SLIDER_VIEW_TAG];
    if(actionButton.tag - SLIDER_VIEW_TAG < [_onBoardingViewDataModelsArray count] - 1) {
        [self scrollToPage:actionButton.tag - SLIDER_VIEW_TAG + 1];
    } else  if(actionButton.tag - SLIDER_VIEW_TAG == [_onBoardingViewDataModelsArray count] - 1) {
        if([_pagingScrollViewDelegate respondsToSelector:@selector(openNextView)]) {
            [_pagingScrollViewDelegate openNextView];
        }
    }
    
}

- (IBAction)changePage:(id)sender
{
    UIPageControl *pager = sender;
    NSInteger page = pager.currentPage;
    if(page < 0 || page >= _pageControl.numberOfPages) {
        return;
    }
    _pageControl.currentPage = page;
    CGRect frame = _imageScrollView.frame;
    frame.origin.x = frame.size.width * page;
    frame.origin.y = 0;
    [_imageScrollView scrollRectToVisible:frame animated:YES];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if(scrollView != _imageScrollView) {
        return;
    }
    
    CGFloat pageWidth = scrollView.frame.size.width;
    int page = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    
    if(page < 0 || page >= _pageControl.numberOfPages) {
        return;
    }
    
    _pageControl.currentPage = page;
    [self scrollSlider];
    if([_pagingScrollViewDelegate respondsToSelector:@selector(imageDidScrollToPage:)]) {
        [_pagingScrollViewDelegate imageDidScrollToPage:_pageControl.currentPage];
    }
}
- (void)scrollSlider
{
    [self loadScrollViewWithPage:_pageControl.currentPage - 1];
    [self loadScrollViewWithPage:_pageControl.currentPage];
    [self loadScrollViewWithPage:_pageControl.currentPage + 1];
}

@end
