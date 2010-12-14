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
static NSString *setexMarkerType = @"setexMarker";

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
  newReferences = false;

  MarkdownCodeSection = @"MarkdownCodeSection";

  NSMutableParagraphStyle *ps;
//  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setHeadIndent:28];
//  [ps setFirstLineHeadIndent:16];
//  [ps setTailIndent:-28];
  blockquoteAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
//					  ps, NSParagraphStyleAttributeName,
						[NSFont fontWithName:@"Times-Italic" size:16], NSFontAttributeName,
					nil
      ] retain];

  NSColor *grey = [NSColor lightGrayColor];
  NSFont *normal = [NSFont fontWithName:@"Times" size:16]; //[NSFont userFontOfSize:14];

  metaAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				    grey, NSForegroundColorAttributeName,
				  nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
  [ps setLineBreakMode:NSLineBreakByTruncatingTail];
  codeAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			     [NSColor colorWithCalibratedWhite:0.95 alpha:1.0], NSBackgroundColorAttributeName,
				  ps, NSParagraphStyleAttributeName,
				  [[[NSObject alloc] init] autorelease], MarkdownCodeSection,
				  nil
      ] retain];

  strongAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				    nil
      ] retain];

  emAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
//  int lineHeight = 20;
//  [ps setMinimumLineHeight:lineHeight];
//  [ps setMaximumLineHeight:lineHeight];
//  [ps setParagraphSpacingBefore:lineHeight];
  h1Attributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				ps, NSParagraphStyleAttributeName,
				     [NSNumber numberWithInt:-1], NSKernAttributeName,
				nil
      ] retain];

  h2Attributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				ps, NSParagraphStyleAttributeName,
				     [NSNumber numberWithInt:-1], NSKernAttributeName,
				nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setMaximumLineHeight:12];
  blankAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				     ps, NSParagraphStyleAttributeName,
				   nil
      ] retain];

  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setMinimumLineHeight:lineHeight];
//  [ps setMaximumLineHeight:lineHeight];
  defaultAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				       ps, NSParagraphStyleAttributeName,
				     normal, NSFontAttributeName,
				     nil
      ] retain];

  NSTextAttachment *a = [[NSTextAttachment alloc] init];
  NSString *attachmentChar = [[NSAttributedString attributedStringWithAttachment:a] string];
  document.attachmentChar = attachmentChar;
  [a release];

  NSString *urlSuffix = @"\\((\\S+?)\\s*(\\\".+?\\\")?\\)"; // 1: url, 2: title
  NSString *refSuffix = @"\\[(.+?)\\]"; // 1: reference
  // 1: suffix, 2: url, 3: title, 4: ref
  NSString *linkSuffix = [NSString stringWithFormat:@"(%@|%@)", urlSuffix, refSuffix];

  // 1: text, 2: suffix, 3: url, 4: title, 5: ref
  NSString *baseRegex = [NSString stringWithFormat:@"\\[(.*?)\\]%@", linkSuffix];

  imageNoAttachment = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"!%@", baseRegex]];

  // 1: attachment, 2: text, 3: suffix, 4: url, 5: title, 6: ref
  attachedImage = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"!(%@)%@", attachmentChar, baseRegex]];

  // ! with attachment char and no image markup, or attachment char with markup but no leading !
  // 1: attachment 2: text, 3: suffix, 5: url, 5: title, 6: ref, 7: attachment
  attachmentNoImage = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?:[^!](%@)%@|!(%@)(?!%@))", attachmentChar, baseRegex, attachmentChar, baseRegex]];

  // ! (optional attachment char) [title] (uri)
  NSString *imageString = [NSString stringWithFormat:@"!%@?%@", attachmentChar, baseRegex];
  image = [[OGRegularExpression alloc] initWithString:imageString];

  inlinePattern = [[OGRegularExpression alloc] initWithString:@"\
(?<!\\\\)              \
(?<delimiter>          \
  (?<delimchar>[*_`])  \
  \\k<delimchar>?      \
)                      \
(?<content>.+?)        \
(?<end_delimiter>      \
  (?<!\\\\)            \
  \\k<delimiter>       \
)                      \
" options:OgreExtendOption];

  linkRegex = [[OGRegularExpression alloc] initWithString:[NSString stringWithFormat:@"(?<!!|%@)\\[((?:%@|.)*?)\\]%@", attachmentChar, imageString, linkSuffix]];

  ps = [[NSMutableParagraphStyle alloc] init];
//  [ps setMinimumLineHeight:lineHeight];
//  [ps setMaximumLineHeight:lineHeight];
  [ps setAlignment:NSCenterTextAlignment];
  hrAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				  ps, NSParagraphStyleAttributeName,
				normal, NSFontAttributeName,
				nil
      ] retain];

  blocks = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSArray arrayWithObjects:[OGRegularExpression regularExpressionWithString:
											   @"^(?:\\d+\\.\\s+|\\*\\s+)"],
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

  bareLink = [[OGRegularExpression alloc] initWithString:@"<(?<url>[^>]+)>"];

  mainOrder = [[NSArray alloc] initWithObjects:codeType, hrType, refType, headerType, quoteType, listType, nil];
  lineBlocks = [[NSArray alloc] initWithObjects:codeType, hrType, refType, headerType, setexType, nil];
}

- (int)attachImage:(NSURL *)url toString:(NSMutableAttributedString *)target atIndex:(int) index {
//  NSLog(@"Image with src %@", imageSrc);

  NSError *error = nil;
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

- (NSString *)urlForReference:(NSString *)link {
  return [references objectForKey:link];
}

- (void)addReference:(NSString *)urlString forKey:ref {
  if (urlString != nil) {
    [references setObject:urlString forKey:ref];
    newReferences = true;
  }
}

- (NSString *)urlStringForString:(NSString *)urlString orReference:(NSString *)reference {
  if (urlString != nil && [urlString length] > 0) {	// url
    return urlString;
  } else {			// reference
    return [self urlForReference:reference];
  }
}

- (NSURL *)urlForString:(NSString *)urlString orReference:(NSString *)reference {
  urlString = [self urlStringForString:urlString orReference:reference];
  return (urlString != nil ? [NSURL URLWithString:urlString relativeToURL:[document fileURL]] : nil);
}

- (void)textStorageWillProcessEditing:(NSNotification *)aNotification {
  NSTextStorage *storage = [aNotification object];
  NSString *stString = [storage string];

  OGRegularExpressionMatch *match;

  // find attachment with no markup
  for (match in [attachmentNoImage matchEnumeratorInString:stString]) {
    // 1: attachment 2: text, 3: suffix, 5: url, 5: title, 6: ref, 7: attachment

    // remove attachment
//    NSLog(@"ATTACHMENT NO IMAGE:%@", [match matchedString]);
    NSRange early = [match rangeOfSubstringAtIndex:1];
    NSRange late = [match rangeOfSubstringAtIndex:7];
    [storage beginEditing];
    if (early.location != NSNotFound) [storage replaceCharactersInRange:early withString:@""];
    if (late.location != NSNotFound) [storage replaceCharactersInRange:late withString:@""];
    [storage endEditing];
  }

  // find image with attachment char
  // Do this before adding attachments so incorrect images get fixed
  int deletions = 0;
  for (match in [attachedImage matchEnumeratorInString:stString]) {
    // 1: attachment, 2: text, 3: suffix, 4: url, 5: title, 6: ref
//    NSLog(@"IMAGE WITH ATTACHMENT: %@", [match matchedString]);

    NSString *src = [self urlStringForString:[match substringAtIndex:4] orReference:[match substringAtIndex:6]];

    NSRange attachmentRange = [match rangeOfSubstringAtIndex:1];
    attachmentRange.location -= deletions;
    NSTextAttachment *attachment = [storage attribute:NSAttachmentAttributeName atIndex:attachmentRange.location effectiveRange:nil];
//    NSLog(@"THE ATTACHMENT %@, the src %@ the char %@", attachment, src, [match substringAtIndex:1]);

    // validate attachment src
    if (![src isEqualToString:[[attachment fileWrapper] filename]]) {
      [storage beginEditing];
      [storage replaceCharactersInRange:attachmentRange withString:@""];
      deletions += 1;
      [storage endEditing];
//      NSLog(@"attachment different to source, stripped");
    } else {
//      NSLog(@"attachment name same as source");
    }
  }

  // find image markup (without attachment char)
  // Do this after removing attachments with incorrect images
  int attachmentCompensation = 1;
  for (match in [imageNoAttachment matchEnumeratorInString:stString]) {
    // 1: text, 2: suffix, 3: url, 4: title, 5: ref

    NSURL *url = [self urlForString:[match substringAtIndex:3] orReference:[match substringAtIndex:5]];
    // add attachment char with attachment
//    NSLog(@"IMAGE %@", [match matchedString]);
    NSRange imageRange = [match rangeOfMatchedString];

    int adjustment = 0;
//    NSLog(@"ATTACHMENT: %@", url);
    adjustment = [self attachImage:url toString:storage atIndex:imageRange.location + attachmentCompensation];
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

  [ps setHeadIndent:pointIndent];
  [ps setFirstLineHeadIndent:pointIndent - pixels];
//  [ps setTailIndent:-pointIndent];
  return [NSDictionary dictionaryWithObject: ps forKey:NSParagraphStyleAttributeName];
}

- (void)indent:(NSMutableAttributedString *)string range:(NSRange) range for:(NSArray *)stack {
  int level = 0;
  int prefixTotal = 0;
  for (MDBlock *block in stack) {
    if (block.type == listType ||
	block.type == quoteType) {
      level += 1;
      prefixTotal += block.prefixLength;
    }
  }

  if (level > 0) [string addAttributes:[self attributesForIndentTo:level leadOffset:8 * prefixTotal] range:range];
}

- (NSFont *)fontOfString:(NSAttributedString *)string atIndex:(int)index {
  return [string attribute:NSFontAttributeName atIndex:index effectiveRange:nil];
}

- (int)fontSizeOfString:(NSAttributedString *)string atIndex:(int)index {
  NSFont *font = [self fontOfString:string atIndex:index];
  return (font != nil) ? [font pointSize] : 16;
}

- (NSFont *)codeFontForSize:(int)size {
  return [NSFont fontWithName:@"Inconsolata" size:16]; //[NSFont userFontOfSize:14];
//  return [NSFont userFixedPitchFontOfSize:size-3];
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

  level = level < 6 ? level : 6;
  int size;
  switch (level) {
    case 1:
      size = 24;
      break;
    case 2:
      size = 21;
      break;
    case 3:
    case 4:
      size = 18;
      break;
    case 5:
    case 6:
      size = 16;
      break;
  }

  font = [fontManager convertFont:font toSize:size];

  if (level != 1 && level % 2 == 1)
    font = [fontManager convertFont:font toHaveTrait:NSFontBoldTrait];

  return font;
}

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

- (void) popLineBlocks:(NSMutableArray *)stack {
  [self popBlocks:stack checkFn:^(MDBlock *block) {
      return (bool) [lineBlocks containsObject:block.type];
    }];
  for (MDBlock *block in stack)
    block.prefixLength = 0;
}

- (void) popIndentedBlocks:(NSMutableArray *)stack indent:(int)indent {
  while ([stack count] > 1) { // Only indent 1 level
    [stack removeLastObject];
  }
  if ([stack count] == 1 && [[stack objectAtIndex:0] type] == listType && indent >= 2) { // Indent 2
    [[stack objectAtIndex:0] setPrefixLength:2];
  } else {
    [stack removeLastObject];
  }
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
    NSRange suffix = [match rangeOfSubstringAtIndex:7];
    NSRange urlRange = [match rangeOfSubstringAtIndex:8];
    // Do nothing with title for now
    // NSString *title = [match substringAtIndex:9];

    NSRange refRange = [match rangeOfSubstringAtIndex:10];
    NSURL *url = [self urlForString:[match substringAtIndex:8] orReference:[match substringAtIndex:10]];
//    NSLog(@"'%@': text:'%@' suffix:'%@' url:'%@' title:'%@' ref:'%@'", [match matchedString], [match substringAtIndex:1], [match substringAtIndex:7], [match substringAtIndex:8], [match substringAtIndex:9], [match substringAtIndex:10]);

    suffix.location -= 1;	// ']' before url+title
    suffix.length += 1;

    [self markAsMeta:string range:NSMakeRange(mRange.location, 1)]; // leading [
    [self markAsMeta:string range:suffix];
    if (url != nil) {
      [string addAttribute:NSLinkAttributeName value:url range:textRange];
    } else {
      [self markAsMeta:string range:textRange];
      [string addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:urlRange];
      [string addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:refRange];
    }
  }

  for (OGRegularExpressionMatch *match in [bareLink matchEnumeratorInAttributedString:string range:range]) {
    NSURL *url = [NSURL URLWithString:[match substringNamed:@"url"]];
    if (url != nil) {
      [string addAttribute:NSLinkAttributeName value:url range:[match rangeOfMatchedString]];
    }
  }

}

- (void)markImages:(NSMutableAttributedString *)string range:(NSRange)range {
  for (OGRegularExpressionMatch *match in [image matchEnumeratorInAttributedString:string range:range]) {
    [self markAsMeta:string range:[match rangeOfMatchedString]];
  }
}

- (void)markInlineElementsIn:(NSMutableAttributedString *)string range:(NSRange)range {
  if (range.length <= 2) return;

  for (OGRegularExpressionMatch *match in [inlinePattern matchEnumeratorInAttributedString:string range:range]) {
    NSRange mRange = [match rangeOfMatchedString];
    NSDictionary *attribs = nil;
    NSString *delimiter = [match substringNamed:@"delimiter"];
    NSFont *font = [self fontOfString:string atIndex:[match rangeOfSubstringNamed:@"content"].location];
    if (![self isCodeSection:string atIndex:[match rangeOfSubstringNamed:@"delimiter"].location]) { // don't set attributes in code blocks
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

    if (attribs != nil) {
      [string addAttribute:NSFontAttributeName value:font range:mRange];
      [string addAttributes:attribs range:mRange];
      [self markAsMeta:string range:[match rangeOfSubstringNamed:@"delimiter"]];
      [self markAsMeta:string range:[match rangeOfSubstringNamed:@"end_delimiter"]];
      if (attribs != codeAttributes) [self markInlineElementsIn:string range:[match rangeOfSubstringNamed:@"content"]];
    }
  }

  [self markImages:string range:range];
  [self markLinks:string range:range];
}

- (void) markLine:(NSMutableAttributedString *)line range:(NSRange) range stack:(NSArray *)stack {
  if (range.length > 0 && stack != nil) {

//    [line addAttribute:NSToolTipAttributeName value:[NSString stringWithFormat:@"%@", stack] range:range];

    NSMutableArray *localStack = [NSMutableArray arrayWithArray:stack];

    NSRange prefix = NSMakeRange(0,0);
    NSRange content = NSMakeRange(range.location, range.length);

    [self indent:line range:range for:localStack];

    int prefixLength = 0;
    while ([localStack count] > 0) {
      MDBlock *block = [localStack objectAtIndex:0];
      [localStack removeObjectAtIndex:0];

      prefix = NSMakeRange(range.location + prefixLength, block.prefixLength);
      if (prefix.length > range.length) prefix.length = range.length;
      content = NSMakeRange(prefix.location + prefix.length, 0);
      prefixLength += block.prefixLength;

      if (range.location + range.length > content.location)
	content.length = range.location + range.length - content.location;

      if (prefix.length > 0) [self markAsMeta:line range:prefix];

//	NSLog(@"%@: '%@' %d %d", block, [line string], prefix.length, all.length);
//	NSLog(@"%@ (%d %d): %@", stack, range.location, range.length, [[line attributedSubstringFromRange:content] string]);

      if (block.type == codeType) {
	[line addAttributes:codeAttributes range:range];
	//	NSLog(@"Not marking code tooltip");
	[line addAttribute:NSToolTipAttributeName value:[line attributedSubstringFromRange:content] range:range];
	[line addAttribute:NSFontAttributeName value:[self codeFontForSize:16] range:content];
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
	[self addReference:url forKey:ref];
      } else {
	// other types
	//NSLog(@"Dunno what to do with type '%@'", block.type);
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

- (NSRange) range:(NSRange) range constrainedTo:(NSAttributedString *)string {
  int length = [string length];
  if (range.location < 0) range.location = 0;
  if (range.location >= length) range.location = length == 0 ? 0 : length - 1;

  if (range.location + range.length > length) range.length = length - range.location;

  return range;
}

- (NSRange) expandRangeToParagraph:(NSRange) range forString:(NSAttributedString *)string {
  NSString *haystack = [string string];
  NSString *needle = @"\n\n";

  // Include current position in search
  NSRange prev = [self range:NSMakeRange(0, range.location + 1) constrainedTo:string];
  NSRange next = NSMakeRange(range.location + range.length - 1, 0);
  next.length = [haystack length] - next.location;
  next = [self range:next constrainedTo:string];

  prev = [haystack rangeOfString:needle options:NSBackwardsSearch range:prev];
  next = [haystack rangeOfString:needle options:0 range:next];

  // Add one to get to the middle of \n\n, ie. the start of the blank
  // line, not the end of the previous paragraph
  range.location = prev.location == NSNotFound ? 0 : prev.location + 1;
  range.length = (next.location == NSNotFound ? [haystack length] : next.location + 1) - range.location;

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

//  NSLog(@"editing:(\n|%@|\n)", [[string attributedSubstringFromRange:edited] string]);

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

  for (OGRegularExpressionMatch *lineMatch in [[OGRegularExpression regularExpressionWithString:@"[^\\n]*\\n?"] matchEnumeratorInAttributedString:string range:stringRange]) {
    NSRange lRange = [lineMatch rangeOfMatchedString];
    NSRange lineRange = NSMakeRange(lRange.location, lRange.length);
    OGRegularExpressionMatch *match;

    [self popLineBlocks:stack];

    indent = 0;

    NSRange paraIndent = [self indentForString:string range:lineRange stack:stack];

    if ([blank matchInAttributedString:string range:lineRange] != nil) {
      [self popParagraphBlocks:stack];
      newPara = true;
      [self markLine:string range:prevRange stack:prevStack];
      continue;
    } else if (newPara) {
      newPara = false;

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

    } else if (match = [setex matchInAttributedString:string range:lineRange]) { // SETEX header
      prevStack = [NSMutableArray array];
      [self pushParagraphBlock:prevStack block:[MDBlock blockWithType:setexType indent:0 prefix:0 match:match]];
      [self markLine:string range:prevRange stack:prevStack];

      prevStack = [NSMutableArray array];
      NSRange mRange = [match rangeOfMatchedString];
      [self pushParagraphBlock:prevStack block:[MDBlock blockWithType:setexMarkerType indent:0 prefix:mRange.length match:match]];
      prevRange = lineRange;	     // whole line, not subsection

      continue;
    } else {
      [self markLine:string range:prevRange stack:prevStack];

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
        // Indent wrapped paragraph
      }
    }


    // Start with the default set of types to check (mainOrder).  If
    // one matches, push that type on this line's stack of types,
    // adn replace the rest of the types to check with the types that
    // can nest inside the original matched type.
    //
    // E.g. default is `(quote, list, header)` matching against "* #
    // The header" quote doesn't match, remove it from list and move
    // on.
    //
    // List matches, so replace the rest of the types to check
    // (currently just `(header)`) with the types that can nest in a
    // list item `(header, list)`, and adjust the range of the string
    // to skip the inital "* ", leaving "# The header". Push
    // `listType` onto this line's block-type stack
    //
    // Try matching the list again: header matches, so replace the
    // list with what can succeed header (in header's case, nothing.),
    // push headerType onto the block stack, adjust the range to skip
    // the header markup "# " and loop again.
    //
    // Now the list of types that this line can be is empty, so we are done.
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

	lineRange = NSMakeRange(lineRange.location + mRange.length, lineRange.length - mRange.length);
      }
    }

    // Remember this line so that it's marked properly next time around
    prevRange = lRange;
    prevStack = [NSMutableArray array];
    MDBlock *new;
    for (MDBlock *block in stack) {
      new = [block copy];
      [prevStack addObject:new];
      if (block.type != listType) block.indent += block.prefixLength;
    }

  }

  // Since each line is marked when it's succeeding line is parsed, we
  // need to mark the last line of the document (which *doesn't have*
  // a succeeding line!)
  if (prevRange.length > 0 && prevStack != nil)
    [self markLine:string range:prevRange stack:prevStack];

  if (newReferences) {
    [self markLinks:string range:NSMakeRange(0, [string length])];
    [self markImages:string range:NSMakeRange(0, [string length])];
    newReferences = false;
  }

  [string fixAttributesInRange:stringRange];
  [storage endEditing];
}

@end
