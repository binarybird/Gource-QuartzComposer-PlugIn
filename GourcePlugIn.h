#import <Quartz/Quartz.h>

@interface GourcePlugIn : QCPlugIn
{
    
    NSString* gourceLocation;
    NSString* gitLocation;
    NSString* gourceArguments;
    
    NSTask* gource;
    CGWindowID winID;
    int pid;
    BOOL canExecute;
    
}



/* Declare a property output port of type "Image" and with the key "outputImage" */
@property(assign) id<QCPlugInOutputImageProvider> outputImage;

@property(copy) NSString* gourceLocation;
@property(copy) NSString* gitLocation;
@property(copy) NSString* gourceArguments;

@end
