//
//  ViewController.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController, AudioWaveformPlotViewModelDelegate {

    var phAsset: PHAsset?
    var asset: AVAsset?
    var analizer: DVGAudioAnalyzer?
    
    @IBOutlet weak var audioWaveformPlot: AudioWaveformPlot!
    
    var audioWaveformPlotModel = AudioWaveformPlotModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let phAsset = self.phAsset {
            let options = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {_ in return false}
            
            phAsset.requestContentEditingInputWithOptions(options) { contentEditingInput, info in
                self.asset = contentEditingInput!.avAsset!
                if let asset = self.asset {
                    self.analizer = DVGAudioAnalyzer(asset: asset)
                }
            }
        }
    }
    
    @IBAction func readAudioAndDrawWaveform() {
        if analizer == nil { return }

        self.prepareAudioWaveformPlot()
        self.startReading()
    }
    
    func prepareAudioWaveformPlot() {
        // 2. Prepare Plot Model with DataSource ???
        self.audioWaveformPlotModel.addChannelSource(self.analizer!)
        self.audioWaveformPlotModel.delegate = self
        
        // 3. Set plot model to plot view
        self.audioWaveformPlot.viewModel = self.audioWaveformPlotModel
        
        // 4. Customization
        let waveform1 = self.audioWaveformPlot.waveformWithIdentifier(analizer!.identifierForLogicProviderType(MaxValueLogicProvider))
        waveform1?.lineColor = UIColor.redColor()
        
        let waveform2 = self.audioWaveformPlot.waveformWithIdentifier(analizer!.identifierForLogicProviderType(AverageValueLogicProvider))
        waveform2?.lineColor = UIColor.greenColor()
    }
    
    var plotPointsCount = 512
    
    func startReading() {
        self.audioWaveformPlot.startSynchingWithDataSource()
        let date = NSDate()
        self.analizer!.prepareToRead {
            [weak self] (success) -> () in
            if success {
                self?.analizer!.read(self!.plotPointsCount) {
                    print("time: \(-date.timeIntervalSinceNow)")
                    self?.audioWaveformPlot.stopSynchingWithDataSource()
                }
            }
        }
    }
    
    func plotMoved(scale: CGFloat, start: CGFloat) {
        self.analizer!.read(plotPointsCount, dataRange: DataRange(location: Double(start), length: 1.0/Double(scale)))
    }
}



