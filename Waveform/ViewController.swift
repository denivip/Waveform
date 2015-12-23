//
//  ViewController.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIView

class ViewController: UIViewController {

    var sourceFile = "video.m4v"//"misha.m4v" //"440Hz-5sec.mp4"

    @IBOutlet weak var audioWaveformPlot: AudioWaveformPlot!
    
    lazy var audioWaveformPlotModel: AudioWaveformPlotModel = {
        let url       = NSBundle.mainBundle().URLForResource(self.sourceFile, withExtension: nil)!
        let viewModel = AudioWaveformPlotModel(asset: AVAsset(URL: url))
        return viewModel
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func buttonPressed() {
        self.prepareAudioWaveformPlot()
        self.startReading()
    }
    
    func prepareAudioWaveformPlot() {
    }
    
    func startReading() {
        self.audioWaveformPlotModel.buildWaveformPlot(self.audioWaveformPlot)
    }
}

