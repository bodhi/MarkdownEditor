//
//  MarkdownDelegate.m
//  MarkEdit
//
//  Created by bodhi on 1/04/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MarkdownDelegate.h"
#import "OgreKit/OgreKit.h"

@implementation MarkdownDelegate
@synthesize text;

- (void)awakeFromNib {
  [text textStorage].delegate = self;
  
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  
  NSMutableParagraphStyle *ps;
//  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setHeadIndent:28];
//  [ps setFirstLineHeadIndent:16];
//  [ps setTailIndent:-28];
  blockquoteAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
//					  ps, NSParagraphStyleAttributeName,
						[NSFont fontWithName:@"Georgia-Italic" size:14], NSFontAttributeName,
					nil
      ] retain];

  NSColor *grey = [NSColor lightGrayColor];
  NSFont *big = [NSFont userFontOfSize:24];
  NSFont *normal = [NSFont userFontOfSize:14];
  NSFont *code = [NSFont userFixedPitchFontOfSize:12];
  metaAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				    grey, NSForegroundColorAttributeName, 
				  normal, NSFontAttributeName, 
				  nil
      ] retain];
  
  ps = [[NSMutableParagraphStyle alloc] init];
  [ps setLineBreakMode:NSLineBreakByTruncatingTail];
  MarkdownCodeSection = @"MarkdownCodeSection";
  codeAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
			     [NSColor colorWithCalibratedWhite:0.95 alpha:1.0], NSBackgroundColorAttributeName,
				  ps, NSParagraphStyleAttributeName,
				  code, NSFontAttributeName,
				  [[NSObject alloc] init], MarkdownCodeSection,
				  nil
      ] retain];

  strongAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
					[fontManager convertFont:normal toHaveTrait:NSFontBoldTrait], NSFontAttributeName,
				    nil
      ] retain];

  emAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				    [fontManager convertFont:normal toHaveTrait:NSFontItalicTrait], NSFontAttributeName,
				nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
  int lineHeight = 20;
//  [ps setMinimumLineHeight:lineHeight];
//  [ps setMaximumLineHeight:lineHeight];
//  [ps setParagraphSpacingBefore:lineHeight];
  h1Attributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				    [fontManager convertFont:big toHaveTrait:NSFontBoldTrait], NSFontAttributeName,
				ps, NSParagraphStyleAttributeName,
				     [NSNumber numberWithInt:-1], NSKernAttributeName,
				nil
      ] retain];

  h2Attributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				  big, NSFontAttributeName,
				ps, NSParagraphStyleAttributeName,
				     [NSNumber numberWithInt:-1], NSKernAttributeName,
				nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setMaximumLineHeight:12];
  blankAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				     ps, NSParagraphStyleAttributeName,
				   //    [NSColor redColor], NSBackgroundColorAttributeName,
				   nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
  [ps setMinimumLineHeight:lineHeight];
  [ps setMaximumLineHeight:lineHeight];
  defaultAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				       ps, NSParagraphStyleAttributeName,
				     normal, NSFontAttributeName,
				     //    [NSColor redColor], NSBackgroundColorAttributeName,
				     nil
      ] retain];

  NSTextAttachment *a = [[NSTextAttachment alloc] init];
  attachmentChar = [[[NSAttributedString attributedStringWithAttachment:a] string] retain];
  [a release];

  // Lists
  // /^(?:[\s>]*)(\s*\d+\.\s*|[\s*]*)(.*)$/
  // Explained:
  // ^(?:[\s>]*)   # skip over any quoting
  //   ((?:
  //   \s*\d+\.\s* # a numeric item
  //   |           # or
  //   [\s*]       # an unordered one
  // )*)           # lots
  // (.*)
  // $
  listRegex = [[OGRegularExpression alloc] initWithString:@"^(?:[\\s>]*)((?:\\s*\\d+\\.\\s*|[\\s*])*)(.*)$"];

  // Image tags:
  // !K?\[(.*?)\]\((.*?)\)
  // Explained:
  // !         # image delimiter
  // K?        # optional attachment char (not k, actually \ufffc)
  // \[(.*?)\] # title
  // \((.*?)\) # url
  imageMark = @"!";
  baseRegex = @"\\[(.*?)\\]\\((.*?)\\)";

  imageNoAttachment = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"%@%@", imageMark, baseRegex]];
  attachedImage = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"%@%@%@", imageMark, attachmentChar, baseRegex]];

  // ! with attachment char and no image markup, or attachment char with markup but no leading !
  attachmentNoImage = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"([^%@]%@%@|%@%@(?!%@))", imageMark, attachmentChar, baseRegex, imageMark, attachmentChar, baseRegex]];
  
  // ! (optional attachment char) [title] (uri)
  image = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"%@%@?%@", imageMark, attachmentChar, baseRegex]];

  // /(?<!\\)([*_`]{1,2})((?!\1).*?[^\\])(\1)/
  inlinePattern = [[OGRegularExpression alloc] initWithString:@"(?<!\\\\)([*_`]{1,2})((?!\\1).*?[^\\\\])(\\1)"];

  // Link tags
  // \[((?:\!\[.*?\]\(.*?\)|.)*?)\]\((.*?)\)
  // explained: 
  //    (?<!!)  # doesn't have a ! before the [ (or attachment char)
  //    \[ # start of anchor text
  //    (                     # capture...
  //      (?:\!\[.*?\]\(.*?\) # an image,
  //      |.)                 # or anything else
  //      *?)                 # zero or more of above
  //    \] # end anchor text
  //    \((.*?)\) # capture url
  link = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?<!!|%@)\\[((?:\\!%@?\\[.*?\\]\\(.*?\\)|.)*?)\\]\\((.*?)\\)", attachmentChar, attachmentChar]];


  header = [[OGRegularExpression alloc] initWithString:@"^(?:[\\s>]*)(#+)(.*?)(#*)?$"];

  blockquoteRegex = [[OGRegularExpression alloc] initWithString:@"^((?:\\s*>+\\s*)+)(.*?(?:\\r{2}|\\n{2}|(?:\\r\\n){2}))" options:OgreMultilineOption];
//  blockquoteRegex = [[OGRegularExpression alloc] initWithString:@"^((?:\\s*>+\\s*)+)(.*)"];
  codeBlockRegex = [[OGRegularExpression alloc] initWithString:@"^ {4}(.*\r?\n?)"];
}

- (int)attachImage:(NSString *)imageSrc toString:(NSMutableAttributedString *)target atIndex:(int) index {
  NSLog(@"Image with src %@", imageSrc);
  
  NSError *error;
//	if (document) 
//	  NSLog(@"Doc: %@", [document fileURL]);
  NSURL *url = [NSURL URLWithString:imageSrc relativeToURL:[document fileURL]];
  NSLog(@"URL scheme: %@", [url scheme]);
  if (url && [[url scheme] isEqualToString:@"file"]) {
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:url options:NSFileWrapperReadingWithoutMapping error:&error];
    if (wrapper) {
      NSLog(@"Wrapper: %@ error: %@", wrapper, error);
      NSTextAttachment *img = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
      NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:img];
      
      NSLog(@"INSERTING %@ of length %d", imageString, [imageString length]);
      [target beginEditing];
      [target insertAttributedString:imageString atIndex:index];
      [target endEditing];
      [img release];
      [wrapper release];
    } else {
      NSLog(@"No file for %@", url);
    }
    return 1;
  }
  return 0;
}

- (void)textStorageWillProcessEditing:(NSNotification *)aNotification {
  NSTextStorage *storage = [aNotification object];
  NSString *stString = [storage string];

  OGRegularExpressionMatch *match;

  // find attachment with no markup
  for (match in [attachmentNoImage matchEnumeratorInString:stString]) {
    // remove attachment
    //    NSLog(@"ATTACHMENT NO IMAGE:%@", [match matchedString]);
    [storage replaceCharactersInRange:NSMakeRange([match rangeOfMatchedString].location + 1, 1) withString:@""];
  }
  
  // find image with attachment char
  // Do this before adding attachments so incorrect images get fixed
  for (match in [attachedImage matchEnumeratorInString:stString]) {
    NSRange imageRange = [match rangeOfMatchedString];
    //    NSLog(@"IMAGE WITH ATTACHMENT: %@", [match matchedString]);
    int attachmentIndex = imageRange.location + 1;
    NSTextAttachment *attachment = [storage attribute:NSAttachmentAttributeName atIndex:attachmentIndex effectiveRange:nil];
    //    NSLog(@"THE ATTACHMENT %@", attachment);

    // validate attachment src
    if (![[match substringAtIndex:2] isEqualToString:[[attachment fileWrapper] filename]]) {
      [storage replaceCharactersInRange:NSMakeRange(attachmentIndex, 1) withString:@""];
      //      NSLog(@"attachment different to source, stripped");
    } else {
      //      NSLog(@"attachment name same as source");
    }
  }

  // find image markup (without attachment char)
  // Do this after removing attachments with incorrect images
  int attachmentCompensation = 1;
  for (match in [imageNoAttachment matchEnumeratorInString:stString]) {
    // add attachment char with attachment
    //    NSLog(@"IMAGE %@", [match matchedString]);
    NSRange imageRange = [match rangeOfMatchedString];

    int adjustment = 0;
    //    NSLog(@"ATTACHMENT: %@", [match substringAtIndex:2]);
    adjustment = [self attachImage:[match substringAtIndex:2] toString:storage atIndex:imageRange.location + attachmentCompensation];
    attachmentCompensation += adjustment;
  }
  
}

- (bool)isCodeSection:(NSAttributedString *)string atIndex:(int) index {
  return [string attribute:MarkdownCodeSection atIndex:index effectiveRange:nil] != nil;
}

- (NSDictionary *)attributesForIndentTo:(int) level leadOffset:(int) pixels {
  NSMutableParagraphStyle *ps;
  ps = [[NSMutableParagraphStyle alloc] init];

  int pointIndent = 16 + level * 12;
  // 28, 16 => 28, 12
  
  // 0 left edge
  // 28 code
  // 32 > 44 quote
  //         56 wrapped line

  // 32 > 44\n quote with breaks
  //  32 next line

  // 48 > 60 > 72 double quote
  //              84 wrapped line

  // 48 > 60 > 72\n double with breaks
  //  48 next line


  [ps setHeadIndent:pointIndent];
  [ps setFirstLineHeadIndent:pointIndent - pixels * level];
//  [ps setTailIndent:-pointIndent];
  return [NSDictionary dictionaryWithObject: ps forKey:NSParagraphStyleAttributeName];
}

- (int)occurencesOf:(NSString *)divider in:(NSString *)target {
  return [[target componentsSeparatedByString:divider] count] - 1;
}

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
  NSTextStorage *storage = [aNotification object];

  //  NSRange edited = [storage editedRange];
  //NSLog(@"%d->%d", edited.location, edited.length);
  [storage beginEditing];
  
  NSRange n = NSMakeRange(0, 1);
//  NSFont *big = [NSFont userFontOfSize:24];
//  NSFont *normal = [NSFont userFontOfSize:14];

  NSRange storageRange = NSMakeRange(0, [storage length]);
  [storage removeAttribute:NSParagraphStyleAttributeName range:storageRange];
  [storage removeAttribute:NSFontAttributeName range:storageRange];
  [storage removeAttribute:NSForegroundColorAttributeName range:storageRange];
  [storage removeAttribute:NSBackgroundColorAttributeName range:storageRange];
  [storage removeAttribute:NSKernAttributeName range:storageRange];
  [storage removeAttribute:NSToolTipAttributeName range:storageRange];
  [storage removeAttribute:MarkdownCodeSection range:storageRange];
  [storage removeAttribute:NSLinkAttributeName range:storageRange];
  [storage addAttributes:defaultAttributes range:NSMakeRange(0, [storage length])];
  
  NSLog(@"----");

  for (OGRegularExpressionMatch *match in [listRegex matchEnumeratorInAttributedString:storage]) {
    NSString *prefix = [match substringAtIndex:1];
    int indent = [self occurencesOf:@"*" in:prefix] + [self occurencesOf:@"." in:prefix];
    [storage addAttributes:[self attributesForIndentTo:indent leadOffset:9] range:[match rangeOfMatchedString]];
    [storage addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:1]];
  }

  for (OGRegularExpressionMatch *match in [codeBlockRegex matchEnumeratorInAttributedString:storage]) {
    [storage addAttributes:codeAttributes range:[match rangeOfMatchedString]];
    NSRange content = [match rangeOfSubstringAtIndex:1];
    [storage addAttribute:NSToolTipAttributeName value:[match substringAtIndex:1] range:content];
    //      NSLog(@"%@", [storage string]);
  }
    
  for (OGRegularExpressionMatch *match in [blockquoteRegex matchEnumeratorInAttributedString:storage]) {
    if (![self isCodeSection:storage atIndex:[match rangeOfMatchedString].location]) {       // don't set attributes in code blocks
      [storage addAttributes:blockquoteAttributes range:[match rangeOfMatchedString]];
      [storage addAttributes:[self attributesForIndentTo:[self occurencesOf:@">" in:[match substringAtIndex:1]] leadOffset:12] range:[match rangeOfMatchedString]];
      [storage addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:1]];
    }
  }

  for (OGRegularExpressionMatch *match in [header matchEnumeratorInAttributedString:storage]) {
//    NSLog(@"matched: %@", [match matchedString]);
    NSRange headerPrefix = [match rangeOfSubstringAtIndex:1];
    if (![self isCodeSection:storage atIndex:headerPrefix.location]) {
      NSDictionary *attributes;
      if (headerPrefix.length == 1)
	attributes = h1Attributes;
      else
	attributes = h2Attributes;
      
      [storage addAttributes:attributes range:[match rangeOfSubstringAtIndex:2]];
      [storage addAttributes:metaAttributes range:headerPrefix];
      [storage addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:3]];
    }
  }

  for (OGRegularExpressionMatch *match in [inlinePattern matchEnumeratorInAttributedString:storage]) {
    NSRange mRange = [match rangeOfMatchedString];
//        NSLog(@"%@ %@ %@", [match matchedString], [match substringAtIndex:1], [match substringAtIndex:2]);
    NSDictionary *attribs = nil;
    NSString *delimiter = [match substringAtIndex:1];
    if (![self isCodeSection:storage atIndex:[match rangeOfSubstringAtIndex:1].location]) { // don't set attributes in code blocks
      if ([delimiter isEqualToString:@"`"] ||
	  [delimiter isEqualToString:@"``"]) { // code span
	attribs = codeAttributes;
      } else if ([delimiter isEqualToString:@"**"] ||
		 [delimiter isEqualToString:@"__"]) { // strong span
	attribs = strongAttributes;
      } else { // em span
	attribs = emAttributes;
      }
    }
//        [storage addAttribute:NSFontAttributeName value:code range:mRange];
    if (attribs != nil) {
      [storage addAttributes:attribs range:mRange];
      [storage addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:1]];
      [storage addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:3]];
    }
  }
 
  for (OGRegularExpressionMatch *match in [image matchEnumeratorInAttributedString:storage]) {    
    [storage addAttributes:metaAttributes range:[match rangeOfMatchedString]];
  }
     
  for (OGRegularExpressionMatch *match in [link matchEnumeratorInAttributedString:storage]) {
    NSRange mRange = [match rangeOfMatchedString];
    NSRange textRange = [match rangeOfSubstringAtIndex:1];
//	NSLog(@"text: %d %d", textRange.location, textRange.length);
    NSRange urlRange = [match rangeOfSubstringAtIndex:2];
//	NSLog(@"url: %d %d", urlRange.location, urlRange.length);

    if (urlRange.location != NSNotFound && textRange.location != NSNotFound) {
      [storage addAttributes:metaAttributes range:mRange];
      [storage addAttribute:NSLinkAttributeName value:[NSURL URLWithString:[match substringAtIndex:2]] range:textRange];
    }
  }

  n.location = 0;
  n.length = [storage length];
  [storage fixAttributesInRange:storageRange];
  [storage endEditing];
}

@end
