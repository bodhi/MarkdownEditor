//
//  MyDocument.h
//  MarkEdit
//
//  Created by bodhi on 31/03/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "MarkdownDelegate.h"

@interface MarkdownDocument : NSDocument
{
  IBOutlet NSTextView *textView;

  NSMutableAttributedString *string;

  IBOutlet MarkdownDelegate *mdDelegate;

  NSRange originalRange;
}

@property(retain) NSMutableAttributedString *string;
@end
