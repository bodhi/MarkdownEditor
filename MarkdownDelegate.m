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

@interface MDBlock : NSObject <NSCopying> {
  NSString *type;
  int indent;
  int prefixLength;
}
@property(retain) NSString *type;
@property(assign) int indent;
@property(assign) int prefixLength;
@end
@implementation MDBlock 
@synthesize type;
@synthesize indent;
@synthesize prefixLength;
- (id) initWithType:(NSString *)_type indent:(int)_indent prefix:(int)_prefixLength {
  if (self = [super init]) {
    self.type = _type;
    self.indent = _indent;
    self.prefixLength = _prefixLength;
  }
  return self;
}

+ (id) blockWithType:(NSString *)type indent:(int)indent prefix:(int)prefixLength {
  return [[[MDBlock alloc] initWithType:type indent:indent prefix:prefixLength] autorelease];
}

- (id)copyWithZone:(NSZone *)zone {
  return [MDBlock blockWithType:self.type indent:self.indent prefix:self.prefixLength];
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
  linkRegex = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?<!!|%@)\\[((?:\\!%@?\\[.*?\\]\\(.*?\\)|.)*?)\\]\\((.*?)\\)", attachmentChar, attachmentChar]];

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
											   @"^(?:\\d+\\.\\s+|\\*\\s+)"],
						   headerType, listType, nil], listType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^\\s*\\[(.+?)\\]:\\s*(\\S+)\\s*(\\\".+?\\\")?\\s*$"],
						   nil], refType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^#+\\s+"],
						   nil], headerType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^>\\s+"],
						   headerType, listType, quoteType, nil], quoteType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^ {4}"],
						    nil], codeType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^[\\t ]{,3}([-*])(?:[\\t ]*\\1){2,}[\\t ]*$"],
						    nil], hrType,
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^(?=[^\\t >#*\\d-=\\[])"],
						    nil], plainType,
				       nil];

  // atx = /^([-=])\1*\s*$/
  atx = [[OGRegularExpression alloc] initWithString:@"^([-=])\\1*\\s*$"];
  // blank = /^\s*$/
  blank = [[OGRegularExpression alloc] initWithString:@"^\\s*$"];
  // @indented = /^\s+(?=\S)/
  indented = [[OGRegularExpression alloc] initWithString:@"^\\s+(?=\\S)"];

  mainOrder = [[NSArray alloc] initWithObjects:plainType, codeType, hrType, refType, headerType, quoteType, listType, nil];
  lineBlocks = [[NSArray alloc] initWithObjects:plainType, codeType, hrType, refType, headerType, nil];
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

- (void)indent:(NSMutableAttributedString *)string for:(NSArray *)stack {
  int level = 0;
  for (MDBlock *block in stack) {
    if (block.type == listType ||
	block.type == quoteType) {
      level += 1;
    }
  }

  if (level > 0) [string addAttributes:[self attributesForIndentTo:level leadOffset:16] range:NSMakeRange(0, [string length])];
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

- (NSFont *)headerFontForFont:(NSFont *)font bold:(bool) bold {
  NSFontManager *fontManager = [NSFontManager sharedFontManager];

//  NSFont *font = [NSFont userFontOfSize:size];
  font = [fontManager convertFont:font toSize:24];
  
  if (bold)
    font = [fontManager convertFont:font toHaveTrait:NSFontBoldTrait];

  return font;
}

// - (int)occurencesOf:(NSString *)divider in:(NSString *)target {
//   return [[target componentsSeparatedByString:divider] count] - 1;
// }

- (void)markAsMeta:(NSMutableAttributedString *)string range:(NSRange)range {
  int size = [self fontSizeOfString:string atIndex:range.location];
  NSFont *font = [self codeFontForSize:size];
  
  [string addAttribute:NSFontAttributeName value:font range:range];
  [string addAttributes:metaAttributes range:range];
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

// def pop_paragraph_blocks stack
//   unless stack.empty? or stack.first.first != :list
//     stack.pop until stack.empty? or stack.last.first == :list
//   end
// end
- (void) popParagraphBlocks:(NSMutableArray *)stack {
  MDBlock *first;
  if ([stack count] > 0) first = [stack objectAtIndex:0];
  if (first == nil || first.type == listType)
    return;

  [self popBlocks:stack checkFn:^(MDBlock *block) {
      return (bool) (block.type != listType);
    }];
}

// def push_paragraph_block stack, type, indent
//   if stack.all? { |bl| 
//       t,i = bl
//       indent > i
//     }
//     stack.push [type, indent] 
//   end
// end
- (void) pushParagraphBlock:(NSMutableArray *)stack block:(MDBlock *)block {
  // buggy, skips the above check for nesting doubles eg "> > qq\n> > qq"
  [stack addObject:block];
}

// def mark_line line_no, stack, line
//   puts "#{line_no}: #{stack.inspect}: '#{line.to_s.chomp}'"
// end
- (void) markLine:(NSMutableAttributedString *)line stack:(NSArray *)stack {
  if (line != nil && stack != nil) {
  NSMutableArray *localStack = [NSMutableArray arrayWithArray:stack];
//  NSLog(@"%@: %@", stack, [line string]);
    
  [self indent:line for:localStack];

    while ([localStack count] > 0) {
      MDBlock *block = [localStack objectAtIndex:0];
      [localStack removeObjectAtIndex:0];

      NSRange all = NSMakeRange(block.indent, [line length] - block.indent);
      NSRange prefix = NSMakeRange(block.indent, block.prefixLength);
      if (prefix.length > all.length) prefix.length = all.length;
      NSRange content = NSMakeRange(block.indent + block.prefixLength, all.length - prefix.length);

      if (prefix.length > 0) [self markAsMeta:line range:prefix];

      if (content.length > 0) {
//	NSLog(@"%@: '%@' %d %d", block, [line string], prefix.length, all.length);

	if (block.type == codeType) {
	  [line addAttributes:codeAttributes range:all];
	  [line addAttribute:NSToolTipAttributeName value:[line attributedSubstringFromRange:content] range:all];
	  //      NSLog(@"%@", [storage string]);
	  [line addAttribute:NSFontAttributeName value:[self codeFontForSize:12] range:content];
	} else if (block.type == headerType) {
	  NSDictionary *attributes = h1Attributes;
//      if (headerPrefix.length == 1)
//	attributes = h1Attributes;
//      else
//	attributes = h2Attributes;
	  
	  NSFont *font = [self headerFontForFont:[self fontOfString:line atIndex:content.location] bold:true];
	  //(headerPrefix.length == 1)];
	  [line addAttribute:NSFontAttributeName value:font range:content];
	  [line addAttributes:attributes range:content];
	  // need to mark suffix too
	  // [self markAsMeta:line range:[match rangeOfSubstringAtIndex:3]];
	} else if (block.type == quoteType) {
	  [line addAttributes:blockquoteAttributes range:content];
	} else if (block.type == refType) {
	  
	} else if (block.type == hrType) {
	  [line addAttributes:hrAttributes range:all];
	} else {
	  // other type
	}
      }
    }
  }
}

// def line_indent line, stack
//   m = line.match(@indented)  
//   m[0].length if m && stack.first && stack.first.first == :list
// end
- (int) indentForLine:(NSAttributedString *)string stack:(NSArray *)stack {
  OGRegularExpressionMatch *match;
  MDBlock *first = nil;
  if ([stack count] > 0) first = [stack objectAtIndex:0];
  
  if (first != nil && first.type == listType && (match = [indented matchInAttributedString:string]) != nil) {
    return [match rangeOfMatchedString].length;
  } else {
    return 0;
  }
}

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
  NSTextStorage *storage = [aNotification object];
  NSMutableAttributedString *string;
  
  NSRange edited = [storage editedRange];
  NSLog(@"%d->%d", edited.location, edited.length);
  string = storage;//[storage attributedSubstringFromRange:edited];
  
  [storage beginEditing];
  
  NSRange storageRange = edited;
  [storage removeAttribute:NSParagraphStyleAttributeName range:storageRange];
  [storage removeAttribute:NSFontAttributeName range:storageRange];
  [storage removeAttribute:NSForegroundColorAttributeName range:storageRange];
  [storage removeAttribute:NSBackgroundColorAttributeName range:storageRange];
  [storage removeAttribute:NSKernAttributeName range:storageRange];
  [storage removeAttribute:NSToolTipAttributeName range:storageRange];
  [storage removeAttribute:MarkdownCodeSection range:storageRange];
  [storage removeAttribute:NSLinkAttributeName range:storageRange];
  [storage addAttributes:defaultAttributes range:storageRange];

  NSMutableArray *stack, *prevStack;
  NSMutableAttributedString *prevLine;
  bool newPara = true;
  int indent = 0;
  stack = [NSMutableArray array];

//  OGRegularExpressionMatch *match;
//  for (match in [[OGRegularExpression regularExpressionWithString:@"/[^\\n]*?\\n/"] matchEnumeratorInAttributedString:string]) {
//    NSMutableAttributedString *l = [storage mutableAttributedSubstringFromRange:[match rangeOfMatchedString]];
  for (NSTextStorage *l in [storage paragraphs]) {
    [self popLineBlocks:stack];

    NSMutableAttributedString *line = l;
    indent = 0;

    if ([blank matchInAttributedString:line] != nil) {
      [self popParagraphBlocks:stack];
      newPara = true;
      [self markLine:prevLine stack:prevStack];
      continue;
    } else if (newPara) {
      newPara = false;

      int paraIndent = [self indentForLine:line stack:stack];
      if (paraIndent > 0) {
	[self popIndentedBlocks:stack indent:paraIndent];
	[self markAsMeta:line range:NSMakeRange(0, paraIndent)];

	match = [indented matchInAttributedString:line];
	if (match)
	  line = [[[NSMutableAttributedString alloc] initWithAttributedString:[match attributedSubstringAtIndex:1]] autorelease];
      } else {
	stack = [NSMutableArray array];
      }
      
    } else if (!newPara && (match = [atx matchInAttributedString:line])) { // ATX header
      prevStack = [NSMutableArray array];
      [self pushParagraphBlock:prevStack block:[MDBlock blockWithType:headerType indent:0 prefix:0]];
      [self markLine:prevLine stack:prevStack];

      prevStack = [NSMutableArray array];
      NSRange mRange = [match rangeOfMatchedString];
      [self pushParagraphBlock:prevStack block:[MDBlock blockWithType:headerType indent:0 prefix:mRange.length]];
      prevLine = l;	     // whole line, not subsection

      continue;
    } else {
      [self markLine:prevLine stack:prevStack];
    }

    NSMutableArray *order = [NSMutableArray arrayWithArray:mainOrder];
    NSString *type;
    while ([order count] > 0) {
      type = [order objectAtIndex:0];
      [order removeObjectAtIndex:0];
      
      NSMutableArray *process = [NSMutableArray arrayWithArray:[blocks objectForKey:type]];
      OGRegularExpression *regex = [process objectAtIndex:0];
      [process removeObjectAtIndex:0];
      
      if (match = [regex matchInAttributedString:line]) {
	NSRange mRange = [match rangeOfMatchedString];
	
	[self pushParagraphBlock:stack block:[MDBlock blockWithType:type indent:indent prefix:mRange.length]];
	indent += mRange.length;
	order = process;
	
	NSRange range = NSMakeRange(mRange.location + mRange.length, [line length] - mRange.length);
	line = [[[NSMutableAttributedString alloc] initWithAttributedString:[line attributedSubstringFromRange:range]] autorelease];

	if (type == refType) {
	  NSString *ref = [match substringAtIndex:1];
	  NSString *url = [match substringAtIndex:2];
	  // NSString *title = [match substringAtIndex:3];
	  [references setObject:url forKey:ref];
	}

      }
    }
    
    prevLine = l;
    prevStack = [NSMutableArray array];
    MDBlock *new;
    for (MDBlock *block in stack) {
      new = [block copy];
      [prevStack addObject:new];
//      block.indent += block.prefixLength;
      block.prefixLength = 0;
    }
    
  }

  if (prevLine != nil && prevLine != nil)
    [self markLine:prevLine stack:prevStack];

  // [references removeAllObjects];
  // for (OGRegularExpressionMatch *match in [refRegex matchEnumeratorInAttributedString:storage]) {
  //   NSRange range = [match rangeOfMatchedString];
  //   NSString *ref = [match substringAtIndex:1];
  //   NSString *url = [match substringAtIndex:2];
  //   NSString *title = [match substringAtIndex:3];
  //   [references setObject:url forKey:ref];
  //   [self markAsMeta:storage range:range];
  //   [storage addAttributes:[self attributesForIndentTo:1 leadOffset:0] range:range];
  // }
  
  for (OGRegularExpressionMatch *match in [inlinePattern matchEnumeratorInAttributedString:string]) {
    NSRange mRange = [match rangeOfMatchedString];
//        NSLog(@"%@ %@ %@", [match matchedString], [match substringAtIndex:1], [match substringAtIndex:2]);
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
    }
  }
 
  for (OGRegularExpressionMatch *match in [image matchEnumeratorInAttributedString:string]) {    
    [self markAsMeta:string range:[match rangeOfMatchedString]];
  }
     
  for (OGRegularExpressionMatch *match in [linkRegex matchEnumeratorInAttributedString:string]) {
    NSRange mRange = [match rangeOfMatchedString];
    NSRange textRange = [match rangeOfSubstringAtIndex:1];
//	NSLog(@"text: %d %d", textRange.location, textRange.length);
    NSRange urlRange = [match rangeOfSubstringAtIndex:2];
//	NSLog(@"url: %d %d", urlRange.location, urlRange.length);

    if (urlRange.location != NSNotFound && textRange.location != NSNotFound) {
      [self markAsMeta:string range:NSMakeRange(mRange.location, 1)];
      [self markAsMeta:string range:NSMakeRange(urlRange.location - 2, urlRange.length + 3)]; // '](' before url and ')' after
      [string addAttribute:NSLinkAttributeName value:[NSURL URLWithString:[self urlForLink:[match substringAtIndex:2]]] range:textRange];
    }
  }

  [storage fixAttributesInRange:NSMakeRange(0, [storage length])];
  [storage endEditing];
}

@end
