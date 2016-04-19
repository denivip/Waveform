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

class DVGWaveformController: NSObject {

    //MARK: - Initialization

    convenience init(containerView: UIView) {
        self.init()
        self.addPlotViewToContainerView(containerView)
    }
    override init() {
        super.init()
    }

    //MARK: -
    //MARK: - Configuration
    //MARK: - Internal configuration
    func addPlotViewToContainerView(containerView: UIView) {
        let diagram = DVGAudioWaveformDiagram()
        self.diagram = diagram
        self.diagram.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(self.diagram)
        self.diagram.attachBoundsOfSuperview()
    }
    
    func configure() {
        waveformDataSource.neededSamplesCount = numberOfPointsOnThePlot
        // Prepare Plot Model with DataSource
        self.addDataSource(waveformDataSource)
        self.diagramViewModel.channelsSource = channelSourceMapper
        
        // Set plot model to plot view
        diagram.delegate = diagramViewModel
        diagram.dataSource = diagramViewModel
        
        diagramViewModel.movementsDelegate = self
    }
    
    //MARK: - For external configuration
    func waveformWithIdentifier(identifier: String) -> Plot? {
        return self.diagram.waveformDiagramView.plotWithIdentifier(identifier)
    }

    func maxValuesWaveform() -> Plot? {
        return waveformWithIdentifier(waveformDataSource.identifier + "." + "AudioMaxValueLogicProvider")
    }
    
    func avgValuesWaveform() -> Plot? {
        return waveformWithIdentifier(waveformDataSource.identifier + "." + "AudioAverageValueLogicProvider")
    }

    //MARK: -
    //MARK: - Reading
    func readAndDrawSynchronously(completion: (ErrorType?) -> ()) {
        
        if self.samplesReader == nil {
            completion(NSError(domain: "",code: -1, userInfo: nil))
            return
        }
        
        self.diagram.waveformDiagramView.startSynchingWithDataSource()
        let date = NSDate()
        
        self.samplesReader.readAudioFormat {
            [weak self] (format, error) in
        
            guard let _ = format else {
                completion(error)
                self?.diagram.waveformDiagramView.stopSynchingWithDataSource()
                return
            }
        
            self?.samplesReader.readSamples(completion: { (error) in
                completion(error)
                print("time: \(-date.timeIntervalSinceNow)")
            })
        }
    }
    
    func addDataSource(dataSource: ChannelSource) {
        channelSourceMapper.addChannelSource(dataSource)
    }
    
    //MARK: -
    //MARK: - Private vars
    private var diagram: DVGAudioWaveformDiagram!
    private var diagramViewModel = DVGAudioWaveformDiagramModel()
    private var samplesReader: AudioSamplesReader!
    private var waveformDataSource = ScalableChannelsContainer()
    private var channelSourceMapper = ChannelSourceMapper()
    
    //MARK: - Public vars
    weak var movementDelegate: DVGDiagramMovementsDelegate?
    var asset: AVAsset? {
        didSet {
            if let asset = asset {
                self.samplesReader = AudioSamplesReader(asset: asset)
                self.configure()
                self.samplesReader.samplesHandler = waveformDataSource
            }
        }
    }
    var numberOfPointsOnThePlot = 512 {
        didSet {
            waveformDataSource.neededSamplesCount = numberOfPointsOnThePlot
        }
    }
    var start: CGFloat = 0.0
    var scale: CGFloat = 1.0
    
    @objc var playbackRelativePosition: NSNumber? {
        get { return self._playbackRelativePosition }
        set { self._playbackRelativePosition = newValue == nil ? nil : CGFloat(newValue!) }
    }
    
    var _playbackRelativePosition: CGFloat? {
        get { return self.diagram.playbackRelativePosition }
        set { self.diagram.playbackRelativePosition = newValue }
    }
    
    var progress: NSProgress {
        return self.samplesReader.progress
    }
}

////MARK: - DiagramViewModelDelegate
extension DVGWaveformController: DVGDiagramMovementsDelegate {
    func diagramDidSelect(dataRange: DataRange) {
        self.movementDelegate?.diagramDidSelect(dataRange)
    }
    func diagramMoved(scale scale: Double, start: Double) {
        self.waveformDataSource.reset(DataRange(location: start, length: 1/scale))
        self.movementDelegate?.diagramMoved(scale: scale, start: start)
    }
}
