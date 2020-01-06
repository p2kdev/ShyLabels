#import "Tweak.h"

static BOOL enabled;
static double delay;


static void animateIconListViewLabelsAlpha(SBIconListView *listView, double alpha) {
    [UIView animateWithDuration:0.5 animations:^{
        [listView setIconsLabelAlpha:alpha];
    }];
}

static void prepareHideLabelsWithDelay(id self, double _delay) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideLabels) object:nil];
    [self performSelector:@selector(_hideLabels) withObject:nil afterDelay:_delay];
}

static void prepareHideLabels(id self) {
    prepareHideLabelsWithDelay(self, delay);
}

/* Label are becoming visible after dismissing the force touch context
   menu. This prevents that. */
%group iOS13
%hook SBIconView

- (void)setIconLabelAlpha:(double)alpha {
    if (self.showingContextMenu)
        return;
    %orig;
}

%end
%end

%hook SBFolderController

- (void)folderControllerDidOpen:(id)folderController {
    %orig;
    prepareHideLabels(self);
}

%new
- (void)_hideLabels {
    animateIconListViewLabelsAlpha(self.currentIconListView, 0.0f);
}

%end

%hook SBCoverSheetIconFlyInAnimator

/* This method shows the labels after unlock. Our own hide animation
   is applied here.

   While the SBCoverSheetIconFlyInAnimator object itself has a property
   to the `iconListView`, the SBRootFolderView is used as it will use
   the same performSelector queue as when scrolling.

   This seems to result in the most elegant solution. */
- (void)_cleanupAnimation {
    %orig;
    /* The 1.8f might seem like a magic number, but it was the measured
       time of the unlock animation from start to finish. It was measured
       from `SBBiometricEventLogger`'s method `_unlockAnimationWillStart`
       to this call. */
    SBIconController *iconController = [%c(SBIconController) sharedInstance];
    prepareHideLabelsWithDelay(iconController.rootFolderController.contentView, MAX(delay - 1.8f, 0));
}

%end

%hook SBFolderView

/* Lul, Apple did a spelling mistake in iOS 12 and corrected it in iOS 13. */
%group didRecieve
- (void)pageControl:(id)pageControl didRecieveTouchInDirection:(int)direction {
    %orig;
    prepareHideLabels(self);
}
%end

%group didReceive
- (void)pageControl:(id)pageControl didReceiveTouchInDirection:(int)direction {
    %orig;
    prepareHideLabels(self);
}
%end

- (void)scrollViewDidEndDragging:(id)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    prepareHideLabels(self);
}

- (void)scrollViewWillBeginDragging:(id)scrollView {
    %orig;
    [self _showLabels];
}

%new
- (void)_hideLabels {
    animateIconListViewLabelsAlpha(self.currentIconListView, 0.0f);
}

%new
- (void)_showLabels {
    animateIconListViewLabelsAlpha(self.currentIconListView, 1.0f);
}

%end

// ===== PREFERENCE HANDLING ===== //
static void loadPrefs() {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/se.nosskirneh.shylabels.plist"];

    if (prefs) {
        enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
        delay = prefs[@"delay"] ? [prefs[@"delay"] doubleValue] : 1.0;
    }
}

static void initPrefs() {
    // Copy the default preferences file when the actual preference file doesn't exist
    NSString *path = @"/User/Library/Preferences/se.nosskirneh.shylabels.plist";
    NSString *pathDefault = @"/Library/PreferenceBundles/ShyLabels.bundle/defaults.plist";
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path])
        [fileManager copyItemAtPath:pathDefault toPath:path error:nil];

    loadPrefs();
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)loadPrefs,
                                    CFSTR("se.nosskirneh.shylabels/prefsupdated"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
    initPrefs();

    if (enabled) {
        %init;

        if ([%c(SBFolderView) instancesRespondToSelector:@selector(pageControl:didRecieveTouchInDirection:)])
            %init(didRecieve);
        else
            %init(didReceive);

        if (@available(iOS 13, *))
            %init(iOS13);
    }
}
