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
  ps = [[NSMutableParagraphStyle alloc] init];
  [ps setHeadIndent:28];
  [ps setFirstLineHeadIndent:16];
  [ps setTailIndent:-28];
  blockquoteAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
					  ps, NSParagraphStyleAttributeName,
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
}

- (int)attachImage:(NSString *)imageSrc toString:(NSMutableAttributedString *)target atIndex:(int) index {
       NSLog(@"Image with src %@", imageSrc);
       
       NSError *error;
//	if (document) 
//	  NSLog(@"Doc: %@", [document fileURL]);
       NSURL *url = [NSURL URLWithString:imageSrc relativeToURL:[document fileURL]];
//	NSLog(@"URL: %@", url);
       if (url) {
	 NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:url options:NSFileWrapperReadingWithoutMapping error:&error];
//	  NSLog(@"Wrapper: %@ error: %@", wrapper, error);
	 NSTextAttachment *img = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
	 NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:img];

	 NSLog(@"INSERTING %@ of length %d", imageString, [imageString length]);
	 [target beginEditing];
	 [target insertAttributedString:imageString atIndex:index];
	 [target endEditing];
//	    [img release];
//	    [wrapper release];
	 return 1;
       }
       return 0;
}

- (void)textStorageWillProcessEditing:(NSNotification *)aNotification {
  NSTextStorage *storage = [aNotification object];
  NSString *stString = [storage string];

  // Image tags:
  // !K?\[(.*?)\]\((.*?)\)
  // Explained:
  // !         # image delimiter
  // K?        # optional attachment char (not k, actually \ufffc)
  // \[(.*?)\] # title
  // \((.*?)\) # url
  NSString *imageMark = @"!";
  NSString *baseRegex = @"\\[(.*?)\\]\\((.*?)\\)";
  OGRegularExpression *imageNoAttachment = [OGRegularExpression regularExpressionWithString:[NSString stringWithFormat:@"%@%@", imageMark, baseRegex]];
  OGRegularExpression *attachedImage = [OGRegularExpression regularExpressionWithString:[NSString stringWithFormat:@"%@%@%@", imageMark, attachmentChar, baseRegex]];

  // ! with attachment char and no image markup, or attachment char with markup but no leading !
  OGRegularExpression *attachmentNoImage = [OGRegularExpression regularExpressionWithString:[NSString stringWithFormat:@"([^%@]%@%@|%@%@(?!%@))", imageMark, attachmentChar, baseRegex, imageMark, attachmentChar, baseRegex]];

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

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
  NSTextStorage *storage = [aNotification object];

  //  NSRange edited = [storage editedRange];
  //NSLog(@"%d->%d", edited.location, edited.length);
  [storage beginEditing];
  
  NSRange n = NSMakeRange(0, 1);
//  NSFont *big = [NSFont userFontOfSize:24];
//  NSFont *normal = [NSFont userFontOfSize:14];

  OGRegularExpression    *pattern, *link, *image;
// /(?<!\\)([*_`]{1,2})((?!\1).*?[^\\])(\1)/
  pattern = [OGRegularExpression regularExpressionWithString:@"(?<!\\\\)([*_`]{1,2})((?!\\1).*?[^\\\\])(\\1)"];

  // Link tags
  // \[((?:\!\[.*?\]\(.*?\)|.)*?)\]\((.*?)\)
  // explained: 
  //    (?<!!)  # doesn't have a ! before the [
  //    \[ # start of anchor text
  //    (                     # capture...
  //      (?:\!\[.*?\]\(.*?\) # an image,
  //      |.)                 # or anything else
  //      *?)                 # zero or more of above
  //    \] # end anchor text
  //    \((.*?)\) # capture url
  link = [OGRegularExpression regularExpressionWithString:[NSString stringWithFormat:@"(?<!!|%@)\\[((?:\\!\\[.*?\\]\\(.*?\\)|.)*?)\\]\\((.*?)\\)", attachmentChar]];

  NSEnumerator    *enumerator;

  NSRange storageRange = NSMakeRange(0, [storage length]);
  [storage removeAttribute:NSParagraphStyleAttributeName range:storageRange];
  [storage removeAttribute:NSFontAttributeName range:storageRange];
  [storage removeAttribute:NSForegroundColorAttributeName range:storageRange];
  [storage removeAttribute:NSBackgroundColorAttributeName range:storageRange];
  [storage removeAttribute:NSKernAttributeName range:storageRange];
  [storage removeAttribute:NSToolTipAttributeName range:storageRange];
  [storage removeAttribute:MarkdownCodeSection range:storageRange];
  [storage removeAttribute:NSLinkAttributeName range:storageRange];
  
  NSLog(@"----");
  for (NSTextStorage *para in [storage paragraphs]) {
    [para beginEditing];
    NSRange paraRange = NSMakeRange(0, [para length]);

    for (OGRegularExpressionMatch *match in [[OGRegularExpression regularExpressionWithString:@"!.."] matchEnumeratorInString:[para string]]) { 
      id attrib = [para attribute:NSAttachmentAttributeName atIndex:[match rangeOfMatchedString].location effectiveRange:nil];
      if (attrib != nil) {
	NSLog(@"Attach %@ @ %d", attrib, [match rangeOfMatchedString].location);
      }
      
    }
    [para addAttributes:defaultAttributes range:paraRange];

    if ([para length] == 1) {	// empty line
//  NSLog(@"len %d", [para length]);
      [para addAttributes:blankAttributes range:NSMakeRange(0, 1)];
    } else {
      NSString *str = [para string];
    
      NSRange r = [str rangeOfString:@"> " options:NSAnchoredSearch];
      if (r.location != NSNotFound) {
	[para addAttributes:blockquoteAttributes range:paraRange];
	[para addAttributes:metaAttributes range:r];
      }

      r = [str rangeOfString:@"# " options:NSAnchoredSearch];
      if (r.location != NSNotFound) {
	r.length -= 1;
	[para addAttributes:h1Attributes range:paraRange];
	[para addAttributes:metaAttributes range:r];
	goto finish;
      }
    
      r = [str rangeOfString:@"## " options:NSAnchoredSearch];
      if (r.location != NSNotFound) {
	r.length -= 1;
	[para addAttributes:h2Attributes range:paraRange];
	[para addAttributes:metaAttributes range:r];
	goto finish;
      }

      r = [str rangeOfString:@"    " options:NSAnchoredSearch];
      if (r.location != NSNotFound) {
	[para addAttributes:codeAttributes range:paraRange];
	NSRange content = NSMakeRange(4, [str length] - 4);
	[para addAttribute:NSToolTipAttributeName value:[str substringWithRange:content] range:content];
//      NSLog(@"%@", [para string]);
	goto finish;
      }

    finish:
//     enumerator = [codeEx matchEnumeratorInString:str];
//     OGRegularExpressionMatch    *match;
//     while ((match = [enumerator nextObject]) != nil) {        
//         NSRange mRange = [match rangeOfMatchedString];
// //        [para addAttribute:NSFontAttributeName value:code range:mRange];
//         [para addAttributes:codeAttributes range:mRange];
//         [para addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:1]];
//         [para addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:2]];
//       }

      // for (OGRegularExpressionMatch *match in [strong matchEnumeratorInString:str]) {
      //     NSRange mRange = [match rangeOfMatchedString];
      //     [para addAttributes:strongAttributes range:mRange];
      //     [para addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:1]];
      //     [para addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:2]];
      //   }

      for (OGRegularExpressionMatch *match in [pattern matchEnumeratorInString:str]) {
        NSRange mRange = [match rangeOfMatchedString];
//        NSLog(@"%@ %@ %@", [match matchedString], [match substringAtIndex:1], [match substringAtIndex:2]);
        NSDictionary *attribs = nil;
	if ([para attribute:MarkdownCodeSection atIndex:[match rangeOfSubstringAtIndex:1].location effectiveRange:nil] == nil) { // don't set attributes in code blocks
	  if ([[match substringAtIndex:1] isEqualToString:@"`"]) { // code span
            attribs = codeAttributes;
	  } else if ([[match substringAtIndex:1] isEqualToString:@"**"] ||
		     [[match substringAtIndex:1] isEqualToString:@"__"]) { // strong span
	    attribs = strongAttributes;
	  } else { // em span
	    attribs = emAttributes;
	  }
	}
//        [para addAttribute:NSFontAttributeName value:code range:mRange];
        if (attribs != nil) {
          [para addAttributes:attribs range:mRange];
          [para addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:1]];
          [para addAttributes:metaAttributes range:[match rangeOfSubstringAtIndex:3]];
        }
      }
 
     for (OGRegularExpressionMatch *match in [image matchEnumeratorInString:str]) {
       NSRange mRange = [match rangeOfMatchedString];
       NSString *src = [match substringAtIndex:2];	
       NSLog(@"Image with src %@", src);
       
       id attrib = [para attribute:NSAttachmentAttributeName atIndex:[match rangeOfMatchedString].location effectiveRange:nil];
       if (attrib == nil) {
	  NSError *error;
//	if (document) 
//	  NSLog(@"Doc: %@", [document fileURL]);
	  NSURL *url = [NSURL URLWithString:src relativeToURL:[document fileURL]];
//	NSLog(@"URL: %@", url);
	  if (url) {
	    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:url options:NSFileWrapperReadingWithoutMapping error:&error];
//	  NSLog(@"Wrapper: %@ error: %@", wrapper, error);
	    NSTextAttachment *img = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
	    [para addAttribute:NSAttachmentAttributeName value:img range:NSMakeRange(mRange.location, 1)];
//	    [img release];
//	    [wrapper release];
	  }
	}
       [para addAttributes:metaAttributes range:mRange];
     }
     
      OGRegularExpressionMatch *match;
      enumerator = [link matchEnumeratorInString:str];
      while ((match = [enumerator nextObject]) != nil) {
        NSRange mRange = [match rangeOfMatchedString];
        NSRange textRange = [match rangeOfSubstringAtIndex:1];
//	NSLog(@"text: %d %d", textRange.location, textRange.length);
        NSRange urlRange = [match rangeOfSubstringAtIndex:2];
//	NSLog(@"url: %d %d", urlRange.location, urlRange.length);

	if (urlRange.location != NSNotFound && textRange.location != NSNotFound) {
//        [para addAttribute:NSUnderlineStyleAttributeName value:NSUnderlineStyleSingle range:textRange];
	  [para addAttributes:metaAttributes range:mRange];
//[para addAttribute:NSFontAttributeName value:[NSFont userFontOfSize:1] range:urlRange];
//[para addAttribute:NSFontAttributeName value:[NSFont userFontOfSize:14] range:textRange];
	  [para addAttribute:NSLinkAttributeName value:[NSURL URLWithString:[match substringAtIndex:2]] range:textRange];
	}
      }
    }


//      [para fixFontAttributeInRange:n];
//      [para endEditing];
  }


  n.location = 0;
  n.length = [storage length];
  [storage fixFontAttributeInRange:n];
  [storage fixParagraphStyleAttributeInRange:n];
//  [storage fixAttributesInRange:storageRange];
  [storage endEditing];
}

@end
