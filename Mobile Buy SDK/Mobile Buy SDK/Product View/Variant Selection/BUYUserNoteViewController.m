//
//  BUYVariantSelectionViewController.m
//  Mobile Buy SDK
//
//  Created by Shopify.
//  Copyright (c) 2015 Shopify Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "BUYImageKit.h"
#import "BUYPresentationControllerForVariantSelection.h"
#import "BUYProduct+Options.h"
#import "BUYProductVariant+Options.h"
#import "BUYTheme.h"
#import "BUYTheme+Additions.h"
#import "BUYVariantOptionBreadCrumbsView.h"
#import "BUYOption.h"
#import "BUYOptionSelectionNavigationController.h"
#import "BUYUserNoteViewController.h"

@interface BUYUserNoteViewController ()<UITextViewDelegate>

@property (nonatomic, strong) BUYProduct *product;
@property (nonatomic, weak) BUYTheme *theme;


@end

@implementation BUYUserNoteViewController

- (instancetype)initWithProduct:(BUYProduct *)product theme:(BUYTheme*)theme
{
	NSParameterAssert(product);
	
	self = [super init];
	
	if (self) {
		self.product = product;
		self.theme = theme;
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	// Add close button
	UIImage *closeButton = [[BUYImageKit imageOfVariantCloseImageWithFrame:CGRectMake(0, 0, 18, 20)] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	UIBarButtonItem *leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:closeButton style:UIBarButtonItemStylePlain target:self action:@selector(dismissPopover)];
	
	self.navigationItem.leftBarButtonItem = leftBarButtonItem;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didTapDone:)];
	self.title = @"Write a note";
	
	BUYOptionSelectionNavigationController *navigationController = (BUYOptionSelectionNavigationController*)self.navigationController;
	UIVisualEffectView *backgroundView = [(BUYPresentationControllerForVariantSelection*)navigationController.presentationController backgroundView];
	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPopover)];
	[backgroundView addGestureRecognizer:tapGestureRecognizer];
	
	
	self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
	self.textView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.textView.delegate =  self;
	self.textView.text = self.initialNote;
	[self.view addSubview:self.textView];
}

- (void)didTapDone:(id)sender {
	[self.delegate userNoteViewControllerDone:self];
}

- (void)dismissPopover
{
	[(BUYOptionSelectionNavigationController*)self.navigationController setDismissWithCancelAnimation:YES];
	[self.delegate userNoteViewControllerCancel:self];
}

- (void)textViewDidChange:(UITextView *)textView {
	if(textView.text.length == 0 && self.navigationItem.rightBarButtonItem.enabled)
		self.navigationItem.rightBarButtonItem.enabled = NO;
	else if(textView.text.length > 0 && !self.navigationItem.rightBarButtonItem.enabled)
		self.navigationItem.rightBarButtonItem.enabled = YES;
}

@end
