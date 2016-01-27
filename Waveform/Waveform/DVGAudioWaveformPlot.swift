//
//  DVGAudioWaveformPlot.swift
//  Waveform
//
//  Created by developer on 26/01/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit

class DVGAudioWaveformPlot: AudioWaveformPlot {
    
    var panToSelect: UIPanGestureRecognizer!
    var tapToSelect: UILongPressGestureRecognizer!
    var selectionView: SelectionView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    func setup(){
        self.setupGestures()
        self.setupSelectionView()
    }
    
    func setupGestures() {
        // New gestures
        let pan                    = UIPanGestureRecognizer(target: self, action: "handlePanToSelect:")
        pan.delegate               = self
        self.addGestureRecognizer(pan)
        self.panToSelect           = pan
        pan.maximumNumberOfTouches = 1
        
        let tap                     = UILongPressGestureRecognizer(target: self, action: "handleTapToSelect:")
        tap.minimumPressDuration    = 0.05
        tap.delegate                = self
        self.addGestureRecognizer(tap)
        self.tapToSelect            = tap
        tap.numberOfTouchesRequired = 1
        
        // Configuring old gestures
        self.pinch.delegate = self
        self.pan.minimumNumberOfTouches = 2
    }
    
    func setupSelectionView() {
        let selectionView = SelectionView()
        self.addSubview(selectionView)
        selectionView.translatesAutoresizingMaskIntoConstraints = false
        selectionView.attachBoundsOfSuperview()
        self.selectionView = selectionView
    }
    
    private var panStartLocation: CGFloat?
    
    func handlePanToSelect(pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .Began:
            if self.panStartLocation == nil {
                self.panStartLocation = pan.locationInView(self).x
            }
        case .Ended:
            // notify delegate
            self.panStartLocation = nil
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
            self.panStartLocation = tap.locationInView(self).x
            self.configureSelectionFromPosition(tap.locationInView(self).x)
        default:()
        }
    }
    
    override func handlePinch(gesture: UIPinchGestureRecognizer) {
        super.handlePinch(gesture)
        self.selectionView.selection = nil
    }
    
    override func handlePan(gesture: UIPanGestureRecognizer) {
        super.handlePan(gesture)
        self.selectionView.selection = nil
    }
    
    var minSelectionWidth: CGFloat = 10.0
    
    func configureSelectionFromPosition(_startPosition: CGFloat) {
        self.configureSelectionFromPosition(_startPosition, toPosition: _startPosition)
    }
    
    func configureSelectionFromPosition(_startPosition: CGFloat, toPosition _endPosition: CGFloat) {

        //TODO: move geometry logic to viewModel (create it first)
        var startPosition = min(_endPosition, _startPosition)
        var endPosition   = max(_endPosition, _startPosition)
        
        startPosition = max(0, min(startPosition, self.bounds.width - minSelectionWidth))
        endPosition   = max(minSelectionWidth, min(endPosition, self.bounds.width))
        
        let width = max(endPosition - startPosition, minSelectionWidth)
        
        let range = DataRange(
            location: startPosition / self.bounds.width,
            length:   width / self.bounds.width)

        self.selectionView.selection = range
    }
    
}

extension DVGAudioWaveformPlot: UIGestureRecognizerDelegate {
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
        print(gestureRecognizer.dynamicType, gestureRecognizer.numberOfTouches(), pinch.state.rawValue)
        return true
    }
}

