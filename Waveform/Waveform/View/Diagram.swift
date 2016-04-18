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
    
    weak var delegate: DiagramDelegate?
    weak var dataSource: DiagramDataSource? {
        didSet{
            self.resetWaveforms()
            dataSource?.onPlotUpdate = { [weak self] in self?.resetWaveforms() }
        }
    }
    
    func resetWaveforms() {
        
        guard let dataSource = self.dataSource else {
            self.plots.forEach{ $0.removeFromSuperview() }
            self.plots.removeAll()
            return
        }
        
        adjustPlotsNumberWithCount(dataSource.plotDataSourcesCount)
        
        for index in 0..<dataSource.plotDataSourcesCount {
            let plot = plots[index]
            let vm = dataSource.plotDataSourceAtIndex(index)
            plot.dataSource = vm
        }
        redraw()
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
    }
    
    func addContainerView() {
        let containerView = UIView()
        self.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.attachBoundsOfSuperview()
        self.containerView = containerView
    }

    func adjustPlotsNumberWithCount(count: Int) {
        if plots.count == count {
            return
        }
        if plots.count < count {
            for _ in plots.count..<count {
                let plot = Plot(frame: self.bounds)
                self.containerView.addSubview(plot)
                plot.translatesAutoresizingMaskIntoConstraints = false
                plot.attachBoundsOfSuperview()
                plots.append(plot)
            }
            return
        }
        for index in count..<plots.count {
            let plot = plots[index]
            plot.removeFromSuperview()
            plots.removeAtIndex(index)
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
            if let dataSource = plot.dataSource where dataSource.needsRedraw {
                plot.redraw()
                dataSource.needsRedraw = false
            }
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