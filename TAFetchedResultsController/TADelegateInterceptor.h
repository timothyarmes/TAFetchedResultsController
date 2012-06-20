//
//  DelegateInterceptor.h
//
//  This class provides mechanism for a sub class to intercept the delegate methods of it's superclass
//  without the need to reimplement every delegate method.
//
//  See here: http://stackoverflow.com/questions/3498158/intercept-obj-c-delegate-messages-within-a-subclass

#import <Foundation/Foundation.h>

@interface TADelegateInterceptor : NSObject

@property (nonatomic, weak) id receiver;
@property (nonatomic, weak) id middleMan;

@end
