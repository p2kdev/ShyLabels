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

/* This method shows the labels after unlock. Thus, it needs to be nuked.
   We also apply our own hide animation here. Another solution is to use
   kSBLockScreenManagerUnlockAnimationDidFinish, but then that would
   require to hook the init methods of SBRootFolderView, which is
   different on iOS 13 and 12.

   While the SBCoverSheetIconFlyInAnimator object itself has a property
   to the `iconListView`, the SBRootFolderView is used as it will use
   the same performSelector queue as when scrolling.

   The choices above seems to result in the most elegant solution. */
- (void)_cleanupAnimation {
    SBIconController *iconController = [%c(SBIconController) sharedInstance];
    SBRootFolderController *rootFolderController = iconController.rootFolderController;

    /* The 1.8f might seem like a magic number, but it was the measured
       time of the unlock animation from start to finish. It was measured
       from `SBBiometricEventLogger`'s method `_unlockAnimationWillStart`
       to this _cleanupAnimation call. */
    prepareHideLabelsWithDelay(rootFolderController.contentView, MAX(delay - 1.8f, 0));
}

%end

%hook SBFolderView

- (void)pageControl:(id)pageControl didReceiveTouchInDirection:(int)direction {
    %orig;
    prepareHideLabels(self);
}

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

    if (enabled)
        %init;
}
