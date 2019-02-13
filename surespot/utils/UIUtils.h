//
//  UIUtils.h
//  surespot
//
//  Created by Adam on 11/1/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"
#import "REMenu.h"
#import "TTTAttributedLabel.h"

@interface UIUtils : NSObject
+ (void) showToastKey: (NSString *) key;
+ (void) showToastKey: (NSString *) key duration: (CGFloat) duration;
+ (CGSize)threadSafeSizeString: (NSString *) string WithFont:(UIFont *)font constrainedToSize:(CGSize)size;
+ (UIColor *) surespotBlue;
+(UIColor *) surespotSelectionBlue;
+(UIColor *) surespotSeparatorGrey;
+(UIColor *) surespotTransparentBlue;
+ (void)setAppAppearances;
+ (BOOL)stringIsNilOrEmpty:(NSString*)aString;
+(CGFloat) keyboardHeightAdjustedForOrientation: (CGSize) size;
+(UIColor *) surespotGrey;
+(UIColor *) surespotTransparentGrey;
+(void) setTextMessageHeights: (SurespotMessage *)  message size: (CGSize) size;
+(void) setImageMessageHeights: (SurespotMessage *)  message size: (CGSize) size;
+(void) setVoiceMessageHeights: (SurespotMessage *)  message size: (CGSize) size;
+(void) startSpinAnimation: (UIView *) view;
+(void) stopSpinAnimation: (UIView *) view;
+(void) startPulseAnimation: (UIView *) view;
+(void) stopPulseAnimation: (UIView *) view;
+(void) showToastMessage: (NSString *) message duration: (CGFloat) duration;
+(NSString *) getMessageErrorText: (NSInteger) errorStatus mimeType: (NSString *) mimeType;
+(REMenu *) createMenu: (NSArray *) menuItems closeCompletionHandler: (void (^)(void))completionHandler;
+(CGSize) screenSizeAdjustedForOrientation;
+(CGSize) sizeAdjustedForOrientation: (CGSize) size;
+(void) setLinkLabel:(TTTAttributedLabel *) label
            delegate: (id) delegate
           labelText: (NSString *) labelText
      linkMatchTexts: (NSArray *) linkMatchTexts
          urlStrings: (NSArray *) urlStrings;
+(BOOL) getBoolPrefWithDefaultYesForUser: (NSString *) username key:(NSString *) key;
+(void) clearLocalCache;
+(NSInteger) getDefaultImageMessageHeight;
+(CGSize)imageSizeAfterAspectFit:(UIImageView*)imgview;
+ (NSString *) buildAliasStringForUsername: (NSString *) username alias: (NSString *) alias;
+ (BOOL) isIOS8Plus;
@end

