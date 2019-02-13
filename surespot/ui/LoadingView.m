//
//  LoadingView.m
//  LoadingView
//

//  heavily Modified by surespot

//  Created by Matt Gallagher on 12/04/09.
//  Copyright Matt Gallagher 2009. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "LoadingView.h"
#import "LoadingView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIUtils.h"
#import "SurespotAppDelegate.h"
#import "AGWindowView.h"

@implementation LoadingView

//
// loadingViewInView:
//
// Constructor for this view. Creates and adds a loading view for covering the
// provided aSuperview.
//
// Parameters:
//    aSuperview - the superview that will be covered by the loading view
//
// returns the constructed view, already added as a subview of the aSuperview
//	(and hence retained by the superview)
//
+ (id) showViewKey: (NSString *) textKey
{
    
    AGWindowView * aSuperview = [[AGWindowView alloc] initAndAddToKeyWindow];
    aSuperview.supportedInterfaceOrientations = AGInterfaceOrientationMaskAll;
    CGRect frame =CGRectMake(0, 0, aSuperview.frame.size.width, aSuperview.frame.size.height);
	LoadingView *backgroundView =    [[LoadingView alloc] initWithFrame:frame];
	if (!backgroundView)
	{
		return nil;
	}
    
    
  //  UIWindow * aWindow =((SurespotAppDelegate *)[[UIApplication sharedApplication] delegate]).overlayWindow;
   // aWindow.userInteractionEnabled = YES;

	
    backgroundView.backgroundColor = [UIUtils surespotTransparentGrey];
	backgroundView.opaque = NO;
	backgroundView.autoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[aSuperview addSubviewAndFillBounds:backgroundView];
    
	const CGFloat DEFAULT_LABEL_WIDTH = [UIUtils screenSizeAdjustedForOrientation].width;
	const CGFloat sheight = [UIUtils screenSizeAdjustedForOrientation].height;
    
    UIView * labelView = [[UIView alloc] initWithFrame:CGRectZero];
    labelView.backgroundColor = [UIColor whiteColor];
    [backgroundView addSubview:labelView];
    
    
    UIImage * image =[UIImage imageNamed:@"surespot_logo.png"];
    UIImageView * imageView = [[UIImageView alloc] initWithImage: image];
    
	[labelView addSubview:imageView];
    
    imageView.autoresizingMask  = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingNone | UIViewAutoresizingFlexibleBottomMargin;

    CABasicAnimation *rotation;
    rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    rotation.fromValue = [NSNumber numberWithFloat:0];
    rotation.toValue = [NSNumber numberWithFloat:(2*M_PI)];
    rotation.duration = 1.1; // Speed
    rotation.repeatCount = HUGE_VALF; //
    [imageView.layer addAnimation:rotation forKey:@"spin"];
    
    
    
    
    UILabel *loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, DEFAULT_LABEL_WIDTH - imageView.bounds.size.width, 0)];
    
	loadingLabel.text = NSLocalizedString(textKey, nil);
    loadingLabel.numberOfLines = 0;
    loadingLabel.lineBreakMode = NSLineBreakByWordWrapping;
	loadingLabel.textColor = [UIColor blackColor];
	loadingLabel.backgroundColor = [UIColor clearColor];
	loadingLabel.textAlignment = NSTextAlignmentLeft;
	loadingLabel.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
	loadingLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingNone | UIViewAutoresizingFlexibleBottomMargin;;

    [loadingLabel sizeToFit];
	
	[labelView addSubview:loadingLabel];
    
    
	
    CGFloat totalHeight =  MAX(loadingLabel.frame.size.height ,imageView.frame.size.height);
    
	CGRect imageRect = imageView.frame;
	imageRect.origin.x = 5;
	imageRect.origin.y = 0;
	imageView.frame = imageRect;
    
    
    CGRect labelFrame =loadingLabel.frame;
    CGFloat labelOrigin =imageView.frame.origin.x + imageView.frame.size.width + 10;
    labelFrame.origin.x = labelOrigin;
	labelFrame.origin.y = 0;
    labelFrame.size.width = DEFAULT_LABEL_WIDTH - labelOrigin;
	loadingLabel.frame = labelFrame;
    
    CGRect viewFrame = CGRectMake(0, 0, DEFAULT_LABEL_WIDTH, totalHeight + 10);
    viewFrame.origin.y = sheight/2 - totalHeight;
    labelView.frame =viewFrame;
    
    
	
	// Set up the fade-in animation
	CATransition *animation = [CATransition animation];
	[animation setType:kCATransitionFade];
	[[aSuperview layer] addAnimation:animation forKey:@"layerAnimation"];
	
    [backgroundView layoutIfNeeded];
	return backgroundView;
}

//
// removeView
//
// Animates the view out from the superview. As the view is removed from the
// superview, it will be released.
//
- (void)removeView
{


	AGWindowView *aSuperview = [AGWindowView activeWindowViewContainingView:self];
    [aSuperview removeFromSuperview];
    
  //  UIWindow * aWindow =((SurespotAppDelegate *)[[UIApplication sharedApplication] delegate]).overlayWindow;
  //  aWindow.userInteractionEnabled = NO;
    
	// Set up the animation
	CATransition *animation = [CATransition animation];
	[animation setType:kCATransitionFade];
	
	[[aSuperview layer] addAnimation:animation forKey:@"layerAnimation"];
    
    
}




@end
