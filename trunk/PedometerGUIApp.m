#import "PedometerGUIApp.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define CMD_FETCH	1
#define CMD_RESET	2

@implementation PedometerGUIApp

- (BOOL)daemonCommand: (unsigned int)cmd returnedValue: (unsigned int *)ret
{
	int sock = socket( AF_INET, SOCK_STREAM, 0 );

	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	addr.sin_len = sizeof(addr);
	addr.sin_family = AF_INET;
	addr.sin_port = htons(12345);
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

	if( 0 != connect(sock, (const struct sockaddr *)&addr, sizeof(addr)) )
		return NO;

	if( sizeof(cmd) != write(sock, &cmd, sizeof(cmd)) )
		return NO;

	if( ret ) {
		if( sizeof(unsigned int) != read(sock,ret,sizeof(unsigned int)) )
			return NO;
	}

	close( sock );
	return YES;
}

- (void)executeCommand:(NSString *)cmd {
	NSString *output = [NSString string];
	FILE *pipe = popen([cmd cStringUsingEncoding: NSASCIIStringEncoding], "r");
	if (!pipe) return;
	char buf[1024];
	while(fgets(buf, 1024, pipe)) {
		output = [output stringByAppendingFormat: @"%s", buf];
	}
	pclose(pipe);
}

- (void)startPedometer
{
	[self executeCommand:@"/bin/launchctl start com.spiffytech.pedometer-daemon"];
}

- (void)stopPedometer
{
	[self executeCommand:@"/bin/launchctl stop com.spiffytech.pedometer-daemon"];
}

- (void)resetPedometer
{
	[self daemonCommand: CMD_RESET returnedValue: nil];
}

- (void)setPedometerStarted: (BOOL)b
{
	isRunning = b;
	if( b ) {
		[topNav showButtonsWithLeftTitle: @"Stop" rightTitle: @"Reset"];
	} else {
		[topNav showButtonsWithLeftTitle: @"Start" rightTitle: nil];
	}
}

- (void)navigationBar:(id)nav buttonClicked:(int)btn
{
	if( nav == bottomNav ) {
		[self openURL: [NSURL URLWithString: @"mailto:sean@spiffytech.com?subject=iPhone%20Pedometer%20Feedback"]];
	} else if( nav == topNav ) {
		if( btn == 1 ) {
			if( isRunning ) {
				[self stopPedometer];
			} else {
				[self startPedometer];
			}
		} else {
			[self resetPedometer];
		}
	}
}

- (void)pollDaemon
{
	unsigned int steps = 0;
	if( [self daemonCommand: CMD_FETCH returnedValue: &steps] ) {
		[self setPedometerStarted: YES];
		[stepsView setText:[NSString stringWithFormat:@"%d steps",steps]];
	} else {
		[self setPedometerStarted: NO];
		[stepsView setText:@"[ the pedometer is stopped ]"];
	}

	[self performSelector:@selector(pollDaemon) withObject:self afterDelay:0.25];
}

- (void)handleSlider7: (id) w { [stepsView setText: @"7"]; }
- (void)handleSlider15: (id) w { [stepsView setText: [NSString stringWithFormat:@"%f",[bounceSlider value]]]; }

- (void)applicationDidFinishLaunching: (id) unused
{
	isRunning = NO;

	float whiteColor[4] = {1,1,1,1};

	window = [[UIWindow alloc] initWithContentRect: [UIHardware fullScreenApplicationContentRect]];
	[window setBackgroundColor: CGColorCreate(CGColorSpaceCreateDeviceRGB(), whiteColor)];

	stepsView = [[UITextLabel alloc] initWithFrame:CGRectMake(0,70,320,40)];
	[stepsView setCentersHorizontally: YES];
	[window addSubview: stepsView];

	UITextLabel *msg = [[UITextLabel alloc] initWithFrame:CGRectMake(4,200,300,250)];
	[msg setText: @"The pedometer is still experimental, so keep that in mind. I'm working on implementing sensitivity adjustments and improving my step-detection algorithm. The pedometer now keeps counting even when you put your phone to sleep or switch to other apps."];
	[msg setWrapsText: YES];
	[window addSubview: msg];

	topNav = [[UINavigationBar alloc] initWithFrame: CGRectMake(0.0f, 0.0f, 320.0f, 48.0f)];
	[topNav setDelegate: self];
	[window addSubview: topNav];

	bottomNav = [[UINavigationBar alloc] initWithFrame: CGRectMake(0.0f, 412.0f, 320.0f, 48.0f)];
	[bottomNav setDelegate: self];
	[bottomNav showButtonsWithLeftTitle: nil rightTitle: @"Send Feedback"];
	[window addSubview: bottomNav];




	bounceSlider = [[UISliderControl alloc] initWithFrame: CGRectMake(40,150,240,0)];
	[bounceSlider setMaxValue:0.3f];
	[bounceSlider setMinValue:0.01f];
	[bounceSlider setShowValue:YES];
//	[bounceSlider setValue: 0.18];

//	[bounceSlider addTarget:self action:@selector(handleSlider15:) forEvents:48];

	[window addSubview: bounceSlider];







	[window orderFront: self];
	[window makeKey: self];

	[self pollDaemon];
}

@end
