//
//  DVGDiagram.swift
//  Waveform
//
//  Created by developer on 26/01/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit

class DVGAudioWaveformDiagram: UIView {
    
    var panToSelect: UIPanGestureRecognizer!
    var tapToSelect: UILongPressGestureRecognizer!
    var pan: UIPanGestureRecognizer!
    var pinch: UIPinchGestureRecognizer!
    
    var selectionView: SelectionView!
    var playbackPositionView: PlaybackPositionView!
    var waveformDiagramView: Diagram!
    
    weak var delegate: DVGDiagramDelegate? {
        didSet {
            waveformDiagramView.delegate = delegate
        }
    }
    weak var dataSource: DiagramDataSource? {
        didSet {
            waveformDiagramView.dataSource = dataSource
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    func setup(){
        self.setupAudioWaveformView()
        self.setupGestures()
        self.setupSelectionView()
        self.setupPlaybackPositionView()
    }
    
    func setupAudioWaveformView() {
        let waveformDiagramView = Diagram()
        addSubview(waveformDiagramView)
        waveformDiagramView.translatesAutoresizingMaskIntoConstraints = false
        waveformDiagramView.attachBoundsOfSuperview()
        self.waveformDiagramView = waveformDiagramView
    }
    
    func setupGestures() {
        // New gestures
        let panToSelect                    = UIPanGestureRecognizer(target: self, action: #selector(DVGAudioWaveformDiagram.handlePanToSelect(_:)))
        panToSelect.delegate               = self
        self.addGestureRecognizer(panToSelect)
        self.panToSelect                   = panToSelect
        panToSelect.maximumNumberOfTouches = 1
        
        let tap                     = UILongPressGestureRecognizer(target: self, action: #selector(DVGAudioWaveformDiagram.handleTapToSelect(_:)))
        tap.delegate                = self
        tap.minimumPressDuration    = 0.08
        self.addGestureRecognizer(tap)
        self.tapToSelect            = tap
        tap.numberOfTouchesRequired = 1

        let pinch                   = UIPinchGestureRecognizer(target: self, action: #selector(DVGAudioWaveformDiagram.handlePinch(_:)))
        pinch.delegate              = self
        self.addGestureRecognizer(pinch)
        self.pinch                  = pinch
        
        let pan                         = UIPanGestureRecognizer(target: self, action: #selector(DVGAudioWaveformDiagram.handlePan(_:)))
        self.addGestureRecognizer(pan)
        self.pan                        = pan
        self.pan.minimumNumberOfTouches = 2
    }
    
    func setupSelectionView() {
        let selectionView = SelectionView()
        self.addSubview(selectionView)
        selectionView.translatesAutoresizingMaskIntoConstraints = false
        selectionView.attachBoundsOfSuperview()
        self.selectionView = selectionView
    }
    
    func setupPlaybackPositionView() {
        let playbackPositionView = PlaybackPositionView()
        self.addSubview(playbackPositionView)
        playbackPositionView.translatesAutoresizingMaskIntoConstraints = false
        playbackPositionView.attachBoundsOfSuperview()
        self.playbackPositionView = playbackPositionView
    }
    
    private var panStartLocation: CGFloat?
    
    func handlePanToSelect(pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .Began:
            if self.panStartLocation == nil {
                self.panStartLocation = pan.locationInView(self).x
            }
            self.configureSelectionFromPosition(panStartLocation!, toPosition: pan.locationInView(self).x)
        case .Failed:
            print("pan failed")
        case .Ended:
            // notify delegate
            self.panStartLocation = nil
            if let selection = self.selection {
                self.delegate?.diagramDidSelect(selection)
            }
            break
        case .Changed:
            self.configureSelectionFromPosition(panStartLocation!, toPosition: pan.locationInView(self).x)
        default:
            break
        }
    }
    
    func handleTapToSelect(tap: UILongPressGestureRecognizer) {
        
        switch self.pinch.state {
        case .Began, .Changed:
            return
        default:
            break
        }
        
        switch tap.state {
        case .Began:
            self.panStartLocation = pan.locationInView(self).x
            self.configureSelectionFromPosition(tap.locationInView(self).x)
        case .Failed:
            print("tap failed")
        case .Ended:
            self.configureSelectionFromPosition(tap.locationInView(self).x)
            if let selection = self.selection {
                self.delegate?.diagramDidSelect(selection)
            }
        default:()
        }
    }
    
    func handlePinch(gesture: UIPinchGestureRecognizer) {
        self.selectionView.selection = nil
        
        let k = self.playbackRelativePosition
        self.playbackRelativePosition = k
        
        let l = self.selection
        self.selection = l
        
        switch gesture.state {
        case .Changed:
            let scale     = gesture.scale
            let locationX = gesture.locationInView(gesture.view).x
            let relativeLocation = locationX/gesture.view!.bounds.width
            self.delegate?.zoomAt(relativeLocation, relativeScale: scale)
            gesture.scale = 1.0
        case .Ended:
            print(self.dataSource?.geometry )
        default:()
        }
    }
    
    func handlePan(gesture: UIPanGestureRecognizer) {
        self.selectionView.selection = nil
        switch gesture.state {
        case .Changed:
            let deltaX         = gesture.translationInView(gesture.view).x
            let relativeDeltaX = deltaX/gesture.view!.bounds.width
            self.delegate?.moveByDistance(relativeDeltaX)
            gesture.setTranslation(.zero, inView: gesture.view)
        default:()
        }
        
        let k = self.playbackRelativePosition
        self.playbackRelativePosition = k
        
        let l = self.selection
        self.selection = l
    }
    
    var minSelectionWidth: CGFloat = 40.0
    var playbackRelativePosition: CGFloat? = nil {
        didSet {
            if let playbackRelativePosition = playbackRelativePosition,
                let viewModel = self.dataSource {
                self.playbackPositionView.position = playbackRelativePosition.convertToGeometry(viewModel.geometry)
            } else {
                self.playbackPositionView.position = nil
            }
        }
    }
    var selection: DataRange? = nil {
        didSet {
            if let relativeSelection = selection,
                let viewModel = self.dataSource {
                self.selectionView.selection = relativeSelection.convertToGeometry(viewModel.geometry)
            } else {
                self.selectionView.selection = nil
            }
        }
    }
    func configureSelectionFromPosition(_startPosition: CGFloat) {
        self.configureSelectionFromPosition(_startPosition, toPosition: _startPosition)
    }
    
    func configureSelectionFromPosition(_startPosition: CGFloat, toPosition _endPosition: CGFloat) {

        //TODO: move geometry logic to viewModel (create it first)
        var startPosition = min(_endPosition, _startPosition)
        var endPosition   = max(_endPosition, _startPosition)
        
        startPosition = startPosition - minSelectionWidth/2
        endPosition   = endPosition + minSelectionWidth/2
        
        startPosition = max(0, startPosition)
        endPosition   = min(endPosition, self.bounds.width)
        
        let width = max(endPosition - startPosition, minSelectionWidth)
        
        let range = DataRange(
            location: startPosition / self.bounds.width,
            length:   width / self.bounds.width)

        self.selection = range.convertFromGeometry(self.dataSource!.geometry)
    }
    
}

extension DVGAudioWaveformDiagram: UIGestureRecognizerDelegate {
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        switch (gestureRecognizer, otherGestureRecognizer) {
        case (panToSelect, tapToSelect):
            fallthrough
        case (tapToSelect, panToSelect):
            return true
        default:
            return false
        }
    }
    
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.panToSelect {
            self.tapToSelect.enabled = false
            self.tapToSelect.enabled = true
        }
        return true
    }
}
