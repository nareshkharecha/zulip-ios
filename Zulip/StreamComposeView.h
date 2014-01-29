//
//  StreamComposeView.h
//  Zulip
//
//  Created by Michael Walker on 1/3/14.
//
//

#import <UIKit/UIKit.h>

@class RawMessage;
@class ComposeAutocompleteView;
@class ZUser;

@interface StreamComposeView : UIView

@property (readonly) CGFloat visibleHeight;

@property (strong, nonatomic) NSString *defaultRecipient;
@property (assign, nonatomic) BOOL isPrivate;
@property (strong, nonatomic) ComposeAutocompleteView *autocompleteView;

- (id)initWithAutocompleteView:(ComposeAutocompleteView *)autocompleteView;

- (void)showComposeViewForMessage:(RawMessage *)message;
- (void)showComposeViewForUser:(ZUser *)message;

- (void)showSubjectBar;
- (void)hideSubjectBar;

@end
