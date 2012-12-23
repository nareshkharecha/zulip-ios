#import "FirstViewController.h"
#import "HumbugAppDelegate.h"
#import "ComposeViewController.h"

@implementation StreamViewController
@synthesize listData;
@synthesize messageCell = _messageCell;
@synthesize first, last;
@synthesize gravatars;
@synthesize delegate;
@synthesize lastRequestTime;
@synthesize waitingOnErrorRecovery;
@synthesize timeWhenBackgrounded;

- (id)initWithStyle:(UITableViewStyle)style
{
    return [super initWithStyle:style];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:@"Humbug"];
    self.first = -1;
    self.last = -1;
    self.backoff = 0;
    self.lastRequestTime = 0;
    self.backgrounded = FALSE;
    self.pollingStarted = FALSE;
    self.waitingOnErrorRecovery = FALSE;
    self.listData = [[NSMutableArray alloc] init];
    self.gravatars = [[NSMutableDictionary alloc] init];
    self.delegate = (HumbugAppDelegate *)[UIApplication sharedApplication].delegate;
    
    UIImage *composeButtonImage = [UIImage imageNamed:@"glyphicons_355_bullhorn.png"];
    UIButton *composeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composeButton setImage:composeButtonImage forState:UIControlStateNormal];
    composeButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40,
                                     composeButtonImage.size.height);
    [composeButton addTarget:self action:@selector(composeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposeButton = [[UIBarButtonItem alloc] initWithCustomView:composeButton];
    [[self navigationItem] setRightBarButtonItem:uiBarComposeButton];
    [composeButton release];
    
    UIImage *composePMButtonImage = [UIImage imageNamed:@"glyphicons_003_user.png"];
    UIButton *composePMButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composePMButton setImage:composePMButtonImage forState:UIControlStateNormal];
    composePMButton.frame = CGRectMake(0.0, 0.0, composeButtonImage.size.width + 40,
                                       composeButtonImage.size.height);
    [composePMButton addTarget:self action:@selector(composePMButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *uiBarComposePMButton = [[UIBarButtonItem alloc] initWithCustomView:composePMButton];
    [[self navigationItem] setLeftBarButtonItem:uiBarComposePMButton];
    [composePMButton release];
    [uiBarComposePMButton release];
}

- (void)viewDidAppear:(BOOL)animated
{
    // This function gets called whenever the stream view appears, including returning to the view after popping another view. We only want to backfill old messages on the very first load.
    [self initialPopulate];
}

- (void)initialPopulate
{
    if (self.last == -1) {
        dispatch_queue_t downloadQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(downloadQueue, ^{

            if ([self initializePointer] != TRUE) {
                [self.delegate showErrorScreen:self.view
                                  errorMessage:@"Unable to fetch messages. Please try again in a few minutes."];
            }
            NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInteger:6], @"num_before",
                                   [NSNumber numberWithInteger:0], @"num_after",
                                   nil];
            [self getOldMessages:args];
        });
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(NSInteger)tableView:(UITableView *)tableView
numberOfRowsInSection:(NSInteger)section
{
    return [self.listData count];
}

- (UIImage *)getGravatar:(NSString *)gravatarHash
{
    UIImage *gravatar = [self.gravatars objectForKey:gravatarHash];
    if (gravatar != nil) {
        return gravatar;
    }

    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:
                                                       [NSString stringWithFormat:
                                                        @"https://secure.gravatar.com/avatar/%@?d=identicon&s=30",
                                                        gravatarHash]]];
    gravatar = [UIImage imageWithData:imageData];
    [self.gravatars setObject:gravatar forKey:gravatarHash];

    return gravatar;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    MessageCell *my_cell = (MessageCell *)cell;
    if ([my_cell.type isEqualToString:@"stream"]) {
        my_cell.headerBar.backgroundColor = [UIColor colorWithRed:187.0/255
                                                            green:187.0/255
                                                             blue:187.0/255
                                                            alpha:1];
    } else {
        // For non-stream messages, color cell background pale yellow (#FEFFE0).
        my_cell.backgroundColor = [UIColor colorWithRed:255.0/255 green:254.0/255
                                                   blue:224.0/255 alpha:1];
        my_cell.headerBar.backgroundColor = [UIColor colorWithRed:51.0/255
                                                            green:51.0/255
                                                             blue:51.0/255
                                                            alpha:1];
        my_cell.header.textColor = [UIColor whiteColor];
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView
        cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger row = [indexPath row];
    NSDictionary *dict = [listData objectAtIndex:row];

    MessageCell *cell = (MessageCell *)[self.tableView dequeueReusableCellWithIdentifier:
                                        [MessageCell reuseIdentifier]];
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"MessageCellView" owner:self options:nil];
        cell = _messageCell;
        _messageCell = nil;
    }

    cell.type = [dict objectForKey:@"type"];
    if ([cell.type isEqualToString:@"stream"]) {
        cell.header.text = [NSString stringWithFormat:@"%@ | %@",
                            [dict objectForKey:@"display_recipient"],
                            [dict objectForKey:@"subject"]];
    } else if ([cell.type isEqualToString:@"private"]) {
        NSArray *recipients = [dict objectForKey:@"display_recipient"];
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (NSDictionary *recipient in recipients) {
            if (![[recipient valueForKey:@"email"] isEqualToString:self.delegate.email]) {
                [recipient_array addObject:[recipient objectForKey:@"full_name"]];
            }
        }
        cell.header.text = [@"You and " stringByAppendingString:[recipient_array componentsJoinedByString:@", "]];
    }

    cell.sender.text = [dict objectForKey:@"sender_full_name"];
    cell.content.text = [dict objectForKey:@"content"];
    // Allow multi-line content.
    cell.content.lineBreakMode = UILineBreakModeWordWrap;
    cell.content.numberOfLines = 0;

    cell.gravatar.image = [self getGravatar:[dict objectForKey:@"gravatar_hash"]];

    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]
                              autorelease]];
    [dateFormatter setDateFormat:@"HH:mm"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:
                    [[dict objectForKey:@"timestamp"] doubleValue]];
    cell.timestamp.text = [dateFormatter stringFromDate:date];

    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellText = [[self.listData objectAtIndex:indexPath.row] valueForKey:@"content"];
    UIFont *cellFont = [UIFont systemFontOfSize:12];
    CGSize constraintSize = CGSizeMake(262.0, CGFLOAT_MAX); // content width from xib = 267.
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];

    // Full cell height of 77 - default content height of 36 = 41. + a little bit of bottom padding.
    return fmax(77.0, labelSize.height + 45);
}

- (void) adjustRequestBackoff
{
    if (self.backoff > 4) {
        return;
    }

    if (self.backoff == 0) {
        self.backoff = .5;
    } else {
        self.backoff *= 2;
    }
    self.backoff = 10;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                          initWithNibName:@"ComposeViewController"
                                          bundle:nil];

    NSDictionary *dict = [listData objectAtIndex:indexPath.row];
    composeView.type = [dict objectForKey:@"type"];
    [[self navigationController] pushViewController:composeView animated:YES];

    if ([[dict objectForKey:@"type"] isEqualToString:@"stream"]) {
        composeView.recipient.text = [dict valueForKey:@"display_recipient"];
        [composeView.subject setHidden:NO];
        composeView.subject.text = [dict valueForKey:@"subject"];
    } else if ([[dict objectForKey:@"type"] isEqualToString:@"private"]) {
        [composeView.subject setHidden:YES];

        NSArray *recipients = [dict objectForKey:@"display_recipient"];
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];
        for (NSDictionary *recipient in recipients) {
            if (![[recipient valueForKey:@"email"] isEqualToString:self.delegate.email]) {
                [recipient_array addObject:[recipient valueForKey:@"email"]];
            }
        }
        composeView.privateRecipient.text = [recipient_array componentsJoinedByString:@", "];
    }

    [composeView release];
}

- (NSDictionary *) makeJSONMessagesPOST:(NSString *)resource_path
                             postFields:(NSMutableDictionary *)postFields
{
    NSHTTPURLResponse *response = nil;
    NSData *data;

    while (([[NSDate date] timeIntervalSince1970] - self.lastRequestTime) < self.backoff) {
        [NSThread sleepForTimeInterval:.5];
    }

    data = [self.delegate makePOST:&response resource_path:resource_path postFields:postFields useAPICredentials:TRUE];

    self.lastRequestTime = [[NSDate date] timeIntervalSince1970];

    if ([response statusCode] == 500) {
        // The service is having problems; possibly indicate this to the user and back off requests.
        [self adjustRequestBackoff];
        if (self.waitingOnErrorRecovery == FALSE) {
            self.waitingOnErrorRecovery = TRUE;
            [self.delegate showErrorScreen:self.view
                              errorMessage:@"Error getting messages. Please try again in a few minutes."];
        }
    } else {
        self.waitingOnErrorRecovery = FALSE;
        self.backoff = 0;
    }

    if (!data) {
        // Sometimes we get no data back. I'm not sure why.
        return nil;
    }

    NSError *e = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData: data
                                                             options: NSJSONReadingMutableContainers
                                                               error: &e];
    if (!jsonDict) {
        NSLog(@"Error parsing JSON: %@", e);
    }

    if ([response statusCode] == 400) {
        NSLog(@"Forbidden: %@", jsonDict);
    }
    return jsonDict;
}

- (void) dataReceived: (NSDictionary*) messageData {
    if (!messageData) {
        return;
    }
    
    BOOL backfill = FALSE;
    if ([self.listData count] == 0) {
        backfill = TRUE;
    }

    for (NSDictionary *item in [messageData objectForKey:@"messages"]) {
        int message_id = [[item objectForKey:@"id"] intValue];

        NSArray *newIndexPaths = [NSArray arrayWithObjects:
                                  [NSIndexPath indexPathForRow:[self.listData count]
                                                     inSection:0], nil];
        [self.listData addObject: item];

        [self.tableView insertRowsAtIndexPaths:newIndexPaths
                              withRowAnimation:UITableViewRowAnimationTop];
        self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 200.0, 0.0);

        if (message_id < self.first) {
            self.first = message_id;
        }
        if (message_id > self.last) {
            self.last = message_id;
        }
    }
    
    if (backfill && [self.listData count]) {
        // If we are backfilling old messages, these are messages you've necessarily already
        // seen that are just being fetched as context, so scroll to the bottom of them.
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath
                                                indexPathForRow:[self.listData count] - 1
                                                inSection:0]
                              atScrollPosition:UITableViewScrollPositionMiddle
                                      animated:NO];
    }
}

- (void) getOldMessages: (NSDictionary *)args {
    int anchor = [[args objectForKey:@"anchor"] integerValue];
    if (!anchor) {
        anchor = self.last;
    }
    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       [NSString stringWithFormat:@"%i", anchor], @"anchor",
                                       [NSString stringWithFormat:@"%i",
                                        [[args objectForKey:@"num_before"] integerValue]], @"num_before",
                                       [NSString stringWithFormat:@"%i",
                                        [[args objectForKey:@"num_after"] integerValue]], @"num_after",
                                       [NSDictionary dictionary], @"narrow", nil];

    NSDictionary *messageData = [self makeJSONMessagesPOST:@"get_old_messages"
                                                postFields:postFields];

    int old_count = [self.listData count];
    [self performSelectorOnMainThread:@selector(dataReceived:)
                           withObject:messageData waitUntilDone:YES];

    if (old_count != [self.listData count]) {
        // There are still historical messages to fetch.
        NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithInteger:self.last + 1], @"anchor",
                               [NSNumber numberWithInteger:0], @"num_before",
                               [NSNumber numberWithInteger:20], @"num_after",
                               nil];
        [self performSelectorInBackground:@selector(getOldMessages:) withObject:args];
    } else {
        self.backgrounded = FALSE;
        if (!self.pollingStarted) {
            self.pollingStarted = TRUE;
            [self startPoll];
        }
    }
}

- (void) longPoll {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       [NSString stringWithFormat:@"%i", self.first], @"first",
                                       [NSString stringWithFormat:@"%i", self.last], @"last",
                                       [NSDictionary dictionary], @"narrow", nil];
    NSDictionary *pollingResponseData = [self makeJSONMessagesPOST:@"get_messages"
                                                        postFields:postFields];

    if (!self.backgrounded) {
        [self performSelectorOnMainThread:@selector(dataReceived:)
                               withObject:pollingResponseData waitUntilDone:YES];
    }

    [pool drain];

    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}

- (void) startPoll {
    [self performSelectorInBackground:@selector(longPoll) withObject: nil];
}

- (void) updatePointer {
    [self.tableView visibleCells];
    if ([self.listData count] == 0) {
        return;
    }
    NSIndexPath *indexPath = [self.tableView indexPathForCell:
                              [self.tableView.visibleCells objectAtIndex:0]];
    NSUInteger lastIndex = [indexPath indexAtPosition:[indexPath length] - 1];
    MessageCell *pointedCell = [self.listData objectAtIndex:lastIndex];

    NSMutableDictionary *postFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       [pointedCell valueForKey:@"id"], @"pointer", nil];
    [self makeJSONMessagesPOST:@"update_pointer" postFields:postFields];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self performSelectorInBackground:@selector(updatePointer) withObject: nil];
}

- (int) fetchPointer
{
    NSMutableDictionary *postFields = [NSMutableDictionary dictionary];
    NSDictionary *resultDict = [self makeJSONMessagesPOST:@"get_profile" postFields:postFields];
    
    if (!resultDict) {
        return FALSE;
    }
    
    return [[resultDict objectForKey:@"pointer"] intValue];
}

- (BOOL) initializePointer
{
    NSMutableDictionary *postFields = [NSMutableDictionary dictionary];
    NSDictionary *resultDict = [self makeJSONMessagesPOST:@"get_profile" postFields:postFields];

    if (!resultDict) {
        return FALSE;
    }

    int pointer = [[resultDict objectForKey:@"pointer"] intValue];
    self.first = pointer;
    self.last = pointer;

    if (self.first < 0) {
        self.first = 0;
    }
    if (self.last < 0) {
        self.last = 0;
    }

    self.delegate.clientID = [resultDict objectForKey:@"client_id"];
    return TRUE;
}

-(void)composeButtonPressed {
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                    initWithNibName:@"ComposeViewController"
                                    bundle:nil];
    composeView.type = @"stream";
    [[self navigationController] pushViewController:composeView animated:YES];
    [composeView release];
}

-(void)composePMButtonPressed {
    ComposeViewController *composeView = [[ComposeViewController alloc]
                                     initWithNibName:@"ComposeViewController"
                                     bundle:nil];
    composeView.type = @"private";
    [[self navigationController] pushViewController:composeView animated:YES];
    [composeView release];
}

-(int) rowWithId: (int)messageId
{
    int i = 0;
    for (i = 0; i < [self.listData count]; i++) {
        if ([[self.listData[i] objectForKey:@"id"] intValue] == messageId) {
            return i;
        }
    }
    return FALSE;
}

-(void)reset {
    int pointer = [self fetchPointer];

    if ((pointer != FALSE) && (pointer != -1)) {
        int pointerRowNum = [self rowWithId:pointer];
        if (pointerRowNum) {
            // If the pointer is already in our table, but not visible, scroll to it
            // but don't try to clear and refetch messages.
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath
                                                    indexPathForRow:pointerRowNum
                                                    inSection:0]
                                    atScrollPosition:UITableViewScrollPositionMiddle
                                            animated:NO];
            self.backgrounded = FALSE;
            return;
        }
    }

    // If the pointer has moved because messages were consumed on another device, clear
    // the list and re-populate it.
    [self.listData removeAllObjects];
    self.first = -1;
    self.last = -1;
    [self initialPopulate];
}

@end