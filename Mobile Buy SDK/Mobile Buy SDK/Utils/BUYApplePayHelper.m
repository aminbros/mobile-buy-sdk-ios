//
//  BUYApplePayHelper.m
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

#import "BUYApplePayHelper.h"
#import "BUYAddress.h"
#import "BUYApplePayAdditions.h"
#import "BUYClient+Checkout.h"
#import "BUYClient+Storefront.h"
#import "BUYCheckout.h"
#import "BUYError.h"
#import "BUYModelManager.h"
#import "BUYShop.h"
#import "BUYShopifyErrorCodes.h"
#import "BUYApplePayToken.h"

typedef void (^BUYApplePayShippingRatesCompletion)(PKPaymentAuthorizationStatus status, NSArray<BUYShippingRate *> *shippingRates, NSArray<PKPaymentSummaryItem *> *summaryItems);

@interface BUYApplePayHelper ()

@property (nonatomic, strong) BUYCheckout *checkout;
@property (nonatomic, strong) BUYClient *client;

@property (nonatomic, strong) NSArray *shippingRates;
@property (nonatomic, strong) NSError *lastError;

@property (nonatomic, strong) BUYShop *shop;

@end

@implementation BUYApplePayHelper

- (instancetype)initWithClient:(BUYClient *)client checkout:(BUYCheckout *)checkout
{
	return [self initWithClient:client checkout:checkout shop:nil];
}

- (instancetype)initWithClient:(BUYClient *)client checkout:(BUYCheckout *)checkout shop:(BUYShop *)shop
{
	NSParameterAssert(client);
	NSParameterAssert(checkout);
	
	self = [super init];
	
	if (self) {
		self.client = client;
		self.checkout = checkout;
		
		// We need a shop object to display the business name in the pay sheet
		if (shop) {
			self.shop = shop;
		}
		else {
			[self.client getShop:^(BUYShop *shop, NSError *error) {
				
				if (shop) {
					self.shop = shop;
				}
			}];
		}
	}
	
	return self;
}


#pragma mark - PKPaymentAuthorizationDelegate methods

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
					   didAuthorizePayment:(PKPayment *)payment
								completion:(void (^)(PKPaymentAuthorizationStatus status))completion
{
	// Update the checkout with the rest of the information. Apple has now provided us with a FULL billing address and a FULL shipping address.
	// We now update the checkout with our new found data so that you can ship the products to the right address, and we collect whatever else we need.	
	if ([payment respondsToSelector:@selector(shippingContact)]) {
		self.checkout.email = payment.shippingContact.emailAddress;
		if (self.checkout.requiresShipping) {
			self.checkout.shippingAddress = [self buyAddressWithContact:payment.shippingContact];
		}
	} else {
		self.checkout.email = [BUYAddress buy_emailFromRecord:payment.shippingAddress];
		if (self.checkout.requiresShipping) {
			self.checkout.shippingAddress = [self buyAddressWithABRecord:payment.shippingAddress];
		}
	}

	if ([payment respondsToSelector:@selector(billingContact)]) {
		self.checkout.billingAddress = [self buyAddressWithContact:payment.billingContact];
	} else {
		self.checkout.billingAddress = [self buyAddressWithABRecord:payment.billingAddress];
	}
	
	[self.client updateCheckout:self.checkout completion:^(BUYCheckout *checkout, NSError *error) {
		if (checkout && error == nil) {
			self.checkout = checkout;
			
			id<BUYPaymentToken> token = [[BUYApplePayToken alloc] initWithPaymentToken:payment.token];
			
			//Now that the checkout is up to date, call complete.
			[self.client completeCheckout:checkout paymentToken:token completion:^(BUYCheckout *checkout, NSError *error) {
				if (checkout) {
					self.checkout = checkout;
					completion(PKPaymentAuthorizationStatusSuccess);
				} else {
					self.lastError = error;
					completion(PKPaymentAuthorizationStatusFailure);
				}
			}];
		}
		else {
			self.lastError = error;
			completion(PKPaymentAuthorizationStatusInvalidShippingPostalAddress);
		}
	}];
}

- (BUYAddress *)buyAddressWithABRecord:(ABRecordRef)addressRecord
{
	return [self.client.modelManager buyAddressWithABRecord:addressRecord];
}

- (BUYAddress *)buyAddressWithContact:(PKContact *)contact
{
	return [self.client.modelManager buyAddressWithContact:contact];
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller
{
	[controller dismissViewControllerAnimated:YES completion:nil];
}

-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingAddress:(ABRecordRef)address completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion
{
	self.checkout.shippingAddress = [self buyAddressWithABRecord:address];
	[self updateCheckoutWithAddressCompletion:completion];
}

-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingContact:(PKContact *)contact completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion
{
	self.checkout.shippingAddress = [self buyAddressWithContact:contact];
	[self updateCheckoutWithAddressCompletion:completion];
}

-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectShippingMethod:(PKShippingMethod *)shippingMethod completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion
{
	BUYShippingRate *shippingRate = [self rateForShippingMethod:shippingMethod];
	self.checkout.shippingRate = shippingRate;
	
	[self.client updateCheckout:self.checkout completion:^(BUYCheckout *checkout, NSError *error) {
		if (checkout && error == nil) {
			self.checkout = checkout;
		}
		else {
			self.lastError = error;
		}
		completion(error == nil ? PKPaymentAuthorizationStatusSuccess : PKPaymentAuthorizationStatusFailure, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
	}];
}

#pragma mark -

- (void)updateCheckoutWithAddressCompletion:(BUYApplePayShippingRatesCompletion)completion
{
	// This method call is internal to selection of shipping address that are returned as partial from PKPaymentAuthorizationViewController
	// However, to ensure we never set partialAddresses to NO, we want to guard the setter. Should PKPaymentAuthorizationViewController ever
	// return a full address through it's delegate method, this will still function since a complete address can be used to calculate shipping rates
	if ([self.checkout.shippingAddress isPartialAddress] == YES) {
		self.checkout.partialAddresses = @YES;
	}
	
	if ([self.checkout.shippingAddress isValidAddressForShippingRates]) {
		
		[self.client updateCheckout:self.checkout completion:^(BUYCheckout *checkout, NSError *error) {
			if (checkout && error == nil) {
				self.checkout = checkout;
				
				if (checkout.requiresShipping) {
					
					[self fetchShippingRates:^(PKPaymentAuthorizationStatus status, NSArray<BUYShippingRate *> *shippingRates, NSArray<PKPaymentSummaryItem *> *summaryItems) {
						NSArray *shippingMethods = [BUYShippingRate buy_convertShippingRatesToShippingMethods:_shippingRates];
						if ([shippingMethods count] > 0) {
							[self selectShippingMethod:shippingMethods[0] completion:^(BUYCheckout *checkout, NSError *error) {
								if (checkout && error == nil) {
									self.checkout = checkout;
								}
								completion(error ? PKPaymentAuthorizationStatusFailure : PKPaymentAuthorizationStatusSuccess, shippingMethods, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
							}];
							
						} else {
							self.lastError = [NSError errorWithDomain:BUYShopifyError code:BUYShopifyError_NoShippingMethodsToAddress userInfo:nil];
							completion(status, nil, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
						}
					}];
					
				} else {
					completion(PKPaymentAuthorizationStatusSuccess, nil, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
				}
			}
			else {
				self.lastError = error;
				completion(PKPaymentAuthorizationStatusInvalidShippingPostalAddress, nil, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
			}
		}];
	}
	else {
		completion(PKPaymentAuthorizationStatusInvalidShippingPostalAddress, nil, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
	}
}

- (void)updateAndCompleteCheckoutWithPayment:(PKPayment *)payment completion:(void (^)(PKPaymentAuthorizationStatus status))completion
{
	// Since we're deprecating this method and the controller is not used in the delegate method, we can pass in a not-null PKPaymentAuthorizationViewController
	[self paymentAuthorizationViewController:[PKPaymentAuthorizationViewController new] didAuthorizePayment:payment completion:completion];
}

- (void)updateCheckoutWithShippingMethod:(PKShippingMethod *)shippingMethod completion:(void (^)(PKPaymentAuthorizationStatus status, NSArray *methods))completion
{
	// Since we're deprecating this method and the controller is not used in the delegate method, we can pass in a not-null PKPaymentAuthorizationViewController
	[self paymentAuthorizationViewController:[PKPaymentAuthorizationViewController new] didSelectShippingMethod:shippingMethod completion:completion];
}

- (void)updateCheckoutWithAddress:(ABRecordRef)address completion:(void (^)(PKPaymentAuthorizationStatus status, NSArray *shippingMethods, NSArray *summaryItems))completion
{
	// Since we're deprecating this method and the controller is not used in the delegate method, we can pass in a not-null PKPaymentAuthorizationViewController
	[self paymentAuthorizationViewController:[PKPaymentAuthorizationViewController new] didSelectShippingAddress:address completion:completion];
}

- (void)updateCheckoutWithContact:(PKContact*)contact completion:(void (^)(PKPaymentAuthorizationStatus status, NSArray *shippingMethods, NSArray *summaryItems))completion
{
	// Since we're deprecating this method and the controller is not used in the delegate method, we can pass in a not-null PKPaymentAuthorizationViewController
	[self paymentAuthorizationViewController:[PKPaymentAuthorizationViewController new] didSelectShippingContact:contact completion:completion];
}

#pragma mark - internal

- (BUYShippingRate *)rateForShippingMethod:(PKShippingMethod *)method
{
	BUYShippingRate *rate = nil;
	NSString *identifier = [method identifier];
	for (BUYShippingRate *method in _shippingRates) {
		if ([[method shippingRateIdentifier] isEqual:identifier]) {
			rate = method;
			break;
		}
	}
	return rate;
}

- (void)fetchShippingRates:(BUYApplePayShippingRatesCompletion)completion
{
	// Fetch shipping rates. This may take several seconds to get back from our shipping providers. You have to poll here.
	self.shippingRates = @[];
	
	[self.client getShippingRatesForCheckout:self.checkout completion:^(NSArray *shippingRates, BUYStatus status, NSError *error) {

		if (error) {
			completion(PKPaymentAuthorizationStatusInvalidShippingPostalAddress, nil, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
			
		} else if (status == BUYStatusComplete) {
			self.shippingRates = shippingRates;
			
			if ([self.shippingRates count] == 0) {
				// Shipping address is not supported and no shipping rates were returned
				if (completion) {
					completion(PKPaymentAuthorizationStatusInvalidShippingPostalAddress, nil, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
				}
			} else {
				if (completion) {
					completion(PKPaymentAuthorizationStatusSuccess, self.shippingRates, [self.checkout buy_summaryItemsWithShopName:self.shop.name]);
				}
			}
			
		}
	}];
}

- (void)selectShippingMethod:(PKShippingMethod *)shippingMethod completion:(BUYDataCheckoutBlock)block
{
	BUYShippingRate *shippingRate = [self rateForShippingMethod:shippingMethod];
	self.checkout.shippingRate = shippingRate;
	
	[self.client updateCheckout:self.checkout completion:block];
}

@end

@implementation BUYModelManager (ApplePay)


- (BUYAddress *)buyAddressWithABRecord:(ABRecordRef)addressRecord
{
	BUYAddress *address = [self insertAddressWithJSONDictionary:nil];
	[address updateWithRecord:addressRecord];
	return address;
}

- (BUYAddress *)buyAddressWithContact:(PKContact *)contact
{
	BUYAddress *address = [self insertAddressWithJSONDictionary:nil];
	[address updateWithContact:contact];
	return address;
}

@end