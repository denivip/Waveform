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
        let plotView = DVGAudioWaveformPlot()
        plotView.selectionDelegate = self
        
        self.plotView = plotView
        self.plotView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.plotView)
        self.plotView.attachBoundsOfSuperview()
    }
    
    func configure() {
        
        waveformDataSource = AudioSamplesSource()
        waveformDataSource.neededSamplesCount = 2000
        samplesReader.samplesHandler = waveformDataSource

        // Prepare Plot Model with DataSource
        plotViewModel.addChannelSource(waveformDataSource)
        plotViewModel.delegate = self
        
        // Set plot model to plot view
        plotView.viewModel = plotViewModel
    }
    
    //MARK: - For external configuration
    func waveformWithIdentifier(identifier: String) -> AudioWaveformView? {
        return self.plotView.waveformWithIdentifier(identifier)
    }

    func maxValuesWaveform() -> AudioWaveformView? {
        return waveformWithIdentifier(self.waveformDataSource.identifierForLogicProviderType(AudioMaxValueLogicProvider))
    }
    
    func avgValuesWaveform() -> AudioWaveformView? {
        return waveformWithIdentifier(self.waveformDataSource.identifierForLogicProviderType(AudioAverageValueLogicProvider))
    }

    //MARK: -
    //MARK: - Reading
    func readAndDrawSynchronously(completion: (ErrorType?) -> ()) {
//        self.plotView.startSynchingWithDataSource()
        let date = NSDate()
        
        self.samplesReader.readAudioFormat {
            [weak self] (format, error) in
        
            guard let _ = format else {
                completion(error)
                self?.plotView.stopSynchingWithDataSource()
                return
            }
        
            self?.samplesReader.readSamples(completion: { (error) in
                completion(error)
                print("time: \(-date.timeIntervalSinceNow)")
//                self?.plotView.stopSynchingWithDataSource()
            })
        }
    }
    
    func addDataSource(dataSource: ChannelSource) {
        self.plotViewModel.addChannelSource(dataSource)
    }
    
    //MARK: -
    //MARK: - Private vars
    private var plotView: AudioWaveformPlot!
    private var plotViewModel: AudioWaveformPlotModel! = AudioWaveformPlotModel()
    
    private var samplesReader = AudioSamplesReader()
    private var waveformDataSource = AudioSamplesSource()
    
    //MARK: - Public vars
    weak var delegate: DVGWaveformViewDelegate?
    var asset: AVAsset? {
        didSet{
            self.samplesReader.asset = self.asset
        }
    }
    
    var numberOfPointsOnThePlot = 512
    var start: CGFloat = 0.0
    var scale: CGFloat = 1.0
//    var progress: NSProgress {
//        return self.waveformDataSource.progress
//    }
    //MARK: -
}

//MARK: - AudioWaveformPlotViewModelDelegate
extension DVGWaveformView: AudioWaveformPlotViewModelDelegate {
    func plotMoved(scale: CGFloat, start: CGFloat) {
        //TODO: Disable untill draw began
//        self.waveformDataSource!.read(numberOfPointsOnThePlot, dataRange: DataRange(location: Double(start), length: 1.0/Double(scale)))
        self.delegate?.plotMoved(scale, start: start)
        self.start = start
        self.scale = scale
    }
}

extension DVGWaveformView: DVGAudioWaveformPlotDelegate {
    func plotSelectedAreaWithRange(range: DataRange) {
        let range = self.plotViewModel.absoluteRangeFromRelativeRange(range)
        self.delegate?.plotSelectedAreaWithLocation(range.location, length: range.length)
    }
}

protocol DVGWaveformViewDelegate: AudioWaveformPlotViewModelDelegate {
    func plotSelectedAreaWithLocation(location: Double, length: Double)
}
