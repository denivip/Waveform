//
//  UIKit+extensions.swift
//  Waveform
//
//  Created by developer on 22/01/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit

extension UIView {
    func attachBoundsOfSuperview(){
        assert(self.superview != nil, "There are no superview")
        let views = ["view": self]
        let horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("|[view]|", options: [], metrics: nil, views: views)
        self.superview!.addConstraints(horizontalConstraints)
        let verticalConstraints   = NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options: [], metrics: nil, views: views)
        self.superview!.addConstraints(verticalConstraints)
    }
}