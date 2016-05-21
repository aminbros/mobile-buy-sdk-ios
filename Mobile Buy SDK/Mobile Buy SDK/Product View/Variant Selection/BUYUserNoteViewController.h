//
//  BUYUserNoteViewController.h
//  Mobile Buy SDK
//
//  Created by Hossein Amin on 5/21/16.
//  Copyright © 2016 Shopify Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BUYUserNoteViewControllerDelegate;

@interface BUYUserNoteViewController : UIViewController

@property (nonatomic, retain) UITextView *textView;

@property (nonatomic, copy) NSString *initialNote;

@property (nonatomic, weak) id<BUYUserNoteViewControllerDelegate> delegate;

- (instancetype)initWithProduct:(BUYProduct *)product theme:(BUYTheme*)theme;

@end

@protocol BUYUserNoteViewControllerDelegate <NSObject>

- (void)userNoteViewControllerDone:(BUYUserNoteViewController*)userNoteViewController;
- (void)userNoteViewControllerCancel:(BUYUserNoteViewController*)userNoteViewController;

@end
