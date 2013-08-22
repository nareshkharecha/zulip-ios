//
//  ZulipAPIController.h
//  Zulip
//
//  Created by Leonardo Franchi on 7/24/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "ZSubscription.h"
#import "NarrowOperators.h"
#import "UnreadManager.h"

@class StreamViewController;

/**
 This class is the entry point for making API requests to the Zulip API.

 It will add the desired data to Core Data, so to be notified of additions,
 use Core Data techniques.

 This class also takes care of long polling and translating long polling
 events into Core Data objects.
 */

// Notification for messages that are received via long polling
extern NSString * const kLongPollMessageNotification;
extern NSString * const kLongPollMessageData;

// Login and logout notifications
extern NSString * const kLogoutNotification;
extern NSString * const kLoginNotification;

// Callback with resulting RawMessage* from desired query
typedef void(^MessagesDelivered)(NSArray *messages);

@interface ZulipAPIController : NSObject

+ (ZulipAPIController *) sharedInstance;

- (void) login:(NSString *)email password:(NSString *)password result:(void (^) (bool success))result;
- (void) logout;

- (BOOL) loggedIn;
- (NSString *)domain;

- (UIColor *)streamColor:(NSString *)name withDefault:(UIColor *)defaultColor;

// Use this to fetch messagesd from **either** the db or zulip api around a certain anchor
- (void)loadMessagesAroundAnchor:(int)anchor before:(int)before after:(int)after withOperators:(NarrowOperators *)operators completionBlock:(MessagesDelivered)block;

// Use this to force a network request to fetch messages. They will be inserted in core data if the narrow is a Home View narrow
- (void) getOldMessages:(NSDictionary *)args narrow:(NarrowOperators *)narrow completionBlock:(MessagesDelivered)block;

- (void)sendMessageFlagsUpdated:(RawMessage *)message withOperation:(NSString *)operation andFlag:(NSString *)flag;

- (void)applicationWillTerminate;

@property(assign) long pointer;
@property(assign) BOOL backgrounded;
@property(assign) long maxServerMessageId;
@property(nonatomic, retain) NSString *email;
@property(nonatomic, retain) NSString *fullName;
@property(nonatomic, retain) StreamViewController *homeViewController;
@property(nonatomic, retain, readonly) UnreadManager *unreadManager;


@end