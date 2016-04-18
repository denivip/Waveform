//
//  Dispatch.swift
//  Waveform
//
//  Created by developer on 13/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

let processingQueue = dispatch_queue_create("ru.denivip.waveform.processing", DISPATCH_QUEUE_SERIAL)

public func dispatch_asynch_on_global_processing_queue(block: dispatch_block_t) {
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(processingQueue)) {
        autoreleasepool(block)
    } else {
        dispatch_async(processingQueue, block);
    }
}

public func dispatch_asynch_on_global_processing_queue(body: () throws -> (), onCatch: (ErrorType?) -> ()) {
    dispatch_asynch_on_global_processing_queue {
        do {
            try body()
            onCatch(nil)
        }
        catch {
            onCatch(error)
        }
    }
}