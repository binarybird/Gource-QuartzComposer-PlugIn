#import <OpenGL/CGLMacro.h>
#import <ApplicationServices/ApplicationServices.h>

#import "GourcePlugIn.h"
#import "ArgumentKeys.h"

#define	kQCPlugIn_Name				@"Gource Screensaver"
#define	kQCPlugIn_Description		@"Outputs a texture based image directly from gource window."

@implementation GourcePlugIn

@dynamic outputImage;
@synthesize gourceLocation,gitLocation,gourceArguments;

//CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type,  CGEventRef event, void *refcon) {
//
//    CGEventTapInformation -> use to block events from pid of gource (sending 300 wakeup calls/s)
//    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
//    
//    NSLog(@"TYPE: %u\n KEYCODE: %u\n", (uint32_t)type,(uint32_t)keycode);
//    
//    return event;
//}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context{
    
    //TODO validate gource and git locations
    canExecute = YES;
}

- (id) init
{
	if(self = [super init]) {
        NSLog(@"starting up gource quartz plugin...");

//        CFMachPortRef eventTap;
//        CFRunLoopSourceRef runLoopSource;
//        
//        eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, kCGEventMaskForAllEvents, myCGEventCallback, NULL);
//        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
//        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
//        CGEventTapEnable(eventTap, true);
        
        [self addObserver:self forKeyPath:@"gourceLocation" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
        [self addObserver:self forKeyPath:@"gitLocation" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
        
        canExecute = YES;
        
        NSUserDefaults *standardUserDefaults = [[NSUserDefaults alloc] init];
        
        if([[standardUserDefaults valueForKey:@"gourceLocation"] length] > 0)
            self.gourceLocation = [standardUserDefaults valueForKey:@"gourceLocation"];
        else
            canExecute = NO;
        
        if([[standardUserDefaults valueForKey:@"gitLocation"] length] > 0)
            self.gitLocation = [standardUserDefaults valueForKey:@"gitLocation"];
        else
            canExecute = NO;
        
        if([standardUserDefaults valueForKey:@"arguments"] >0)
            self.gourceArguments = [standardUserDefaults valueForKey:@"arguments"];
        else
            self.gourceArguments = @"";
        
        winID=0;
        pid=0;
	}
	return self;
}

+ (NSDictionary*) attributes
{
	/* Return the attributes of this plug-in */
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/* Return the attributes for the plug-in property ports */
	if([key isEqualToString:@"outputImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey,nil];
	
	return nil;
}

+ (NSArray*) plugInKeys
{
    return [NSArray arrayWithObjects: @"gourceLocation",@"gitLocation",@"gourceArguments",nil];
}
- (QCPlugInViewController*) createViewController
{
    return [[QCPlugInViewController alloc] initWithPlugIn:self viewNibName:@"gourceArgs"];
}

+ (QCPlugInExecutionMode) executionMode
{
	/* This plug-in is a provider (it outputs an image coming from an outside source) */
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	/* This plug-in does not depend on the time (time parameter is completely ignored in the -execute:atTime:withArguments: method) but needs idling */
	return kQCPlugInTimeModeIdle;
}

-(void)dealloc{
    /*
     * TODO
     * added observers in the init
     * dealloc never gets called in ARC
     * there is no applicationWillTerminate: in a plugin, thats the AppKit framework :(
     *
     * need to find some way to get rid of the observers when the plugin is unloaded!
     */
    
//    [self removeObserver:self forKeyPath:@"gourceLocation"];
//    [self removeObserver:self forKeyPath:@"gitLocation"];
}

@end

@implementation GourcePlugIn (Execution)

static void _BufferReleaseCallback(const void* address, void* context)
{
	/* Destroy the CGContext and its backing */
	free((void*)address);
}

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* context)
{
	/* Delete the OpenGL texture */
	glDeleteTextures(1, &name);
}

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
    winID = 0;
    pid = 0;
    
   if([gitLocation length] == 0 || [gourceLocation length] == 0)
       canExecute = NO;
    
    if(canExecute){

        @try{
            gource = [NSTask new];
            
            NSArray* args = [gourceArguments componentsSeparatedByString:@","];
            if([args count] > 0 && [gourceArguments length] > 0)
                [gource setArguments:args];
            NSLog(@"launching gource with args: %@",args);
            
            [gource setLaunchPath:gourceLocation];
            [gource setCurrentDirectoryPath:gitLocation];
            [gource launch];
    
            pid = [gource processIdentifier];
            
        }@catch (NSException *exception)
        {
           	NSLog(@"error: %@ caught while trying to launch gource (%@)", [exception name], [exception reason]);

            gource = nil;
            canExecute = NO;
        }
    }
    
    if(pid == 0){
        canExecute = NO;
    }
    
    return canExecute;
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	GLuint						name = [[arguments objectForKey:kArgumentKey_TextureName] unsignedIntValue];
	CGLContextObj				cgl_ctx = [context CGLContextObj];
	id							provider;
    
    CGContextRef				bitmapContext;
	CGImageSourceRef			source;
	CGImageRef					image;
	void*						baseAddress;
	size_t						rowBytes;
	NSString*					path;
	CGRect						bounds;
	

    if(winID == 0){
        NSArray* listOfWindows= (__bridge NSArray*)CGWindowListCopyWindowInfo(kCGWindowListExcludeDesktopElements,kCGNullWindowID );
   
        for(int i = 0; i < [listOfWindows count]; i++){
            if([[[listOfWindows objectAtIndex:i] objectForKey:kCGWindowOwnerPID] integerValue] == pid){
                winID = [[[listOfWindows objectAtIndex:i] objectForKey:kCGWindowNumber] unsignedIntValue];
            
            }
        }
    }
    
    image = CGWindowListCreateImage(CGRectNull,  kCGWindowListOptionIncludingWindow, winID, kCGWindowImageDefault);
    
	if(image == NULL)
        return NO;
    
	
	/* Create CGContext backing */
	rowBytes = CGImageGetWidth(image) * 4;
	if(rowBytes % 16)
        rowBytes = ((rowBytes / 16) + 1) * 16;
    
	baseAddress = valloc(CGImageGetHeight(image) * rowBytes);
	if(baseAddress == NULL) {
		CGImageRelease(image);
		return NO;
	}
	
	/* Create CGContext and draw image into it */
	bitmapContext = CGBitmapContextCreate(baseAddress, CGImageGetWidth(image), CGImageGetHeight(image), 8, rowBytes, [context colorSpace], kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
	if(bitmapContext == NULL) {
		free(baseAddress);
		CGImageRelease(image);
		return NO;
	}
    
	bounds = CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image));
	CGContextClearRect(bitmapContext, bounds);
	CGContextDrawImage(bitmapContext, bounds, image);
	
	/* We don't need the image and context anymore */
	CGImageRelease(image);
	CGContextRelease(bitmapContext);
	
	/* Create image provider from backing */
    provider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatBGRA8
                                               pixelsWide:CGImageGetWidth(image)
                                               pixelsHigh:CGImageGetHeight(image)
                                              baseAddress:baseAddress
                                              bytesPerRow:rowBytes
                                          releaseCallback:_BufferReleaseCallback
                                           releaseContext:NULL
                                               colorSpace:(CGColorSpaceRef)[context colorSpace]
                                         shouldColorMatch:YES];

	if(provider == nil) {
		free(baseAddress);
		return NO;
	}
	
	/* Set output image */
	self.outputImage = provider;
	
	return YES;
}

- (void)stopExecution:(id<QCPlugInContext>)context
{
    NSLog(@"shutting down gource quartz plugin...");
    
    NSUserDefaults *standardUserDefaults = [[NSUserDefaults alloc] init];
    [standardUserDefaults setObject:gourceLocation forKey:@"gourceLocation"];
    [standardUserDefaults setObject:gitLocation forKey:@"gitLocation"];
    [standardUserDefaults setObject:gourceArguments forKey:@"arguments"];
    [standardUserDefaults synchronize];
    
    //TODO NSTask terminate does not terminate the process for some reason
    [gource terminate];
    
    system([[NSString stringWithFormat:@"kill -9 %i",pid] UTF8String]);
    
    gource = nil;
    
    canExecute = YES;
    
    winID = 0;
    pid = 0;
	
}
@end
    
