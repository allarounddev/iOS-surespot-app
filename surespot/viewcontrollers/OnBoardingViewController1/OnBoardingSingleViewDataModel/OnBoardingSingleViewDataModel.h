//
//  OnBoardingSingleViewDataModel.h
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OnBoardingSingleViewDataModel : NSObject

@property (nonatomic, strong) NSString *descriptionLogoImageName;
@property (weak, nonatomic) NSString *onBoardingSingleViewDescriptionTitle;
@property (weak, nonatomic) NSString *onBoardingSingleViewDescription;
@property (weak, nonatomic) NSString *actionName;
@property (nonatomic, strong) UIColor *actionViewColor;

@end
