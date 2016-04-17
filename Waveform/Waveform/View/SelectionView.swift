//
//  SelectionView.swift
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
        self.clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
        self.clipsToBounds = true
    }
    
    func setup() {
        self.setupSelectionLayer()
        self.backgroundColor = .clearColor()
    }
    
    func setupSelectionLayer() {
        let layer             = CALayer()
        layer.borderColor     = UIColor.grayColor().CGColor
        layer.cornerRadius    = 5.0
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
        self.selectionLayer.borderColor = UIColor.grayColor().CGColor
        
        let startLocation  = self.bounds.width * CGFloat(dataRange.location)
        let selectionWidth = self.bounds.width * CGFloat(dataRange.length)
        
        let frame = CGRect(x: startLocation, y: 0, width: selectionWidth, height: self.bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.selectionLayer.frame = frame
        CATransaction.commit()
    }
}
