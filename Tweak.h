@interface SBIconListView : UIView
- (void)setIconsLabelAlpha:(double)alpha;
@end

@interface SBFolderController : NSObject
@property (nonatomic, readonly) SBIconListView *currentIconListView;
@end

@interface SBRootFolderController : SBFolderController
@property (nonatomic, readonly) UIView *contentView;
@end

@interface SBIconController : NSObject
@property (getter=_rootFolderController, nonatomic, readonly) SBRootFolderController *rootFolderController;
+ (id)sharedInstance;
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


@interface SBIconView
@property (getter=isShowingContextMenu, nonatomic, readonly) BOOL showingContextMenu; 
- (void)setIconLabelAlpha:(double)alpha;
@end
