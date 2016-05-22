#import "../PS.h"

@interface UIKeyboardImpl : NSObject
+ (UIKeyboardImpl *)sharedInstance;
+ (UIKeyboardImpl *)activeInstance;
- (BOOL)isMinimized;
- (void)recomputeActiveInputModesWithExtensions:(BOOL)extensions;
- (void)showKeyboard;
- (void)hideKeyboard;
- (void)toggleSoftwareKeyboard;
@end

@interface UIKeyboardMenuView : UIView
- (void)show;
- (void)showAsHUD;
@end

@interface UIInputSwitcherView : UIKeyboardMenuView
+ (UIInputSwitcherView *)sharedInstance;
+ (UIInputSwitcherView *)activeInstance;
- (void)setInputMode:(NSString *)identifer;
@end

@interface UIInputSwitcher : NSObject
+ (UIInputSwitcher *)sharedInstance;
+ (UIInputSwitcher *)activeInstance;
- (void)showSwitcher; // 9.0
- (void)showSwitcherShouldAutoHide:(BOOL)autoHide; // 9.1
@end

@interface UIKeyboardInputMode : NSObject
+ (UIKeyboardInputMode *)keyboardInputModeWithIdentifier:(NSString *)identifier;
@property(nonatomic, assign) NSString *identifier;
@property(nonatomic, assign) NSString *normalizedIdentifier;
@property(nonatomic, assign) NSString *primaryLanguage;
- (NSString *)displayName;
- (BOOL)isExtensionInputMode;
@end

@interface UIKeyboardInputModeController : NSObject
+ (UIKeyboardInputModeController *)sharedInputModeController;
@property(atomic, strong, readwrite) NSArray *normalizedInputModes;
@property(retain, nonatomic) UIKeyboardInputMode *lastUsedInputMode;
- (NSArray *)activeInputModes;
- (UIKeyboardInputMode *)currentInputMode;
- (UIKeyboardInputMode *)inputModeWithIdentifier:(NSString *)identifier;
- (void)switchToCurrentSystemInputMode;
@end

static UIAlertController *sheet;
static NSString *sheetTitle = nil;
static NSString *cancelTitle = nil;

%group Extension

extern "C" void _UIApplicationAssertForExtensionType(NSArray *);
MSHook(void, _UIApplicationAssertForExtensionType, NSArray *arg1)
{
	return;
}

%hook UIInputViewController

- (void)advanceToNextInputMode
{
	if (sheet)
		[sheet release];
	[UIKeyboardImpl.sharedInstance recomputeActiveInputModesWithExtensions:YES];
	if (sheetTitle == nil)
		sheetTitle = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Alternate Keyboards" value:@"Alternate Keyboards" table:@"Localizable"];
	sheet = [[UIAlertController alertControllerWithTitle:sheetTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet] retain];
	for (UIKeyboardInputMode *inputMode in UIKeyboardInputModeController.sharedInputModeController.activeInputModes) {
		if ([inputMode isEqual:UIKeyboardInputModeController.sharedInputModeController.currentInputMode])
			continue;
		UIAlertAction *action = [UIAlertAction actionWithTitle:inputMode.displayName style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[self dismissKeyboard];
			[(UIInputSwitcherView *)[objc_getClass("UIInputSwitcherView") sharedInstance] setInputMode:inputMode.identifier];
			[sheet dismissViewControllerAnimated:YES completion:^{
				[UIKeyboardImpl.sharedInstance showKeyboard];
			}];
		}];
		[sheet addAction:action];
	}
	if (cancelTitle == nil)
		cancelTitle = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Cancel" value:@"Cancel" table:@"Localizable"];
	UIAlertAction *cancel = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
		[sheet dismissViewControllerAnimated:YES completion:nil];
	}];
	[sheet addAction:cancel];
	[self presentViewController:sheet animated:YES completion:nil];
}

%end

%end

%ctor
{
	NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
	NSUInteger count = args.count;
	if (count != 0) {
		NSString *executablePath = args[0];
		if (executablePath) {
			BOOL isExtensionOrApp = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
			BOOL isExtension = isExtensionOrApp && [executablePath rangeOfString:@"appex"].location != NSNotFound;
			if (isExtension) {
				MSHookFunction(_UIApplicationAssertForExtensionType, MSHake(_UIApplicationAssertForExtensionType));
				%init(Extension);
			}
		}
	}
}