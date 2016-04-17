//
//  Diagram.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit

class Diagram: UIView {
    
    var containerView: UIView!
    var pan: UIPanGestureRecognizer!
    var pinch: UIPinchGestureRecognizer!
    
    weak var delegate: DiagramDelegate?
    weak var dataSource: DiagramDataSource? {
        didSet{
            self.updateWaveforms()
        }
    }
    
    weak var viewModel: protocol<DiagramDelegate, DiagramDataSource>? {
        didSet {
            self.delegate   = viewModel
            self.dataSource = viewModel
            viewModel?.onPlotUpdate = self.updateWaveforms
        }
    }
    
    func updateWaveforms() {
        if let newDataSource = dataSource {
            for index in 0..<newDataSource.plotDataSourcesCount {
                let plotDataSource = newDataSource.plotDataSourceAtIndex(index)
                
                guard let view = self.plotWithIdentifier(plotDataSource.identifier) else  {
                    self.addPlotWithDataSource(plotDataSource)
                    continue
                }
                view.dataSource = plotDataSource
            }
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
    
    private func setup() {
        self.addContainerView()
        self.addGestures()
    }
    
    func addContainerView() {
        let containerView = UIView()
        self.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.attachBoundsOfSuperview()
        self.containerView = containerView
    }
    
    func addGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(Diagram.handlePan(_:)))
        self.addGestureRecognizer(pan)
        self.pan = pan
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(Diagram.handlePinch(_:)))
        self.addGestureRecognizer(pinch)
        self.pinch = pinch
    }
    
    func handlePan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .Changed:
            let deltaX         = gesture.translationInView(gesture.view).x
            let relativeDeltaX = deltaX/gesture.view!.bounds.width
            self.delegate?.moveByDistance(relativeDeltaX)
            gesture.setTranslation(.zero, inView: gesture.view)
        default:()
        }
    }
    
    func handlePinch(gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .Changed:
            let scale     = gesture.scale
            let locationX = gesture.locationInView(gesture.view).x
            let relativeLocation = locationX/gesture.view!.bounds.width
            self.delegate?.zoomAt(relativeLocation, relativeScale: scale)
            gesture.scale = 1.0
        case .Ended:
            print(self.viewModel!.start, self.viewModel!.scale)
        default:()
        }
    }
    
    var plots = [Plot]()
    var displayLink: CADisplayLink?
}

extension Diagram {
    
    func addPlotWithDataSource(dataSource: PlotDataSource) -> Plot {
        
        let plot = Plot(frame: self.bounds)
        plot.dataSource = dataSource
        
        self.plots.append(plot)
        
        self.containerView.addSubview(plot)
        
        plot.translatesAutoresizingMaskIntoConstraints = false
        plot.attachBoundsOfSuperview()
        
        return plot
    }
    
    func plotWithIdentifier(identifier: String) -> Plot? {
        for plot in self.plots {
            if plot.identifier == identifier {
                return plot
            }
        }
        return nil
    }
    
    func redraw() {
        for plot in self.plots {
            plot.dataSource?.updateGeometry()//redraw()
        }
    }
    
    func startSynchingWithDataSource() {
        if self.displayLink != nil {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
        let displayLink = CADisplayLink.init(target: self, selector: #selector(Diagram.redraw))
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        self.displayLink = displayLink
    }
    
    func stopSynchingWithDataSource() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
}