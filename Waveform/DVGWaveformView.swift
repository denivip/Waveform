//
//  DVGWaveformView.swift
//  Waveform
//
//  Created by developer on 22/01/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

/// Entry point for Waveform UI Component
/// Creates all needed data sources, view models and views and sets needed dependencies between them
/// By default draws waveforms for max values and average values (see. LogicProvider class)

class DVGWaveformView: UIView {

    //MARK: - Initialization

    convenience init(asset: AVAsset) {
        self.init()
        self.asset = asset
    }
    
    convenience init(){
        self.init(frame: .zero)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addPlotView()
        self.configure()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addPlotView()
        self.configure()
    }

    //MARK: -
    //MARK: - Configuration
    //MARK: - Internal configuration
    func addPlotView() {
        self.plotView = AudioWaveformPlot()
        self.plotView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.plotView)
        self.plotView.attachBoundsOfSuperview()
    }
    
    func configure() {
        
        self.waveformDataSource = AudioSamplesSource()
        
        // Prepare Plot Model with DataSource
        self.plotViewModel.addChannelSource(self.waveformDataSource!)
        self.plotViewModel.delegate = self
        
        // Set plot model to plot view
        self.plotView.viewModel = self.plotViewModel
    }
    
    //MARK: - For external configuration
    func waveformWithIdentifier(identifier: String) -> AudioWaveformView? {
        return self.plotView.waveformWithIdentifier(identifier)
    }

    var maxValuesWaveform: AudioWaveformView? {
        if let dataSource = self.waveformDataSource {
            return waveformWithIdentifier(dataSource.identifierForLogicProviderType(AudioMaxValueLogicProvider))
        }
        return nil
    }
    
    var avgValuesWaveform: AudioWaveformView? {
        if let dataSource = self.waveformDataSource {
            return waveformWithIdentifier(dataSource.identifierForLogicProviderType(AudioAverageValueLogicProvider))
        }
        return nil
    }

    //MARK: -
    //MARK: - Reading
    func readAndDrawSynchronously() {
        self.plotView.startSynchingWithDataSource()
        let date = NSDate()
        self.waveformDataSource?.prepareToRead {
            [weak self] (success) -> () in
            if success {
                self?.waveformDataSource?.read(self!.numberOfPointsOnThePlot) {
                    print("time: \(-date.timeIntervalSinceNow)")
                    self?.plotView.stopSynchingWithDataSource()
                }
            }
        }
    }
    
    //MARK: -
    //MARK: - Private vars
    private var plotView: AudioWaveformPlot!
    private var plotViewModel: AudioWaveformPlotModel! = AudioWaveformPlotModel()
    private var waveformDataSource: AudioSamplesSource!
    
    //MARK: - Public vars
    var asset: AVAsset? {
        didSet{
            dispatch_async(dispatch_get_main_queue()) {
                self.waveformDataSource.asset = self.asset
            }
        }
    }
    
    var numberOfPointsOnThePlot = 512
    //MARK: -
}

//MARK: - AudioWaveformPlotViewModelDelegate
extension DVGWaveformView: AudioWaveformPlotViewModelDelegate {
    func plotMoved(scale: CGFloat, start: CGFloat) {
        self.waveformDataSource!.read(numberOfPointsOnThePlot, dataRange: DataRange(location: Double(start), length: 1.0/Double(scale)))
    }
}
