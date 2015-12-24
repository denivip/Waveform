//
//  AudioWaveformPlotModel.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import Foundation
import UIKit.UIColor

final
class AudioWaveformPlotModel: NSObject, AudioWaveformPlotDataSource {

    private var asset: AVAsset!
    private lazy var pcmReader : DVGAudioAnalyzer = {
        let analizer = DVGAudioAnalyzer(asset: self.asset)
        return analizer
    }()
    
    private var plot: _AudioWaveformPlot?
    private var viewModels = [AudioWaveformViewModel]()
    
    private override init() {
        super.init()
    }
    convenience init(asset: AVAsset) {
        self.init()
        self.asset = asset
    }
    
    func buildWaveformPlot(waveformPlot: _AudioWaveformPlot) {
        self.plot = waveformPlot
        
        self.addOriginalMaxWaveformView()
        self.addOriginalAverageWaveformView()
        
        self.plot?.startSynchingWithDataSource()
        
        self.pcmReader.prepareToRead { [weak self] success in
            if success {
                let date = NSDate()
                self?.pcmReader.readPCMs(neededPulsesCount: 2208) {
                    let time = -date.timeIntervalSinceNow
                    print("time = \(time)")
                    self?.plot?.redraw()
                }
            }
        }
    }
    
    private func addOriginalMaxWaveformView() {
        let waveformViewOrigMax        = self.plot?.addWaveformViewWithId("orig.max")
        waveformViewOrigMax?.lineColor = UIColor.blackColor()
        
        let waveformViewModel                  = AudioWaveformViewModel()
        //FIXME: Retain cycle
        waveformViewModel.onMaxPulse           = { return   self.pcmReader.maxPulse }
        waveformViewModel.onTotalPulsesCount   = { return   self.pcmReader.totalPulsesCount }
        waveformViewModel.onCurrentPulsesCount = { return   self.pcmReader.currentPulsesCount }
        waveformViewModel.onPulseAtIndex       = { index in self.pcmReader.maxPulseAtIndex(index) }
        
        waveformViewOrigMax?.dataSource = waveformViewModel
        self.viewModels.append(waveformViewModel)
    }
    
    private func addOriginalAverageWaveformView() {
        let waveformViewOrigMax        = self.plot?.addWaveformViewWithId("orig.avg")
        waveformViewOrigMax?.lineColor = UIColor.lightGrayColor()
        
        let waveformViewModel                  = AudioWaveformViewModel()
        //FIXME: Retain cycle
        waveformViewModel.onMaxPulse           = { return   self.pcmReader.maxPulse }
        waveformViewModel.onTotalPulsesCount   = { return   self.pcmReader.totalPulsesCount }
        waveformViewModel.onCurrentPulsesCount = { return   self.pcmReader.currentPulsesCount }
        waveformViewModel.onPulseAtIndex       = { index in self.pcmReader.avgPulseAtIndex(index) }
        
        waveformViewOrigMax?.dataSource = waveformViewModel
        self.viewModels.append(waveformViewModel)
    }
}
