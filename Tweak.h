#define kSBHomescreenDisplayChangedNotification @"SBHomescreenDisplayChangedNotification"

#import <SpringBoard/SBUserAgent.h>
@interface SpringBoard : NSObject
- (SBUserAgent *)pluginUserAgent;
@end

@interface SBIconListView : UIView
- (void)setIconsLabelAlpha:(double)alpha;
@end

@interface SBRootIconListView : SBIconListView
@end

@interface SBFolderController : UIViewController
@end

@interface SBRootFolderController : SBFolderController
@property (nonatomic, readonly) SBIconListView *currentIconListView;
@end

@interface SBIconController : NSObject
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
@end

@interface SBRootFolderView : UIView
@end

@interface SBRootFolderView (ShyLabels)
- (void)_subscribeToHomescreenDisplayChange;
- (void)_prepareHideLabels;
- (void)_hideLabels;
- (void)_showLabels;
@end
