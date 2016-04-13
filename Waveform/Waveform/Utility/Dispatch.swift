//
//  Dispatch.swift
//  Waveform
//
//  Created by developer on 13/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

let processingQueue = dispatch_queue_create("ru.denivip.denoise.processing", DISPATCH_QUEUE_SERIAL)

public func runAsynchronouslyOnProcessingQueue(block: dispatch_block_t) {
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(self.processingQueue)) {
        autoreleasepool(block)
    } else {
        dispatch_async(self.processingQueue, block);
    }
}