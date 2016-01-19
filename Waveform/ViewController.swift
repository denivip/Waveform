//
//  ViewController.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIView

class ViewController: UIViewController {

    var sourceFile = "video.m4v" //"440Hz-5sec.mp4"

    lazy var analizer: DVGAudioAnalyzer = {
        
        let fileURL = NSBundle.mainBundle().URLForResource(self.sourceFile, withExtension: nil)!
        return DVGAudioAnalyzer(asset: AVAsset(URL: fileURL))
    }()
    
    @IBOutlet weak var audioWaveformPlot: AudioWaveformPlot!
    
    var audioWaveformPlotModel = AudioWaveformPlotModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func buttonPressed() {
        self.prepareAudioWaveformPlot()
        self.startReading()
    }
    
    func prepareAudioWaveformPlot() {
        // 1. Prepare DataSource with logic providers
        let dataSource = analizer
        dataSource.configureChannelsForLogicProviderTypes([
            MaxValueLogicProvider.self,
            AverageValueLogicProvider.self
            ])
        
        // 2. Prepare Plot Model with DataSource ???
        self.audioWaveformPlotModel.addChannelSource(dataSource)

        // 3. Set plot model to plot view
        self.audioWaveformPlot.viewModel = self.audioWaveformPlotModel
        
        // 4. Customization
        let waveform1 = self.audioWaveformPlot.waveformWithIdentifier(analizer.identifierForLogicProviderType(MaxValueLogicProvider))
        waveform1?.lineColor = UIColor.redColor()
        
        let waveform2 = self.audioWaveformPlot.waveformWithIdentifier(analizer.identifierForLogicProviderType(AverageValueLogicProvider))
        waveform2?.lineColor = UIColor.greenColor()
    }
    
    func startReading() {
        self.audioWaveformPlot.startSynchingWithDataSource()
        let date = NSDate()
        self.analizer.prepareToRead {
            [weak self] (success) -> () in
            if success {
                self?.analizer.read(320) {
                    print("time: \(-date.timeIntervalSinceNow)")
//                    self?.audioWaveformPlot.stopSynchingWithDataSource()
                }
            }
        }
    }
}

