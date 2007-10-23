#import <UIKit/UIKit.h>
#import <IOKit/IOKitLib.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/types.h>
#import <sys/socket.h>
#import <netinet/in.h>

double lastx = 0;
double lasty = 0;
double lastz = 0;
unsigned int steps = 0;
NSTimeInterval lastStep;
int listenSocket;
int connectedSocket;
int watchDog;
float lastdot = 1;

#define trainingLen 100
double training[trainingLen];
unsigned int trainingPos = 0;




void resetSteps()
{
	lastStep = [NSDate timeIntervalSinceReferenceDate];
	steps = 0;
	lastdot = 0;
}

void sendSteps()
{
	if( connectedSocket )
		write( connectedSocket, &steps, sizeof(steps) );
}

void handleNetworking()
{
	struct timeval timeout;
	timeout.tv_sec = 0;
	timeout.tv_usec = 0;
	struct sockaddr who;
	unsigned int len = sizeof(who);
	int newSock = accept( listenSocket, &who, &len );
	if( newSock > 0 ) {
		// only allow one connection at a time.. it's just easier that way
		if( connectedSocket )
			close(connectedSocket);
		connectedSocket = newSock;
	}

	if( connectedSocket ) {
		int cmd = 0;
		int len = read( connectedSocket, &cmd, sizeof(cmd) );
		if( len == 0 ) {
			close( connectedSocket );
			connectedSocket = 0;
		} else if( len == sizeof(cmd) ) {
			if( cmd == 1 )
				sendSteps();
			else if( cmd == 2 )
				resetSteps();
			// ignore all other unknown commands at this time... :)
		}
	}
}

double getSteps( double bVar, unsigned int tVar ) {
	unsigned int i;
	double recordedSteps = 0;
	double score = 0;
	unsigned int timer = tVar / 2;
	for( i=0; i<trainingLen; i++ ) {
		if( timer >= tVar ) {
			score += training[i];
			if( score >= bVar && score <= bVar*1.5 ) {
				recordedSteps++;
				timer = 0;
			}
		}
		timer++;
	}
	return recordedSteps;
}

unsigned int timeSkipper = 0;
unsigned int timeToSkip = 0;
double magicDelta = 0;


void changeInXYZ( float x, float y, float z )
{
	watchDog++;
	handleNetworking();

	const float speedFACTOR = 0.35;		// speed = timer..  lower number = more polling = faster movement
	const float bounceFACTOR = 0.16;		// higher bounce threshold means it takes more motion to count as a step

	// normalize the vector
	double dist = sqrtf( (x*x) + (y*y) + (z*z) );
	if( dist == 0 ) dist = 1;	// avoid div by zero - just in case :)
	x /= dist;
	y /= dist;
	z /= dist;

	// find the angle between this one and the last one
	// (dot product)
	double dot = (x*lastx) + (y*lasty) + (z*lastz);
	dot = fabs(dot);
	//NSLog(@"dot = %f", dot );

	double diff = fabs(lastdot - dot);

	if( magicDelta ) {

		if( timeSkipper == timeToSkip ) {
			if( diff >= magicDelta && diff <= magicDelta*1.5 ) {
				NSLog(@"step");
				timeSkipper = 0;
			}
		} else {
			timeSkipper++;
		}

	} else if( trainingPos+1 == trainingLen ) {
		// do magic...
		NSLog(@"done");

		unsigned int givenSteps = 12;

		double varA = 0;
		double varB = 100;
		double timeA = trainingLen / (givenSteps*2.5);
		double timeB = trainingLen / (givenSteps/2.5);

		int attempts = 100;
		while( attempts-- ) {
			double stepsA = getSteps( varA, timeA );
			double stepsB = getSteps( varB, timeA );

			double stepsC = getSteps( varA, timeB );
			double stepsD = getSteps( varB, timeB );

			double deltaA = fabs(givenSteps - stepsA);
			double deltaB = fabs(givenSteps - stepsB);
			double deltaC = fabs(givenSteps - stepsC);
			double deltaD = fabs(givenSteps - stepsD);

			double newVar1 = varA + ((varB - varA) * 0.6);
			double newVar2 = timeA + ((timeB - timeA) * 0.6);

			if( attempts % 2 == 0 ) {
				if( deltaB < deltaA && stepsB <= givenSteps ) {
					NSLog(@"B wins with %g steps and a delta of %g newVar = %g", stepsB,deltaB,newVar1);
					varA = newVar1;
				} else {
					NSLog(@"A wins with %g steps and a delta of %g newVar = %g", stepsA,deltaA,newVar1);
					varB = newVar1;
				}
			} else {
				if( deltaD < deltaC && stepsD <= givenSteps ) {
					NSLog(@"D wins with %g steps and a delta of %g newVar = %g", stepsD,deltaD,newVar2);
					timeA = newVar2;
				} else {
					NSLog(@"C wins with %g steps and a delta of %g newVar = %g", stepsC,deltaC,newVar2);
					timeB = newVar2;
				}
			}
		}
		NSLog(@"done");

		magicDelta = varA;
		timeToSkip = timeA;
		timeSkipper = 0;
	} else {
		NSLog(@"diff = %g", diff );
		training[trainingPos] = diff;
		trainingPos++;
	}

	lastdot = dot;
	lastx = x;
	lasty = y;
	lastz = z;
}

void startListener()
{
	connectedSocket = 0;
	listenSocket = socket( AF_INET, SOCK_STREAM, 0 );
	int yes = 1;
	setsockopt( listenSocket, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes) );
	fcntl( listenSocket, F_SETFL, O_NONBLOCK );

	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	addr.sin_len = sizeof(addr);
	addr.sin_family = AF_INET;
	addr.sin_port = htons(12345);
	addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	bind( listenSocket, (const struct sockaddr *)&addr, sizeof(addr) );
	listen( listenSocket, 2 );
}

// Some of the below code was initially borrowed from Ants:  http://code.google.com/p/iphone-ants/

typedef struct {} *IOHIDEventSystemRef;
typedef struct {} *IOHIDEventRef;
float IOHIDEventGetFloatValue(IOHIDEventRef ref, int param);

void handleHIDEvent(int a, int b, int c, IOHIDEventRef ptr) {
	int type = IOHIDEventGetType(ptr);
	if (type == 12) {
		float x = IOHIDEventGetFloatValue(ptr, 0xc0000);
		float y = IOHIDEventGetFloatValue(ptr, 0xc0001);
		float z = IOHIDEventGetFloatValue(ptr, 0xc0002);
		changeInXYZ( x, y, z );
	}
}

#define expect(x) if(!x) { printf("failed: %s\n", #x);  return; }

void initialize(int hz) {
	mach_port_t master;
	expect(0 == IOMasterPort(MACH_PORT_NULL, &master));
	int page = 0xff00, usage = 3;

	CFNumberRef nums[2];
	CFStringRef keys[2];
	keys[0] = CFStringCreateWithCString(0, "PrimaryUsagePage", 0);
	keys[1] = CFStringCreateWithCString(0, "PrimaryUsage", 0);
	nums[0] = CFNumberCreate(0, kCFNumberSInt32Type, &page);
	nums[1] = CFNumberCreate(0, kCFNumberSInt32Type, &usage);
	CFDictionaryRef dict = CFDictionaryCreate(0, (const void**)keys, (const void**)nums, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	expect(dict);

	IOHIDEventSystemRef sys = (IOHIDEventSystemRef) IOHIDEventSystemCreate(0);
	expect(sys);

	CFArrayRef srvs = (CFArrayRef)IOHIDEventSystemCopyMatchingServices(sys, dict, 0, 0, 0);
	expect(CFArrayGetCount(srvs)==1);

	io_registry_entry_t serv = (io_registry_entry_t)CFArrayGetValueAtIndex(srvs, 0);
	expect(serv);

	CFStringRef cs = CFStringCreateWithCString(0, "ReportInterval", 0);
	int rv = 1000000/hz;
	CFNumberRef cn = CFNumberCreate(0, kCFNumberSInt32Type, &rv);

	int res = IOHIDServiceSetProperty(serv, cs, cn);
	expect(res == 1);

	res = IOHIDEventSystemOpen(sys, handleHIDEvent, 0, 0);
	expect(res != 0);
}

// End borrowed code...

int main(int argc, char **argv)
{
	resetSteps();
	startListener();

	// just chill in the main thread...  wasting time, etc..
	// the accelerometer events actually drive the networking :)
	struct timeval timeout;
	timeout.tv_sec = timeout.tv_usec = 0;
	for( ;; ) {
		// NEED a watchdog timer for some reason because certain actions seem to un-register us
		// from the accelerometer in some way...  I think this IOHIDEvent.. stuff is depricated.
		// there's got to be a better way to get access to it.

		// note: one situation that unregisters is going into the iPod, starting a song, and then
		// coming back to the menu.

		watchDog = 0;
		select(0,0,0,0,&timeout);
		if( watchDog == 0 ) {
			initialize(10);
		}
		timeout.tv_sec = 2;		// down here so the first loop is instant.. 
	}

	return 0;
}
