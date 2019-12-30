#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>

@interface ShyLabelsController : PSListController
@end

@interface ShyLabelsLogo : PSTableCell {
    UILabel *background;
    UILabel *tweakName;
    UILabel *version;
}
@end


@interface UIApplication (iOS10)
- (void)openURL:(NSURL *)URL options:(id)options completionHandler:(id)completionHandler;
@end
