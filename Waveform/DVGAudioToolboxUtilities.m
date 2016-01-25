//
//  DVGAudioToolboxUtilities.m
//  Denoise
//
//  Created by Nikolay Morev on 03.12.14.
//  Copyright (c) 2014 DENIVIP Group. All rights reserved.
//

#import "DVGAudioToolboxUtilities.h"
@import AudioToolbox;

NSString *DVGStringFromOSStatus(OSStatus status) {
    switch (status) {
        case kAudioQueueErr_InvalidBuffer:
            return @"kAudioQueueErr_InvalidBuffer";
        case kAudioQueueErr_BufferEmpty:
            return @"kAudioQueueErr_BufferEmpty";
        case kAudioQueueErr_DisposalPending:
            return @"kAudioQueueErr_DisposalPending";
        case kAudioQueueErr_InvalidProperty:
            return @"kAudioQueueErr_InvalidProperty";
        case kAudioQueueErr_InvalidPropertySize:
            return @"kAudioQueueErr_InvalidPropertySize";
        case kAudioQueueErr_InvalidParameter:
            return @"kAudioQueueErr_InvalidParameter";
        case kAudioQueueErr_CannotStart:
            return @"kAudioQueueErr_CannotStart";
        case kAudioQueueErr_InvalidDevice:
            return @"kAudioQueueErr_InvalidDevice";
        case kAudioQueueErr_BufferInQueue:
            return @"kAudioQueueErr_BufferInQueue";
        case kAudioQueueErr_InvalidRunState:
            return @"kAudioQueueErr_InvalidRunState";
        case kAudioQueueErr_InvalidQueueType:
            return @"kAudioQueueErr_InvalidQueueType";
        case kAudioQueueErr_Permissions:
            return @"kAudioQueueErr_Permissions";
        case kAudioQueueErr_InvalidPropertyValue:
            return @"kAudioQueueErr_InvalidPropertyValue";
        case kAudioQueueErr_PrimeTimedOut:
            return @"kAudioQueueErr_PrimeTimedOut";
        case kAudioQueueErr_CodecNotFound:
            return @"kAudioQueueErr_CodecNotFound";
        case kAudioQueueErr_InvalidCodecAccess:
            return @"kAudioQueueErr_InvalidCodecAccess";
        case kAudioQueueErr_QueueInvalidated:
            return @"kAudioQueueErr_QueueInvalidated";
        case kAudioQueueErr_RecordUnderrun:
            return @"kAudioQueueErr_RecordUnderrun";
        case kAudioQueueErr_EnqueueDuringReset:
            return @"kAudioQueueErr_EnqueueDuringReset";
        case kAudioQueueErr_InvalidOfflineMode:
            return @"kAudioQueueErr_InvalidOfflineMode";
        case kAudioFormatUnsupportedDataFormatError:
            return @"kAudioFormatUnsupportedDataFormatError";
        case kAudioFileUnspecifiedError:
            return @"kAudioFileUnspecifiedError";
        case kAudioFileUnsupportedFileTypeError:
            return @"kAudioFileUnsupportedFileTypeError";
        case kAudioFileUnsupportedPropertyError:
            return @"kAudioFileUnsupportedPropertyError";
        case kAudioFileBadPropertySizeError:
            return @"kAudioFileBadPropertySizeError";
        case kAudioFileNotOptimizedError:
            return @"kAudioFileNotOptimizedError";
        case kAudioFileInvalidChunkError:
            return @"kAudioFileInvalidChunkError";
        case kAudioFileDoesNotAllow64BitDataSizeError:
            return @"kAudioFileDoesNotAllow64BitDataSizeError";
        case kAudioFileInvalidPacketOffsetError:
            return @"kAudioFileInvalidPacketOffsetError";
        case kAudioFileOperationNotSupportedError:
            return @"kAudioFileOperationNotSupportedError";
        case kAudioFileNotOpenError:
            return @"kAudioFileNotOpenError";
        case kAudioFileEndOfFileError:
            return @"kAudioFileEndOfFileError";
        case kAudioFilePositionError:
            return @"kAudioFilePositionError";
        case kAudioFileFileNotFoundError:
            return @"kAudioFileFileNotFoundError";
        case kExtAudioFileError_NonPCMClientFormat:
            return @"kExtAudioFileError_NonPCMClientFormat";
        default:
            return @"Unknown error";
    }
}
