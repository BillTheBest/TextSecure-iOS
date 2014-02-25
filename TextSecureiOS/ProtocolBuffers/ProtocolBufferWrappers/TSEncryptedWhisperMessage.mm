//
//  TSWhisperMessage.m
//  TextSecureiOS
//
//  Created by Christine Corbett Moran on 1/6/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSEncryptedWhisperMessage.hh"
#import "WhisperMessage.pb.hh"
@implementation TSEncryptedWhisperMessage
@synthesize ephemeralKey;
@synthesize counter;
@synthesize previousCounter;
@synthesize message;


-(id) initWithEphemeralKey:(NSData*)ephemeral previousCounter:(NSNumber*)prevCounter counter:(NSNumber*)ctr encryptedMessage:(NSData*)ciphertext {
    if(self = [super init]) {
        self.ephemeralKey = ephemeral;
        self.previousCounter = prevCounter;
        self.counter = ctr;
        self.message=ciphertext;
    }
    return self;
}
-(id) initWithData:(NSData*) data {
    /*
     optional bytes  ephemeralKey    = 1;
     optional uint32 counter         = 2;
     optional uint32 previousCounter = 3;
     optional bytes  ciphertext      = 4;
     */
    if(self = [super init]) {
        // c++
        textsecure::WhisperMessage *whisperMessage = [self deserialize:data];
        const std::string cppEphemeralKey =  whisperMessage->ephemeralkey();
        
        const uint32_t cppCounter = whisperMessage->counter();
        const uint32_t cppPreviousCounter = whisperMessage->previouscounter();
        const std::string cppMessage = whisperMessage->ciphertext();
        // c++->objective C
        self.ephemeralKey = [self cppStringToObjcData:cppEphemeralKey];
        NSLog(@"Result of ephemeral key : %lu ", (unsigned long)[self.ephemeralKey length]);
        self.counter = [self cppUInt32ToNSNumber:cppCounter];
        self.previousCounter = [self cppUInt32ToNSNumber:cppPreviousCounter];
        self.message = [self cppStringToObjcData:cppMessage];
    }
    return self; // super is abstract class
}


-(const std::string) serializedProtocolBufferAsString {
    textsecure::WhisperMessage *whisperMessage = new textsecure::WhisperMessage;
    // objective c->c++
    NSLog(@"Ephemeral key size %lu", (unsigned long)[self.ephemeralKey length]);
    const std::string cppEphemeralKey = [self objcDataToCppString:self.ephemeralKey];
    const uint32_t cppCounter = [self objcNumberToCppUInt32:self.counter];
    const uint32_t cppPreviousCounter = [self objcNumberToCppUInt32:self.previousCounter];
    const std::string cppMessage =  [self objcDataToCppString:self.message];
    
    
    // c++->protocol buffer
    whisperMessage->set_ephemeralkey(cppEphemeralKey);
    whisperMessage->set_counter(cppCounter);
    whisperMessage->set_previouscounter(cppPreviousCounter);
    whisperMessage->set_ciphertext(cppMessage);
    std::string ps = whisperMessage->SerializeAsString();
    
    return ps;
}

#pragma mark private methods
- (textsecure::WhisperMessage *)deserialize:(NSData *)data {
    int len = [data length];
    char raw[len];
    textsecure::WhisperMessage *messageSignal = new textsecure::WhisperMessage;
    [data getBytes:raw length:len];
    messageSignal->ParseFromArray(raw, len);
    NSLog(@" Length when deserializing %lu",(unsigned long)[[self cppStringToObjcData:messageSignal->ephemeralkey()] length]);
    return messageSignal;
}

@end
