//
//  DVGAudioWaveformPlot.swift
//  Waveform
//
//  Created by developer on 26/01/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit

class SelectionView: UIView {
    var selectionLayer: CALayer!
    init() {
        super.init(frame: .zero)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    func setup() {
        self.setupSelectionLayer()
    }
    
    func setupSelectionLayer() {
        let layer             = CALayer()
        layer.borderColor     = UIColor.blackColor().CGColor
        layer.borderWidth     = 2.0
        layer.backgroundColor = UIColor.clearColor().CGColor
        self.layer.addSublayer(layer)
        self.selectionLayer   = layer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layoutSelection(self.selection)
    }
    
    var selection: DataRange? {
        didSet{ self.layoutSelection(selection) }
    }
    
    func layoutSelection(dataRange: DataRange?) {
        guard let dataRange = dataRange else {
            self.selectionLayer.borderColor = UIColor.clearColor().CGColor
            return
        }
        self.selectionLayer.borderColor = UIColor.blackColor().CGColor
        
        let startLocation  = self.bounds.width * CGFloat(dataRange.location)
        let selectionWidth = self.bounds.width * CGFloat(dataRange.length)
        
        let frame = CGRect(x: startLocation, y: 0, width: selectionWidth, height: self.bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.selectionLayer.frame = frame
        CATransaction.commit()
    }
}

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
        self.pan.minimumNumberOfTouches = 2 //enabled = false
        
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
        
        self.pinch.delegate = self
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
            print("began", pan.locationInView(self).x)
        case .Ended:
            // notify delegate
            print("ended", pan.locationInView(self).x)
            self.panStartLocation = nil
            break
        case .Changed:
//            print("changed", pan.locationInView(self).x)
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
            print("tap", tap.locationInView(self).x)
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

