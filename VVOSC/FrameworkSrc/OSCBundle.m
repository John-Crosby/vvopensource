
#import "OSCBundle.h"
#import "VVBasicMacros.h"
#import "OSCInPort.h"




@implementation OSCBundle


+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p inheritedTimeTag:(NSDate *)d fromAddr:(unsigned int)txAddr port:(unsigned short)txPort	{
	//NSLog(@"%s",__func__);
	if ((b == nil) || (l == 0) || (p == NULL))
		return;
/*	
	- remember, OSC data is clumped in a minimum of 4 byte groups!
	- bytes 0-7 consist of '#bundle', and then a null character to make it an even multiple of 4 (8 bytes, total, for this)
	- bytes 8-15 is an 8-byte (64-bit!) OSC time tag which ostensibly applies to the entire contents of the bundle
	...this is followed by zer or more bundle elements (either messages or more bundles).  each element consists of two things:
		1)- a 4-byte (32-bit) int describing the length of the element that's about to follow
		2)- the element itself, whether it's a message or a bundle
*/
	//	calculate the timetag for the bundle...
	uint32_t		time_s = CFSwapInt32HostToBig(*((uint32_t *)(b+8)));
	uint32_t		time_us = CFSwapInt32HostToBig(*((uint32_t *)(b+12)));
	NSDate			*localTimeTag = nil;
	if (time_s==0 && (time_us==0 || time_us==1))
		localTimeTag = d;
	else	{
		double			timeSinceRefDate = ((double)(time_s)) + ((double)time_us)/((double)4294967296.0);
		//	...the "reference date" in OSC is 1/1/1900, so we have to account for one century plus one year's worth of seconds to this...
		timeSinceRefDate -= 3187296000.;
		localTimeTag = [NSDate dateWithTimeIntervalSinceReferenceDate:timeSinceRefDate];
	}
	int				baseIndex = 16;	//	baseIndex is now pointing to the int describing the length of the first element
	unsigned char	*c = b;
	int				length = 0;
	
	while (baseIndex < l)	{
		//	assemble the int describing the length of the first element
		length = (c[baseIndex+3]) + (c[baseIndex+2] << 8) + (c[baseIndex+1] << 16) + (c[baseIndex] << 24);
		//	advance the baseIndex so it's pointing at the start of the first element
		baseIndex = baseIndex + 4;
		//	parse the first element, which is either a bundle or a msg
		BOOL			isBundle = NO;
		if ((c[baseIndex]=='#') && (c[baseIndex+1]=='b'))
			isBundle = YES;
		
		if (isBundle)	{
			[OSCBundle
				parseRawBuffer:b+baseIndex
				ofMaxLength:length
				toInPort:p
				inheritedTimeTag:localTimeTag
				fromAddr:txAddr
				port:txPort];
		}
		else	{
			OSCMessage		*tmpMsg = [OSCMessage
				parseRawBuffer:b+baseIndex
				ofMaxLength:length
				fromAddr:txAddr
				port:txPort];
			if (tmpMsg != nil)	{
				if (localTimeTag != nil)
					[tmpMsg setTimeTag:localTimeTag];
				//	now that i've assembed the message, send it to the in port
				[p _addMessage:tmpMsg];
			}
			else	{
				NSLog(@"\t\terr: breaking, message couldn't be parsed. %s",__func__);
				break;
			}
		}
		
		//	advance the baseIndex so it's pointing at the the int describing the length of the next element (or done)
		baseIndex = baseIndex + length;
	}
}

+ (id) create	{
	OSCBundle		*returnMe = [[OSCBundle alloc] init];
	if (returnMe == nil)
		return nil;
	return returnMe ;
}
+ (id) createWithElement:(id)n	{
	OSCBundle		*returnMe = [[OSCBundle alloc] init];
	if (returnMe == nil)
		return nil;
	if (n != nil)
		[returnMe addElement:n];
	return returnMe ;
}
+ (id) createWithElementArray:(id)a	{
	OSCBundle		*returnMe = [[OSCBundle alloc] init];
	if (returnMe == nil)
		return nil;
	if (a != nil)
		[returnMe addElementArray:a];
	return returnMe ;
}
- (id) init	{
	if (self = [super init])	{
		elementArray = [NSMutableArray arrayWithCapacity:0];
		timeTag = nil;
		return self;
	}
	self ;
	return nil;
}

- (void) dealloc	{
//	VVRELEASE(elementArray);
//	VVRELEASE(timeTag);
//	[super dealloc];
}

- (void) addElement:(id)n	{
	if (n == nil)
		return;
	if ((![n isKindOfClass:[OSCBundle class]]) && (![n isKindOfClass:[OSCMessage class]]))
		return;
	[elementArray addObject:n];
}
- (void) addElementArray:(NSArray *)a	{
	if ((a==nil) || ([a count]<1))
		return;
	for (id anObj in a)	{
		if (([anObj isKindOfClass:[OSCBundle class]]) || ([anObj isKindOfClass:[OSCMessage class]]))	{
			[elementArray addObject:anObj];
		}
	}
}

- (long) bufferLength	{
	//NSLog(@"%s",__func__);
	long			totalSize = 0;
	//NSEnumerator	*it;
	//id				anObj;
	
	/*
	a bundle starts off with:
		8 bytes for the '#bundle'
		8 bytes for the timestamp
	*/
	totalSize = 16;
	
	//	run through my elements, getting their sizes
	//it = [elementArray objectEnumerator];
	//while (anObj = [it nextObject])	{
	for (id anObj in elementArray)	{
		/*
		each element will occupy an amount of space equal to the size of the payload plus
		4 bytes (these 4 bytes are used to store the size of the payload which follows it)
		*/
		totalSize = totalSize + 4 + [anObj bufferLength];
	}
	
	return totalSize;
}
- (void) writeToBuffer:(unsigned char *)b	{
	if (b == NULL)
		return;
	int				writeOffset;
	int				elementLength;
	UInt32			tmpInt;
	//NSEnumerator	*it;
	//id				anObj;
	
	//	write the "#bundle" to the buffer (bytes 0-7)
	strncpy((char *)b, "#bundle", 7);
	//	if there's a timetag, write that to the buffer (otherwise write an immediate timetag)- bytes 8-15
	if (timeTag == nil)	{
		writeOffset = 15;
		*((long *)(b+writeOffset)) = 1;
	}
	else	{
		//	the interval since ref date gives us the interval since 1/1/2001
		NSTimeInterval		interval = [timeTag timeIntervalSinceReferenceDate];
		//	...the "reference date" in OSC is 1/1/1900, so we have to account for one century plus one year's worth of seconds to this...
		interval += 3187296000.;
		uint32_t		time_s = CFSwapInt32HostToBig((uint32_t)floor(interval));
		uint32_t		time_us = CFSwapInt32HostToBig((uint32_t)(floor((double)4294967296.0 * ((double)(interval - floor(interval))))));
		writeOffset = 8;
		*((long *)(b+writeOffset)) = time_s;
		writeOffset = 12;
		*((long *)(b+writeOffset)) = time_us;
	}
	//	adjust the write offset so it's after the timetag...
	writeOffset = 16;
	//	run through all the elements in this bundle
	//it = [elementArray objectEnumerator];
	//while (anObj = [it nextObject])	{
	for (id anObj in elementArray)	{
		//	write the message's size to the buffer
		elementLength = (int)[anObj bufferLength];
		tmpInt = htonl(*((UInt32 *)(&elementLength)));
		memcpy(b+writeOffset, &tmpInt, 4);
		//	adjust the write offset to compensate for writing the message size
		writeOffset = writeOffset + 4;
		//	write the message to the buffer
		[anObj writeToBuffer:b+writeOffset];
		//	adjust the write offset to compensate for the data i just wrote to the buffer
		writeOffset = writeOffset + elementLength;
	}
}


@synthesize timeTag;


@end
