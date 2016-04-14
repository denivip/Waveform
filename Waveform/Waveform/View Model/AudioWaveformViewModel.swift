//
//  AudioWaveformViewModel.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit
import Foundation

class AudioWaveformViewModel: NSObject, AudioWaveformViewDataSource {
    
    weak var plotModel: AudioWaveformPlotModel?
    var channel: AbstractChannel? {
        didSet{
            self._identifier = channel?.identifier ?? ""
        }
    }
    
    var pointsCount = 0
    var bounds      = CGSize(width: 1.0, height: 1.0)
    var scale: CGFloat { return self.plotModel?.scale ?? 1.0 }
    var start: CGFloat { return self.plotModel?.start ?? 0.0 }
    
    var scaledDx: CGFloat     = 0
    var scaledStartX: CGFloat = 0
    var startIndex: Int       = 0
    var identifier: String    { return _identifier }
    var onGeometryUpdate: () -> () = {}
    
    var _identifier: String = ""
    
    func pointAtIndex(index: Int) -> CGPoint {
        guard let channel = self.channel else {
            return .zero
        }
        
        let pointX     = scaledStartX + scaledDx * CGFloat(index)
        let pointIndex = startIndex + index
        
        let pointY: CGFloat
        if pointIndex < channel.count {
            pointY = CGFloat(channel[pointIndex])
        } else {
            pointY = 0
        }
        
        return CGPoint(x: pointX, y: CGFloat(pointY))
    }
    
    func updateGeometry() {
        
        if channel == nil {
            self.pointsCount = 0
            return
        }
        
        if channel!.totalCount < 2 {
            self.pointsCount = 0
            return
        }
        
        let dx       = 1.0/(CGFloat(channel!.totalCount) - 1)
        scaledDx     = dx * scale
        startIndex   = Int(ceil(start/dx))
        
        scaledStartX = (CGFloat(startIndex) * dx - start) * scale
        
        var count = Int(ceil((1 - scaledStartX)/scaledDx + 0.000001))
        count     = max(0, min(count, self.channel!.count - startIndex))
        
        self.pointsCount = count

        let bounds  = self.plotModel!.maxWafeformBounds()
        self.bounds = bounds
        
        self.onGeometryUpdate()
    }
    
    deinit {
        self.channel = nil
    }
}
