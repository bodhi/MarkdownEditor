//
//  MyDocument.m
//  MarkEdit
//
//  Created by bodhi on 31/03/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MarkdownDocument.h"
#import "OgreKit/OgreKit.h"

@implementation MarkdownDocument
@synthesize string;
@synthesize attachmentChar;

- (id)init
{
    self = [super init];
    if (self) {
        // If an error occurs here, send a [self release] message and return nil.
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    if (self.string != nil) {
      [[textView textStorage] setAttributedString: self.string];
    }
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
  OGRegularExpression *regex = [OGRegularExpression regularExpressionWithString:attachmentChar];
  return [[regex replaceAllMatchesInString:[textView string] withString:@""] dataUsingEncoding:NSUTF8StringEncoding];

  if ( outError != NULL ) {
    *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
  }
  return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
  NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (content != nil) {
    self.string = [[NSMutableAttributedString alloc] initWithString:content];
    [[textView textStorage] setAttributedString: self.string];
    [content release];
    return YES;
  } else {
    *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    return NO;
  }
}

@end
