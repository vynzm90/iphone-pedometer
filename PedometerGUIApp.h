#import <UIKit/UIKit.h>
#import <UIKit/UISliderControl.h>

@interface PedometerGUIApp : UIApplication {
	UIWindow	*window;
	UITextLabel	*stepsView;
	UINavigationBar	*topNav;
	UINavigationBar	*bottomNav;
	Boolean		isRunning;
	UISliderControl	*bounceSlider;
}


@end
