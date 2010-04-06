//
//  MarkdownDelegate.m
//  MarkEdit
//
//  Created by bodhi on 1/04/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MarkdownDelegate.h"
#import "OgreKit/OgreKit.h"

static NSString *listType = @"list";
static NSString *refType = @"ref";
static NSString *headerType = @"header";
static NSString *quoteType = @"quote";
static NSString *codeType = @"code";
static NSString *hrType = @"hr";
static NSString *plainType = @"plain";
static NSString *setexType = @"setex";

@interface MDBlock : NSObject <NSCopying> {
  NSString *type;
  int indent;
  int prefixLength;
  OGRegularExpressionMatch *match;
}
@property(retain) NSString *type;
@property(retain) OGRegularExpressionMatch *match;
@property(assign) int indent;
@property(assign) int prefixLength;
@end
@implementation MDBlock 
@synthesize type;
@synthesize indent;
@synthesize prefixLength;
@synthesize match;
- (id) initWithType:(NSString *)_type indent:(int)_indent prefix:(int)_prefixLength match:(OGRegularExpressionMatch *)_match {
  if (self = [super init]) {
    self.type = _type;
    self.indent = _indent;
    self.prefixLength = _prefixLength;
    self.match = _match;
  }
  return self;
}

+ (id) blockWithType:(NSString *)type indent:(int)indent prefix:(int)prefixLength match:(OGRegularExpressionMatch *)match {
  return [[[MDBlock alloc] initWithType:type indent:indent prefix:prefixLength match:match] autorelease];
}

- (id)copyWithZone:(NSZone *)zone {
  return [MDBlock blockWithType:self.type indent:self.indent prefix:self.prefixLength match:self.match];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@:%d:%d", type, indent, prefixLength];
}
@end

@implementation MarkdownDelegate
@synthesize text;

- (void)awakeFromNib {
  [text textStorage].delegate = self;

  references = [[NSMutableDictionary alloc] init];
  
//  NSFontManager *fontManager = [NSFontManager sharedFontManager];

  MarkdownCodeSection = @"MarkdownCodeSection";
  MarkdownTextSize = @"MarkdownSectionTextSize";
  
  NSNumber *bigSize = [NSNumber numberWithInt:24];
  NSNumber *codeSize = [NSNumber numberWithInt:12];
  NSNumber *quoteSize = [NSNumber numberWithInt:14];
  NSNumber *normalSize = [NSNumber numberWithInt:14];

  NSMutableParagraphStyle *ps;
//  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setHeadIndent:28];
//  [ps setFirstLineHeadIndent:16];
//  [ps setTailIndent:-28];
  blockquoteAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
//					  ps, NSParagraphStyleAttributeName,
						[NSFont fontWithName:@"Georgia-Italic" size:14], NSFontAttributeName,
					  quoteSize, MarkdownTextSize,
					nil
      ] retain];

  NSColor *grey = [NSColor lightGrayColor];
//  NSFont *big = [NSFont userFontOfSize:24];
  NSFont *normal = [NSFont userFontOfSize:14];
//  NSFont *code = [NSFont userFixedPitchFontOfSize:12];
  metaAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				    grey, NSForegroundColorAttributeName, 
//				  normal, NSFontAttributeName, 
				  nil
      ] retain];
  
  ps = [[NSMutableParagraphStyle alloc] init];
  [ps setLineBreakMode:NSLineBreakByTruncatingTail];
  codeAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
			     [NSColor colorWithCalibratedWhite:0.95 alpha:1.0], NSBackgroundColorAttributeName,
				  ps, NSParagraphStyleAttributeName,
//				  code, NSFontAttributeName,
				  [[NSObject alloc] init], MarkdownCodeSection,
				  nil
      ] retain];

  strongAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
//					[fontManager convertFont:normal toHaveTrait:NSFontBoldTrait], NSFontAttributeName,
				    nil
      ] retain];

  emAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
//				    [fontManager convertFont:normal toHaveTrait:NSFontItalicTrait], NSFontAttributeName,
				nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
  int lineHeight = 20;
//  [ps setMinimumLineHeight:lineHeight];
//  [ps setMaximumLineHeight:lineHeight];
//  [ps setParagraphSpacingBefore:lineHeight];
  h1Attributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
//				    [fontManager convertFont:big toHaveTrait:NSFontBoldTrait], NSFontAttributeName,
				  bigSize, MarkdownTextSize,
				ps, NSParagraphStyleAttributeName,
				     [NSNumber numberWithInt:-1], NSKernAttributeName,
				nil
      ] retain];

  h2Attributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
//				  big, NSFontAttributeName,
				ps, NSParagraphStyleAttributeName,
				  bigSize, MarkdownTextSize,
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
//  [ps setMinimumLineHeight:lineHeight];
//  [ps setMaximumLineHeight:lineHeight];
  defaultAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: 
				       ps, NSParagraphStyleAttributeName,
				     normal, NSFontAttributeName,
				     //    [NSColor redColor], NSBackgroundColorAttributeName,
				     nil
      ] retain];

  NSTextAttachment *a = [[NSTextAttachment alloc] init];
  attachmentChar = [[[NSAttributedString attributedStringWithAttachment:a] string] retain];
  [a release];

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
//  linkRegex = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?<!!|%@)\\[((?:\\!%@?\\[.*?\\]\\(.*?\\)|.)*?)\\]\\((.*?)\\)", attachmentChar, attachmentChar]];

  linkRegex = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?<!!|%@)\\[((?:\\!%@?\\[.*?\\]\\(.*?\\)|.)*?)\\]\\((\\S+)\\s*(\\\".+?\\\")?\\)", attachmentChar, attachmentChar]];

  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setMinimumLineHeight:lineHeight];
//  [ps setMaximumLineHeight:lineHeight];
  [ps setAlignment:NSCenterTextAlignment];
  hrAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				  ps, NSParagraphStyleAttributeName,
				normal, NSFontAttributeName,
				nil
      ] retain];
  

// blocks = { 
//   :list => [/^(?:\d+\.\s*|\*\s*)/, :header, :list],
//   :ref => /^\s*\[(.+?)\]:\s*(\S+)\s*(\".+?\")?\s*$/,
//   :header => /^#+\s+/,
//   :quote => [/^>\s+/, :header, :list, :quote],
//   :code => /^ {4}/,
//   :hr => /^[\t ]{,3}([-*])(?:[\t ]*\1){2,}[\t ]*$/,
// }
  blocks = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^\\d+\\.\\s+|\\*\\s+"],
						   headerType, listType, nil], listType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^(\\s*\\[(.+?)\\]:\\s*(\\S+)\\s*(\\\".+?\\\")?\\s*)$"],
						   nil], refType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^(#+)\\s+[^#]*(#*)"],
						   nil], headerType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^>\\s+"],
						   headerType, listType, quoteType, nil], quoteType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^ {4}"],
						    nil], codeType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^([\\t ]{,3}([-*])(?:[\\t ]*\\2){2,}[\\t ]*)$"],
						    nil], hrType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^(?=[^\\t >#*\\d-=\\[])"],
						    nil], plainType,
				       nil];

  // setex = /^([-=])\1*\s*$/
  setex = [[OGRegularExpression alloc] initWithString:@"^([-=])\\1*\\s*$"];
  // blank = /^\s*$/
  blank = [[OGRegularExpression alloc] initWithString:@"^\\s*$"];
  // @indented = /^\s+(?=\S)/
  indented = [[OGRegularExpression alloc] initWithString:@"^\\s+(?=\\S)"];

  mainOrder = [[NSArray alloc] initWithObjects:codeType, hrType, refType, headerType, quoteType, listType, nil];
  lineBlocks = [[NSArray alloc] initWithObjects:codeType, hrType, refType, headerType, setexType, nil];
}

- (int)attachImage:(NSString *)imageSrc toString:(NSMutableAttributedString *)target atIndex:(int) index {
//  NSLog(@"Image with src %@", imageSrc);
  
  NSError *error;
//	if (document) 
//	  NSLog(@"Doc: %@", [document fileURL]);
  NSURL *url = [NSURL URLWithString:imageSrc relativeToURL:[document fileURL]];
//  NSLog(@"URL scheme: %@", [url scheme]);
  if (url && [[url scheme] isEqualToString:@"file"]) {
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:url options:NSFileWrapperReadingWithoutMapping error:&error];
    if (wrapper) {
//      NSLog(@"Wrapper: %@ error: %@", wrapper, error);
      NSTextAttachment *img = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
      NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:img];
      
//      NSLog(@"INSERTING %@ of length %d", imageString, [imageString length]);
      [target beginEditing];
      [target insertAttributedString:imageString atIndex:index];
      [target endEditing];
      [img release];
      [wrapper release];
    } else {
//      NSLog(@"No file for %@", url);
    }
    return 1;
  }
  return 0;
}

- (NSString *)urlForLink:(NSString *)link {
  NSString *url = [references objectForKey:link];
  if (url == nil) url = link;
  return url;
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
    NSString *src = [self urlForLink:[match substringAtIndex:2]];

    int attachmentIndex = imageRange.location + 1;
    NSTextAttachment *attachment = [storage attribute:NSAttachmentAttributeName atIndex:attachmentIndex effectiveRange:nil];
    //    NSLog(@"THE ATTACHMENT %@", attachment);

    // validate attachment src
    if (![src isEqualToString:[[attachment fileWrapper] filename]]) {
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
    NSString *src = [self urlForLink:[match substringAtIndex:2]];
    // add attachment char with attachment
    //    NSLog(@"IMAGE %@", [match matchedString]);
    NSRange imageRange = [match rangeOfMatchedString];

    int adjustment = 0;
    //    NSLog(@"ATTACHMENT: %@", [match substringAtIndex:2]);
    adjustment = [self attachImage:src toString:storage atIndex:imageRange.location + attachmentCompensation];
    attachmentCompensation += adjustment;
  }
  
}

- (bool)isCodeSection:(NSAttributedString *)string atIndex:(int) index {
  return [string attribute:MarkdownCodeSection atIndex:index effectiveRange:nil] != nil;
}

- (NSDictionary *)attributesForIndentTo:(int) level leadOffset:(int) pixels {
  NSMutableParagraphStyle *ps;
  ps = [[NSMutableParagraphStyle alloc] init];

  int pointIndent = 16 + level * 16;
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

- (void)indent:(NSMutableAttributedString *)string range:(NSRange) range for:(NSArray *)stack {
  int level = 0;
  for (MDBlock *block in stack) {
    if (block.type == listType ||
	block.type == quoteType) {
      level += 1;
    }
  }

  if (level > 0) [string addAttributes:[self attributesForIndentTo:level leadOffset:16] range:range];
}

- (NSFont *)fontOfString:(NSAttributedString *)string atIndex:(int)index {
  return [string attribute:NSFontAttributeName atIndex:index effectiveRange:nil];
}

- (int)fontSizeOfString:(NSAttributedString *)string atIndex:(int)index {
  NSFont *font = [self fontOfString:string atIndex:index];
  return (font != nil) ? [font pointSize] : 14;
}

- (NSFont *)codeFontForSize:(int)size {
  return [NSFont userFixedPitchFontOfSize:size];
}

- (NSFont *)emphasisedFont:(NSFont *)font {
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFontTraitMask trait = NSFontItalicTrait;
  if ([fontManager traitsOfFont:font] & NSItalicFontMask) {
    font = [fontManager convertFont:font toNotHaveTrait:trait];
  } else {
    font = [fontManager convertFont:font toHaveTrait:trait];
  }
  return font;
}

- (NSFont *)strongFont:(NSFont *)font {
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFontTraitMask trait = NSFontBoldTrait;
  if ([fontManager traitsOfFont:font] & NSBoldFontMask) {
    font = [fontManager convertFont:font toNotHaveTrait:trait];
  } else {
    font = [fontManager convertFont:font toHaveTrait:trait];
  }
  return font;
}

- (NSFont *)headerFontForFont:(NSFont *)font level:(int) level {
  NSFontManager *fontManager = [NSFontManager sharedFontManager];

//  NSFont *font = [NSFont userFontOfSize:size];
  font = [fontManager convertFont:font toSize:24];
  
  if (level == 1)
    font = [fontManager convertFont:font toHaveTrait:NSFontBoldTrait];

  return font;
}

// - (int)occurencesOf:(NSString *)divider in:(NSString *)target {
//   return [[target componentsSeparatedByString:divider] count] - 1;
// }

- (void)markAsMeta:(NSMutableAttributedString *)string range:(NSRange)range size:(int)size {
  NSFont *font = [self codeFontForSize:size];
  
  [string addAttribute:NSFontAttributeName value:font range:range];
  [string addAttributes:metaAttributes range:range];
}

- (void)markAsMeta:(NSMutableAttributedString *)string range:(NSRange)range {
  int size = [self fontSizeOfString:string atIndex:range.location];
  [self markAsMeta:string range:range size:size];
}

typedef bool (^blockCheckFn)(MDBlock *bl);

- (void) popBlocks:(NSMutableArray *)stack checkFn:(blockCheckFn)fn {
  MDBlock *block = [stack lastObject];
  while (block != nil) {
    if (fn(block)) {
      [stack removeLastObject];
      block = [stack lastObject];
    } else {
      block = nil;
    }
  }  
}

// def pop_line_blocks stack
//   stack.pop until stack.empty? or !@line_blocks.include? stack.last.first
// end
- (void) popLineBlocks:(NSMutableArray *)stack {

  [self popBlocks:stack checkFn:^(MDBlock *block) {
      return (bool) [lineBlocks containsObject:block.type];
    }];
}

// def pop_indented_paragraph_blocks stack, indent
//   stack.pop until stack.empty? or (stack.last.last == indent and stack.last.first == :list)
// end
- (void) popIndentedBlocks:(NSMutableArray *)stack indent:(int)indent {
  [self popBlocks:stack checkFn:^(MDBlock *block) {
      return (bool) (block.type != listType || block.indent + block.prefixLength > indent);
    }];
}

- (void) popParagraphBlocks:(NSMutableArray *)stack {
  MDBlock *first;
  if ([stack count] > 0) first = [stack objectAtIndex:0];
  if (first == nil || first.type == listType)
    return;

  [self popBlocks:stack checkFn:^(MDBlock *block) {
      return (bool) (block.type != listType);
    }];
}

- (void) pushParagraphBlock:(NSMutableArray *)stack block:(MDBlock *)newBlock {
  while ([stack count] > 0) {
    MDBlock *block = [stack lastObject];
    if (block.indent >= newBlock.indent) {
      [stack removeLastObject];
    } else {
      break;
    }
  }
  [stack addObject:newBlock];
}

- (void)markLinks:(NSMutableAttributedString *)string range:(NSRange)range {
  for (OGRegularExpressionMatch *match in [linkRegex matchEnumeratorInAttributedString:string range:range]) {
    NSRange mRange = [match rangeOfMatchedString];
    NSRange textRange = [match rangeOfSubstringAtIndex:1];
    NSRange urlRange = [match rangeOfSubstringAtIndex:2];
    NSString *urlString = [match substringAtIndex:2];
    // Do nothing with title for now
    // NSString *title = [match substringAtIndex:3];
    NSURL *url = [NSURL URLWithString:[self urlForLink:urlString]];
    NSLog(@"'%@' '%@'", urlString, url);

    // '](' before url+title and ')' after
    NSRange suffix = NSMakeRange(urlRange.location - 2, 0);
    suffix.length = mRange.location + mRange.length - suffix.location;

    if (urlRange.location != NSNotFound && textRange.location != NSNotFound && url != nil) {
      [self markAsMeta:string range:NSMakeRange(mRange.location, 1)]; // leading [
      [self markAsMeta:string range:suffix];
      [string addAttribute:NSLinkAttributeName value:url range:textRange];
    }
  }
}

- (void)markImages:(NSMutableAttributedString *)string range:(NSRange)range {
  for (OGRegularExpressionMatch *match in [image matchEnumeratorInAttributedString:string range:range]) {    
    [self markAsMeta:string range:[match rangeOfMatchedString]];
  }
}

- (void)markInlineElementsIn:(NSMutableAttributedString *)string range:(NSRange)range {  
//  if (range.length <= 0) return;

  for (OGRegularExpressionMatch *match in [inlinePattern matchEnumeratorInAttributedString:string range:range]) {
    NSRange mRange = [match rangeOfMatchedString];
    NSDictionary *attribs = nil;
    NSString *delimiter = [match substringAtIndex:1];
    NSFont *font = [self fontOfString:string atIndex:mRange.location];
    if (![self isCodeSection:string atIndex:[match rangeOfSubstringAtIndex:1].location]) { // don't set attributes in code blocks
      if ([delimiter isEqualToString:@"`"] ||
	  [delimiter isEqualToString:@"``"]) { // code span
	attribs = codeAttributes;
	font = [self codeFontForSize:[self fontSizeOfString:string atIndex:mRange.location]];
      } else if ([delimiter isEqualToString:@"**"] ||
		 [delimiter isEqualToString:@"__"]) { // strong span
	attribs = strongAttributes;
	font = [self strongFont:font];
      } else { // em span
	attribs = emAttributes;
	font = [self emphasisedFont:font];
      }
    }
//        [string addAttribute:NSFontAttributeName value:code range:mRange];
    if (attribs != nil) {
      [string addAttribute:NSFontAttributeName value:font range:mRange];
      [string addAttributes:attribs range:mRange];
      [self markAsMeta:string range:[match rangeOfSubstringAtIndex:1]];
      [self markAsMeta:string range:[match rangeOfSubstringAtIndex:3]];
      [self markInlineElementsIn:string range:[match rangeOfSubstringAtIndex:2]];
    }
  }

  [self markImages:string range:range];
  [self markLinks:string range:range];
}

- (void) markLine:(NSMutableAttributedString *)line range:(NSRange) range stack:(NSArray *)stack {
  if (range.length > 0 && stack != nil) {

    [line addAttribute:NSToolTipAttributeName value:[NSString stringWithFormat:@"%@", stack] range:range];

    NSMutableArray *localStack = [NSMutableArray arrayWithArray:stack];

    NSRange prefix = NSMakeRange(0,0);
    NSRange content = NSMakeRange(range.location, range.length);
    
    [self indent:line range:range for:localStack];

    while ([localStack count] > 0) {
      MDBlock *block = [localStack objectAtIndex:0];
      [localStack removeObjectAtIndex:0];
    
      prefix = NSMakeRange(range.location + block.indent, block.prefixLength);
      if (prefix.length > range.length - block.indent) prefix.length = range.length - block.indent;
      content = NSMakeRange(prefix.location + prefix.length, 0);
      content.length = range.location + range.length - content.location;

      if (prefix.length > 0) [self markAsMeta:line range:prefix];

      if (content.length > 0) {
//	NSLog(@"%@: '%@' %d %d", block, [line string], prefix.length, all.length);
//	NSLog(@"%@ (%d %d): %@", stack, range.location, range.length, [[line attributedSubstringFromRange:content] string]);

	if (block.type == codeType) {
	  [line addAttributes:codeAttributes range:range];
	  NSLog(@"Not marking code tooltip");
//	  [line addAttribute:NSToolTipAttributeName value:[line attributedSubstringFromRange:content] range:range];
	  //      NSLog(@"%@", [storage string]);
	  [line addAttribute:NSFontAttributeName value:[self codeFontForSize:12] range:content];
	} else if (block.type == headerType) {
	  NSDictionary *attributes = h1Attributes;
	  NSRange suffix = NSMakeRange(NSNotFound, 0);

	  if (block.match != nil) {
	    prefix = [block.match rangeOfSubstringAtIndex:1];
	    suffix = [block.match rangeOfSubstringAtIndex:2];
	    
	    if (prefix.length == 1) {
	      attributes = h1Attributes;
	    } else {
	      attributes = h2Attributes;
	    }
	  }
	  
	  NSFont *font = [self headerFontForFont:[self fontOfString:line atIndex:content.location] level:prefix.length];
	  [line addAttribute:NSFontAttributeName value:font range:content];
	  [line addAttributes:attributes range:content];

	  // need to mark suffix too
	  if (suffix.location != NSNotFound && suffix.length > 0) {
	    int size = [self fontSizeOfString:line atIndex:prefix.location];
	    [self markAsMeta:line range:suffix size:size];
	  }
	} else if (block.type == setexType) {
	  NSDictionary *attributes = h1Attributes;
	  NSString *delimiter = [block.match substringAtIndex:1];
	  bool isH1 = [delimiter isEqualToString:@"="];
	  if (!isH1) attributes = h2Attributes;
	  NSFont *font = [self headerFontForFont:[self fontOfString:line atIndex:content.location] level:(isH1?1:2)];
	  [line addAttribute:NSFontAttributeName value:font range:content];
	  [line addAttributes:attributes range:content];
	} else if (block.type == quoteType) {
	  [line addAttributes:blockquoteAttributes range:content];
	} else if (block.type == hrType) {
	  [line addAttributes:hrAttributes range:prefix];
	} else if (block.type == refType) {
	  OGRegularExpressionMatch *match = block.match;
	  NSString *ref = [match substringAtIndex:2];
	  NSString *url = [match substringAtIndex:3];
	  //NSString *title = [match substringAtIndex:4];
	  [references setObject:url forKey:ref];
	} else {
	  // other types
	}
      }
    }

    if (content.length > 0) [self markInlineElementsIn:line range:content];
  }
}

- (NSRange) indentForString:(NSAttributedString *)string range:(NSRange)range stack:(NSArray *)stack {
  OGRegularExpressionMatch *match;
  NSRange indent = NSMakeRange(NSNotFound, 0);
  MDBlock *first = nil;
  if ([stack count] > 0) first = [stack objectAtIndex:0];
  
  if (first != nil && first.type == listType && (match = [indented matchInAttributedString:string range:range]) != nil) {
    indent = [match rangeOfMatchedString];
  }
  return indent;
}

- (NSRange) expandRangeToParagraph:(NSRange) range forString:(NSAttributedString *)string {
  NSString *haystack = [string string];
  NSString *needle = @"\n\n";
  
  NSRange prev = NSMakeRange(0, range.location);
  NSRange next = NSMakeRange(range.location + range.length, 0);
  next.length = [haystack length] - next.location;

  prev = [haystack rangeOfString:needle options:NSBackwardsSearch range:prev];
  next = [haystack rangeOfString:needle options:0 range:next];
  
  range.location = prev.location == NSNotFound ? 0 : prev.location;
  range.length = (next.location == NSNotFound ? [haystack length] : next.location) - range.location;
  
  return range;
}

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
  NSTextStorage *storage = [aNotification object];
  NSMutableAttributedString *string;
  string = storage;
  NSRange stringRange = NSMakeRange(0, [string length]);
  
  NSRange edited = [storage editedRange];
  edited = [self expandRangeToParagraph:edited forString:string];
  stringRange = edited;

  [string beginEditing];
  
  [string removeAttribute:NSParagraphStyleAttributeName range:stringRange];
  [string removeAttribute:NSFontAttributeName range:stringRange];
  [string removeAttribute:NSForegroundColorAttributeName range:stringRange];
  [string removeAttribute:NSBackgroundColorAttributeName range:stringRange];
  [string removeAttribute:NSKernAttributeName range:stringRange];
  [string removeAttribute:NSToolTipAttributeName range:stringRange];
  [string removeAttribute:MarkdownCodeSection range:stringRange];
  [string removeAttribute:NSLinkAttributeName range:stringRange];
  [string addAttributes:defaultAttributes range:stringRange];

  NSMutableArray *stack, *prevStack;
  NSRange prevRange = NSMakeRange(NSNotFound, 0);
  bool newPara = true;
  int indent = 0;
  stack = [NSMutableArray array];

//  for (NSTextStorage *l in [storage paragraphs]) {
  for (OGRegularExpressionMatch *lineMatch in [[OGRegularExpression regularExpressionWithString:@"[^\\n]*\\n?"] matchEnumeratorInAttributedString:string range:stringRange]) {
    NSRange lRange = [lineMatch rangeOfMatchedString];
    NSRange lineRange = NSMakeRange(lRange.location, lRange.length);
    OGRegularExpressionMatch *match;

    [self popLineBlocks:stack];

    indent = 0;

    if ([blank matchInAttributedString:string range:lineRange] != nil) {
      [self popParagraphBlocks:stack];
      newPara = true;
      [self markLine:string range:prevRange stack:prevStack];
      continue;
    } else if (newPara) {
      newPara = false;

      NSRange paraIndent = [self indentForString:string range:lineRange stack:stack];
      if (paraIndent.length > 0) {
	[self popIndentedBlocks:stack indent:paraIndent.length];
	[self markAsMeta:string range:paraIndent];

	match = [indented matchInAttributedString:string range:lineRange];
	if (match) {
	  NSRange mRange = [match rangeOfMatchedString];
	  lineRange.location += mRange.length;
	  lineRange.length -= mRange.length;
	}
      } else {
	stack = [NSMutableArray array];
      }
      
    } else if (!newPara && (match = [setex matchInAttributedString:string range:lineRange])) { // SETEX header
      prevStack = [NSMutableArray array];
      [self pushParagraphBlock:prevStack block:[MDBlock blockWithType:setexType indent:0 prefix:0 match:match]];
      [self markLine:string range:prevRange stack:prevStack];

      prevStack = [NSMutableArray array];
      NSRange mRange = [match rangeOfMatchedString];
      [self pushParagraphBlock:prevStack block:[MDBlock blockWithType:headerType indent:0 prefix:mRange.length match:match]];
      prevRange = lineRange;	     // whole line, not subsection

      continue;
    } else {
      [self markLine:string range:prevRange stack:prevStack];
    }

    NSMutableArray *order = [NSMutableArray arrayWithArray:mainOrder];
    NSString *type;
    while ([order count] > 0) {
      type = [order objectAtIndex:0];
      [order removeObjectAtIndex:0];
      
      NSMutableArray *process = [NSMutableArray arrayWithArray:[blocks objectForKey:type]];
      OGRegularExpression *regex = [process objectAtIndex:0];
      [process removeObjectAtIndex:0];
      
      if (match = [regex matchInAttributedString:string range:lineRange]) {
	NSRange mRange = [match rangeOfSubstringAtIndex:1];
	if (mRange.location == NSNotFound) mRange = [match rangeOfMatchedString];
	
	[self pushParagraphBlock:stack block:[MDBlock blockWithType:type indent:indent prefix:mRange.length match:match]];
	indent += mRange.length;
	order = process;

//	NSLog(@"%@ %d %d: %d %d", type, lineRange.location, lineRange.length, mRange.location, mRange.length);
	lineRange = NSMakeRange(lineRange.location + mRange.length, lineRange.length - mRange.length);


      }
    }
    
    prevRange = lRange;
    prevStack = [NSMutableArray array];
    MDBlock *new;
    for (MDBlock *block in stack) {
      new = [block copy];
      [prevStack addObject:new];
//      block.indent += block.prefixLength;
      block.prefixLength = 0;
    }
    
  }

  if (prevRange.length > 0 && prevStack != nil)
    [self markLine:string range:prevRange stack:prevStack];

  [string fixAttributesInRange:stringRange];
  [storage endEditing];
}

@end
