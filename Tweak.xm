#import "Tweak.h"

static BOOL enabled;
static double delay;


static BOOL isDeviceLocked() {
    SpringBoard *springBoard = (SpringBoard *)[%c(SpringBoard) sharedApplication];
    return [[springBoard pluginUserAgent] deviceIsLocked];   
}

static void animateIconListViewLabelsAlpha(SBIconListView *listView, double alpha) {
    [UIView animateWithDuration:0.5 animations:^{
        [listView setIconsLabelAlpha:alpha];
    }];
}

static void prepareHideLabels(id self) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideLabels) object:nil];
    [self performSelector:@selector(_hideLabels) withObject:nil afterDelay:delay];
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

%hook SBRootFolderView

/* iOS 12 and earlier */
%group iOS12
- (id)initWithFolder:(id)arg1 orientation:(long long)arg2 viewMap:(id)arg3 forSnapshot:(BOOL)arg4 {
    self = %orig;
    [self _subscribeToHomescreenDisplayChange];
    return self;
}
%end

/* iOS 13 */
%group iOS13
- (id)initWithConfiguration:(id)configuration {
    self = %orig;
    [self _subscribeToHomescreenDisplayChange];
    return self;
}
%end

%new

%new
- (void)_subscribeToHomescreenDisplayChange {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_displayChanged:)
                                                 name:kSBHomescreenDisplayChangedNotification
                                               object:nil];
}

/* This is called when leaving or entering the homescreen */
%new
- (void)_displayChanged:(NSNotification *)notification {
    if (!isDeviceLocked()) {
        /* This is not perfect, but the labels are made visible on iOS 13
           shortly before this delay by iOS itself. Hence, using anything
           lower than 1.5 s causes it to dim and then shortly after being
           visible again. Inspective-C is not supporting iOS 13, so nuking
           the method that makes them visible is not easily done. */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, MAX(1.5, delay) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            prepareHideLabels(self);
        });
    }
}

%end

%hook SBFolderView

- (void)pageControl:(id)pageControl didRecieveTouchInDirection:(int)direction {
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
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    (CFNotificationCallback)loadPrefs,
                                    CFSTR("se.nosskirneh.shylabels/prefsupdated"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
    initPrefs();

    if (enabled) {
        if ([%c(SBFolderView) instancesRespondToSelector:@selector(initWithConfiguration:)])
            %init(iOS13);
        else if ([%c(SBFolderView) instancesRespondToSelector:@selector(initWithFolder:orientation:viewMap:forSnapshot:)])
            %init(iOS12);
        %init;
    }
}
