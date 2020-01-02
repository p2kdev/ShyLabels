#import "Tweak.h"

static BOOL isDragging;
static BOOL enabled;
static double delay;


static BOOL isDeviceLocked() {
    SpringBoard *springBoard = (SpringBoard *)[%c(SpringBoard) sharedApplication];
    return [[springBoard pluginUserAgent] deviceIsLocked];   
}

static void animateIconLabelAlpha(double alpha) {
    SBIconController *iconController = [%c(SBIconController) sharedInstance];
    SBRootFolderController *rootFolderController = [iconController _rootFolderController];
    SBIconListView *listView = rootFolderController.currentIconListView;

    [UIView animateWithDuration:0.5 animations:^{
        [listView setIconsLabelAlpha:alpha];
    }];
}

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
            [self _prepareHideLabels];
        });
    }
}

%end

%hook SBFolderView

- (void)pageControl:(id)pageControl didRecieveTouchInDirection:(int)direction {
    %orig;
    [self _prepareHideLabels];
}

- (void)scrollViewDidEndDragging:(id)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    [self _prepareHideLabels];
}

- (void)scrollViewWillBeginDragging:(id)scrollView {
    %orig;
    isDragging = YES;
    [self _showLabels];
}

%new
- (void)_prepareHideLabels {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideLabels) object:nil];
    [self performSelector:@selector(_hideLabels) withObject:nil afterDelay:delay];
}

%new
- (void)_hideLabels {
    animateIconLabelAlpha(0);
    isDragging = NO;
}

%new
- (void)_showLabels {
    animateIconLabelAlpha(1);
}

%end

// ===== PREFERENCE HANDLING ===== //
static void loadPrefs() {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.noisyflake.shylabels.plist"];

    if (prefs) {
        enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
        delay = prefs[@"delay"] ? [prefs[@"delay"] doubleValue] : 1.0;
    }
}

static void initPrefs() {
    // Copy the default preferences file when the actual preference file doesn't exist
    NSString *path = @"/User/Library/Preferences/com.noisyflake.shylabels.plist";
    NSString *pathDefault = @"/Library/PreferenceBundles/ShyLabels.bundle/defaults.plist";
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path])
        [fileManager copyItemAtPath:pathDefault toPath:path error:nil];
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    (CFNotificationCallback)loadPrefs,
                                    CFSTR("com.noisyflake.shylabels/prefsupdated"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
    initPrefs();
    loadPrefs();

    if (enabled) {
        if ([%c(SBRootFolderView) instancesRespondToSelector:@selector(initWithConfiguration:)])
            %init(iOS13);
        else if ([%c(SBRootFolderView) instancesRespondToSelector:@selector(initWithFolder:orientation:viewMap:forSnapshot:)])
            %init(iOS12);
        %init;
    }
}
