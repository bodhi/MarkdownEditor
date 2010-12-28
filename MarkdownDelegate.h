//
//  MarkdownDelegate.h
//  MarkEdit
//
//  Created by bodhi on 1/04/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class OGRegularExpression;

@interface MarkdownDelegate : NSObject <NSTextStorageDelegate> {
    NSTextView *text;

    NSDictionary *blockquoteAttributes, *metaAttributes, 
      *codeAttributes, *strongAttributes, *emAttributes,
      *blankAttributes, *h1Attributes, *h2Attributes,
      *defaultAttributes, *hrAttributes;

    NSMutableDictionary *references;
    
    NSString *MarkdownCodeSection;

    OGRegularExpression *imageNoAttachment;
    OGRegularExpression *attachedImage;
    OGRegularExpression *attachmentNoImage;

    OGRegularExpression *inlinePattern, *linkRegex, *image, *setex, *blank, *indented, *bareLink, *hrRegexp;

    NSArray *mainOrder, *lineBlocks;

    NSDictionary *blocks;

    bool newReferences;

    NSString *attachmentChar;
    NSURL *baseURL;
  }

@property (assign) IBOutlet NSTextView *text;
@property (retain) NSString *attachmentChar;
@property (retain) NSURL *baseURL;
@end
