//
//  MyDocument.h
//  MarkEdit
//
//  Created by bodhi on 31/03/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//


#import <Cocoa/Cocoa.h>

@interface MarkdownDocument : NSDocument
{
  IBOutlet NSTextView *textView;

  NSMutableAttributedString *string;
  NSString *attachmentChar;
}

@property(retain) NSMutableAttributedString *string;
@property(retain) NSString *attachmentChar;
@end
