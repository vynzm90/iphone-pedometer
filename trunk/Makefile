CC=/usr/local/arm-apple-darwin/bin/gcc
CXX=/usr/local/arm-apple-darwin/bin/g++
CFLAGS=-fsigned-char -I/usr/local/arm-apple-darwin/arm-apple-darwin/include/includes -O3
LDFLAGS=-Wl,-syslibroot,/usr/local/arm-apple-darwin/heavenly -lobjc -ObjC -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit -framework CoreGraphics -framework GraphicsServices -framework Celestial -framework MusicLibrary -framework IOKit
LD=$(CC)

all:	PedometerGUI pedometer-daemon package

PedometerGUI:	gui-main.o PedometerGUIApp.o
		$(LD) $(LDFLAGS) -o $@ $^
		cp PedometerGUI Pedometer-app/

pedometer-daemon:	pedometer-daemon.o
			$(LD) $(LDFLAGS) -o $@ $^

package:	PedometerGUI pedometer-daemon
		mkdir -p package/Applications/Pedometer.app
		mkdir -p package/usr/local/bin/
		mkdir -p package/Library/LaunchDaemons
		cp Pedometer-app/* package/Applications/Pedometer.app
		cp pedometer-daemon package/usr/local/bin/
		cp com.spiffytech.pedometer-daemon.plist package/Library/LaunchDaemons
		cp PACKAGE-NOTES package/

%.o:	%.m %.h
		$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

clean:
		rm -f *.o PedometerGUI pedometer-daemon
		rm -rf package

