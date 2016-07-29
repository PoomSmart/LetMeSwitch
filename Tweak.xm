#import "../PS.h"
#import <substrate.h>

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

@interface _UIInputViewControllerState : NSObject
@end

@interface _UIInputViewControllerOutput : NSObject
@end

@protocol _UIIVCResponseDelegate <NSObject>
@required
- (void)_performInputViewControllerOutput:(_UIInputViewControllerOutput *)output;
@end

// Hax
@protocol _UIIVCResponseDelegate2 <NSObject>
@required
- (void)_performInputViewControllerOutput:(_UIInputViewControllerOutput *)output;
- (void)lms_getActiveInputModes:(id)arg1;
- (UIKeyboardInputMode *)lms_getCurrentInputMode:(id)arg1;
- (void)lms_setInputMode:(NSString *)identifier foo:(id)arg2;
@end

@protocol _UIIVCInterface <NSObject>
@required
- (void)_handleInputViewControllerState:(_UIInputViewControllerState *)state;
- (void)_tearDownRemoteService;
- (id <_UIIVCResponseDelegate>)responseDelegate;
- (void)setResponseDelegate:(id <_UIIVCResponseDelegate>)delegate;
@end

@interface UIInputViewControllerInterface : NSObject
@property (nonatomic, retain) id <_UIIVCInterface> forwardingInterface;
@property (nonatomic, retain) id <_UIIVCResponseDelegate> responseDelegate;
@end

@interface _UITextDocumentInterface : UIInputViewControllerInterface <UITextDocumentProxy>
- (_UIInputViewControllerOutput *)_controllerOutput;
- (void)_willPerformOutputOperation;
- (void)_didPerformOutputOperation;
- (void)setControllerOutput:(_UIInputViewControllerOutput *)output;
@end

@interface UIInputViewController (Private)
- (_UITextDocumentInterface *)_textDocumentInterface;
@end

@interface _UIInputViewControllerOutput (LetMeSwitch)
@property(assign, nonatomic) BOOL request;
@property(retain, nonatomic) NSString *identifier;
@end

%group Extension

static NSString *sheetTitle = nil;
static NSString *cancelTitle = nil;

extern "C" void _UIApplicationAssertForExtensionType(NSArray *);
MSHook(void, _UIApplicationAssertForExtensionType, NSArray *arg1)
{
	return;
}

%hook UIInputViewController

- (void)advanceToNextInputMode
{
	if (sheetTitle == nil)
		sheetTitle = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Alternate Keyboards" value:@"Alternate Keyboards" table:@"Localizable"];
	UIAlertController *sheet = [UIAlertController alertControllerWithTitle:sheetTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	_UITextDocumentInterface *interface = [self _textDocumentInterface];
	_UIInputViewControllerOutput *output = [interface _controllerOutput];
	for (UIKeyboardInputMode *inputMode in UIKeyboardInputModeController.sharedInputModeController.activeInputModes) {
		if ([inputMode isEqual:UIKeyboardInputModeController.sharedInputModeController.currentInputMode])
			continue;
		UIAlertAction *action = [UIAlertAction actionWithTitle:inputMode.displayName style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			NSString *identifier = inputMode.identifier;
			[interface _willPerformOutputOperation];
			output.identifier = identifier;
			output.request = YES;
			[interface _didPerformOutputOperation];
			[sheet dismissViewControllerAnimated:YES completion:nil];
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

%group App

%hook UIKeyboardImpl

- (void)_completePerformInputViewControllerOutput:(_UIInputViewControllerOutput *)output executionContext:(UIKeyboardTaskExecutionContext *)context
{
	if (output.request) {
		output.request = NO;
		NSString *identifier = output.identifier;
		if (identifier) {
			[(UIInputSwitcherView *)[objc_getClass("UIInputSwitcherView") sharedInstance] setInputMode:identifier];
			output.identifier = nil;
		}
	}
	%orig;
}

%end

%end

%group Transition

%hook _UIInputViewControllerOutput

%property(assign, nonatomic) BOOL request;
%property(retain, nonatomic) NSString *identifier;

- (_UIInputViewControllerOutput *)copyWithZone:(NSZone *)zone
{
	_UIInputViewControllerOutput *output = %orig;
	if (output) {
		output.request = self.request;
		output.identifier = self.identifier;
	}
	return output;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	%orig;
	[coder encodeBool:self.request forKey:@"request"];
	if (self.identifier)
		[coder encodeObject:self.identifier forKey:@"identifier"];
}

- (_UIInputViewControllerOutput *)initWithCoder:(NSCoder *)coder
{
	_UIInputViewControllerOutput *output = %orig;
	if (output) {
		output.request = [coder decodeBoolForKey:@"request"];
		output.identifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] retain];
	}
	return output;
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
			BOOL shouldTransition = NO;
			BOOL isExtensionOrApp = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
			if (isExtensionOrApp) {
				BOOL isExtension = [executablePath rangeOfString:@"appex"].location != NSNotFound;
				if (isExtension) {
					id val = NSBundle.mainBundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"];
					BOOL isKeyboardExtension = val ? [val isEqualToString:@"com.apple.keyboard-service"] : NO;
					if (isKeyboardExtension) {
						MSHookFunction(_UIApplicationAssertForExtensionType, MSHake(_UIApplicationAssertForExtensionType));
						%init(Extension);
						shouldTransition = YES;
					}
				} else {
					%init(App);
					shouldTransition = YES;
				}
			}
			if (shouldTransition) {
				%init(Transition);
			}
		}
	}
}