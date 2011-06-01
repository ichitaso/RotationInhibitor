#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CaptainHook/CaptainHook.h>
#import <GraphicsServices/GraphicsServices.h>
#import <SpringBoard/SpringBoard.h>

#include <notify.h>

#define kSettingsChangeNotification "com.booleanmagic.rotationinhibitor.settingschange"
#define kSettingsFilePath "/User/Library/Preferences/com.booleanmagic.rotationinhibitor.plist"

#define IsOS4 (kCFCoreFoundationVersionNumber >= 478.61)

static BOOL rotationEnabled;

// OS 4.0

@interface SBOrientationLockManager : NSObject {
	int _override;
	int _lockedOrientation;
	int _overrideOrientation;
}
+ (id)sharedInstance;
- (void)lock:(int)lock;
- (void)unlock;
- (BOOL)isLocked;
- (int)lockOrientation;
- (void)setLockOverride:(int)override orientation:(int)orientation;
- (int)lockOverride;
- (void)updateLockOverrideForCurrentDeviceOrientation;
@end

@interface SBNowPlayingBar : NSObject {
	UIView *_containerView;
	UIButton *_orientationLockButton;
	UIButton *_prevButton;
	UIButton *_playButton;
	UIButton *_nextButton;
	SBIconLabel *_trackLabel;
	SBIconLabel *_orientationLabel;
	SBApplicationIcon *_nowPlayingIcon;
	SBApplication *_nowPlayingApp;
	int _scanDirection;
	BOOL _isPlaying;
	BOOL _isEnabled;
	BOOL _showingOrientationLabel;
}
- (void)_orientationLockHit:(id)sender;
- (void)_displayOrientationStatus:(BOOL)isLocked;
@end

@class SBNowPlayingBarMediaControlsView;
@interface SBNowPlayingBarView : UIView {
	UIView *_orientationLockContainer;
	UIButton *_orientationLockButton;
	UISlider *_brightnessSlider;
	UISlider *_volumeSlider;
	UIImageView *_brightnessImage;
	UIImageView *_volumeImage;
	SBNowPlayingBarMediaControlsView *_mediaView;
	SBApplicationIcon *_nowPlayingIcon;
}
@property(readonly, nonatomic) UIButton *orientationLockButton;
@property(readonly, nonatomic) UISlider *brightnessSlider;
@property(readonly, nonatomic) UISlider *volumeSlider;
@property(readonly, nonatomic) SBNowPlayingBarMediaControlsView *mediaView;
@property(retain, nonatomic) SBApplicationIcon *nowPlayingIcon;
@property(readonly, nonatomic) UIButton *airPlayButton;
- (void)_layoutForiPhone;
- (void)_layoutForiPad;
- (void)_orientationLockChanged:(id)sender;
- (void)showAudioRoutesPickerButton:(BOOL)button;
- (void)showVolume:(BOOL)volume;
@end

@class SBAppSwitcherModel, SBAppSwitcherBarView;
@interface SBAppSwitcherController : NSObject {
	SBAppSwitcherModel *_model;
	SBNowPlayingBar *_nowPlaying;
	SBAppSwitcherBarView *_bottomBar;
	SBApplicationIcon *_pushedIcon;
	BOOL _editing;
}
+ (id)sharedInstance;
+ (id)sharedInstanceIfAvailable;
@end

@interface SBNowPlayingBarView (iOS43)
@property (assign, nonatomic) NSInteger toggleType;
@property (readonly, assign, nonatomic) UIButton *toggleButton;
@end

@interface SpringBoard (OS40)
- (UIInterfaceOrientation)activeInterfaceOrientation;
@end

CHDeclareClass(SBOrientationLockManager)
CHDeclareClass(SBAppSwitcherController)

// 4.0-4.2

CHDeclareClass(SBNowPlayingBar)

CHOptimizedMethod(1, self, void, SBNowPlayingBar, _orientationLockHit, id, sender)
{
	SBOrientationLockManager *lockManager = CHSharedInstance(SBOrientationLockManager);
	NSString *labelText;
	BOOL isLocked = [lockManager isLocked];
	if (isLocked) {
		[lockManager unlock];
		if ([lockManager lockOverride])
			[lockManager setLockOverride:0 orientation:UIDeviceOrientationPortrait];
		labelText = @"Orientation Unlocked";
	} else {
		[lockManager lock:[(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation]];
		if ([lockManager lockOverride])
			[lockManager updateLockOverrideForCurrentDeviceOrientation];
		switch ([lockManager lockOrientation]) {
			case UIDeviceOrientationPortrait:
				labelText = @"Portrait Orientation Locked";
				break;
			case UIDeviceOrientationLandscapeLeft:
				labelText = @"Landscape Left Orientation Locked";
				break;
			case UIDeviceOrientationLandscapeRight:
				labelText = @"Landscape Right Orientation Locked";
				break;
			default:
				labelText = @"Upside Down Orientation Locked";
				break;
		}
	}
	SBNowPlayingBarView **nowPlayingBarView = CHIvarRef(self, _barView, SBNowPlayingBarView *);
	UIButton *orientationLockButton;
	if (nowPlayingBarView) {
		orientationLockButton = (*nowPlayingBarView).orientationLockButton;
	} else {
		orientationLockButton = CHIvar(self, _orientationLockButton, UIButton *);
		[self _displayOrientationStatus:isLocked];
		[CHIvar(self, _orientationLabel, UILabel *) setText:labelText];
	}
	orientationLockButton.selected = !isLocked;
}

// 4.3

CHOptimizedMethod(1, self, void, SBNowPlayingBar, _toggleButtonHit, id, sender)
{
	SBNowPlayingBarView **nowPlayingBarView = CHIvarRef(self, _barView, SBNowPlayingBarView *);
	if (!nowPlayingBarView || [*nowPlayingBarView toggleType] != 0) {
		CHSuper(1, SBNowPlayingBar, _toggleButtonHit, sender);
		return;
	}
	SBOrientationLockManager *lockManager = CHSharedInstance(SBOrientationLockManager);
	BOOL isLocked = [lockManager isLocked];
	if (isLocked) {
		[lockManager unlock];
		if ([lockManager lockOverride])
			[lockManager setLockOverride:0 orientation:UIDeviceOrientationPortrait];
	} else {
		[lockManager lock:[(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation]];
		if ([lockManager lockOverride])
			[lockManager updateLockOverrideForCurrentDeviceOrientation];
	}
	UIButton *orientationLockButton = (*nowPlayingBarView).toggleButton;
	orientationLockButton.selected = !isLocked;
}

#pragma mark Preferences

static void ReloadPreferences()
{
	NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:@kSettingsFilePath];
	rotationEnabled = [[dict objectForKey:@"RotationEnabled"] boolValue];
	[dict release];
}

#pragma mark SBSettings Toggle

BOOL isCapable()
{
	return YES;
}

BOOL isEnabled()
{
	if (IsOS4)
		return ![CHSharedInstance(SBOrientationLockManager) isLocked];
	else
		return rotationEnabled;
}

BOOL getStateFast()
{
	if (IsOS4)
		return ![CHSharedInstance(SBOrientationLockManager) isLocked];
	else
		return rotationEnabled;
}

float getDelayTime()
{
	return 0.0f;
}

void setState(BOOL enable)
{
	if (IsOS4) {
		SBOrientationLockManager *lockManager = CHSharedInstance(SBOrientationLockManager);
		if (enable) {
			[lockManager unlock];
			if ([lockManager lockOverride])
				[lockManager updateLockOverrideForCurrentDeviceOrientation];
		} else {
			[lockManager lock:[(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation]];
			if ([lockManager lockOverride])
				[lockManager setLockOverride:0 orientation:UIDeviceOrientationUnknown];
		}
		SBNowPlayingBar **nowPlayingBar = CHIvarRef([CHClass(SBAppSwitcherController) sharedInstanceIfAvailable], _nowPlaying, SBNowPlayingBar *);
		if (nowPlayingBar)
			[CHIvar(*nowPlayingBar, _orientationLockButton, UIButton *) setSelected:[lockManager isLocked]];
	} else {
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:@kSettingsFilePath];
		if (!dict)
			dict = [[NSMutableDictionary alloc] init];
		[dict setObject:[NSNumber numberWithBool:enable] forKey:@"RotationEnabled"];
		NSData *data = [NSPropertyListSerialization dataFromPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
		[dict release];
		[data writeToFile:@kSettingsFilePath options:NSAtomicWrite error:NULL];
		notify_post(kSettingsChangeNotification);
	}
}

void invokeHoldAction()
{
	SBOrientationLockManager *lockManager = CHSharedInstance(SBOrientationLockManager);
	if ([lockManager isLocked]) {
		switch ([lockManager lockOrientation]) {
			case UIInterfaceOrientationPortrait:
				[lockManager lock:UIInterfaceOrientationLandscapeLeft];
				break;
			case UIInterfaceOrientationLandscapeLeft:
				[lockManager lock:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? UIInterfaceOrientationPortraitUpsideDown : UIInterfaceOrientationLandscapeRight];
				break;
			case UIInterfaceOrientationPortraitUpsideDown:
				[lockManager lock:UIInterfaceOrientationLandscapeRight];
				break;
			case UIInterfaceOrientationLandscapeRight:
				[lockManager unlock];
				break;
		}
	} else {
		[lockManager lock:UIInterfaceOrientationPortrait];
	}
}

// OS 3.x

CHDeclareClass(UIApplication)

CHOptimizedMethod(2, self, void, UIApplication, handleEvent, GSEventRef, gsEvent, withNewEvent, UIEvent *, newEvent)
{
	if (gsEvent)
		if (GSEventGetType(gsEvent) == 50)
			if (!rotationEnabled)
				return;
	CHSuper(2, UIApplication, handleEvent, gsEvent, withNewEvent, newEvent);
}

CHConstructor
{
	if (IsOS4) {
		if (CHLoadLateClass(SBOrientationLockManager)) {
			CHLoadLateClass(SBAppSwitcherController);
			CHLoadLateClass(SBNowPlayingBar);
			CHHook(1, SBNowPlayingBar, _orientationLockHit);
			CHHook(1, SBNowPlayingBar, _toggleButtonHit);
		}
	} else {
		CHLoadLateClass(UIApplication);
		CHHook(2, UIApplication, handleEvent, withNewEvent);
		ReloadPreferences();
		CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			NULL,
			(void (*)(CFNotificationCenterRef, void *, CFStringRef, const void *, CFDictionaryRef))ReloadPreferences,
			CFSTR(kSettingsChangeNotification),
			NULL,
			CFNotificationSuspensionBehaviorHold
		);
	}
}

