//
//  BUYTableViewCell.m
//  Mobile Buy SDK
//
//  Created by Hossein Amin on 5/21/16.
//  Copyright © 2016 Shopify Inc. All rights reserved.
//

#import "BUYTUserNoteCell.h"
#import "BUYTheme.h"
#import "BUYTheme+Additions.h"
#import "BUYImageKit.h"

@interface BUYTUserNoteCell ()

@property (nonatomic, strong) BUYTheme *theme;
@end

@implementation BUYTUserNoteCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		self.layoutMargins = UIEdgeInsetsMake(kBuyPaddingMedium, self.layoutMargins.left, kBuyPaddingMedium, self.layoutMargins.right);
		[self.textLabel setFont:[BUYTheme variantOptionValueFont]];
		self.textLabel.textColor = self.tintColor;
	}
	
	return self;
}

- (void)setTheme:(BUYTheme *)theme
{
	_theme = theme;
	self.backgroundColor = [theme backgroundColor];
	self.selectedBackgroundView.backgroundColor = [theme selectedBackgroundColor];
	self.textLabel.textColor = [theme variantOptionNameTextColor];

	UIImage *image = [BUYImageKit imageOfDisclosureIndicatorImageWithFrame:CGRectMake(0, 0, 10.0, 16) color:[theme disclosureIndicatorColor]];
	self.accessoryView = [[UIImageView alloc] initWithImage:image];
}

- (void)tintColorDidChange {
	[super tintColorDidChange];
	self.textLabel.textColor = self.tintColor;
}

@end
