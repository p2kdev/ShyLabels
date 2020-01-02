#define kSBHomescreenDisplayChangedNotification @"SBHomescreenDisplayChangedNotification"

#import <SpringBoard/SBUserAgent.h>
@interface SpringBoard : NSObject
- (SBUserAgent *)pluginUserAgent;
@end

@interface SBIconListView : UIView
- (void)setIconsLabelAlpha:(double)alpha;
@end

@interface SBFolderView : UIView
@property (nonatomic, readonly) SBIconListView *currentIconListView;
@end

@interface SBFolderView (ShyLabels)
- (void)_subscribeToHomescreenDisplayChange;
- (void)_prepareHideLabels;
- (void)_hideLabels;
- (void)_showLabels;
- (void)_animateIconLabelsAlpha:(double)alpha;
@end


@interface SBRootFolderView : SBFolderView
@end
