//
//  AudioWaveformViewModel.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import Foundation

class AudioWaveformViewModel: NSObject, AudioWaveformViewDataSource {
    
    weak var plotModel: AudioWaveformPlotModel?
    weak var channel: AbstractChannel?
    
    var pointsCount = 0
    var bounds      = CGSize(width: 1.0, height: 1.0)
    var scale: CGFloat { return self.plotModel?.scale ?? 1.0 }
    var start: CGFloat { return self.plotModel?.start ?? 0.0 }
    
    var scaledDx: CGFloat     = 0
    var scaledStartX: CGFloat = 0
    var startIndex: Int       = 0
    var identifier: String { return self.channel?.identifier ?? "" }
    
    func pointAtIndex(index: Int) -> CGPoint {
        
        if channel == nil {
            return .zero
        }
        
        let pointX     = scaledStartX + scaledDx * CGFloat(index)
        let pointIndex = startIndex + index
        
        let pointY: CGFloat
        if pointIndex < self.channel!.count {
            pointY = self.channel![pointIndex]
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
        
        let dx       = 1.0/CGFloat(channel!.totalCount - 1)
        scaledDx     = dx * scale
        startIndex   = Int(ceil(start/dx))
        scaledStartX = (CGFloat(startIndex) * dx - start) * scale
        
        var count = Int(ceil((1 - scaledStartX)/scaledDx + 0.000001))
        count     = max(0, min(count, self.channel!.count - startIndex))
        
        self.pointsCount = count
        
        var maxValue: CGFloat = 1.0
        for index in 0..<self.channel!.count {
            let value: CGFloat = self.channel![index]
            if maxValue < value {
                maxValue = value
            }
        }
        // TODO: If there are negative numbers too, height == 2 * max(maxValue, abs(minValue))
        self.bounds = CGSize(width: 1.0, height: maxValue)
    }
}
