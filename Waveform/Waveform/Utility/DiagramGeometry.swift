//
//  Geometry.swift
//  Waveform
//
//  Created by qqqqq on 17/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

struct DiagramGeometry {
    var start = 0.0
    var scale = 1.0
}

extension Double {
    func convertToGeometry(geometry: DiagramGeometry) -> Double {
        return (self - geometry.start) * geometry.scale
    }
    func convertFromGeometry(geometry: DiagramGeometry) -> Double {
        return self/geometry.scale + geometry.start
    }
}

extension CGFloat {
    func convertToGeometry(geometry: DiagramGeometry) -> CGFloat {
        return CGFloat((Double(self) - geometry.start) * geometry.scale)
    }
    func convertFromGeometry(geometry: DiagramGeometry) -> CGFloat {
        return CGFloat(Double(self)/geometry.scale + geometry.start)
    }
}