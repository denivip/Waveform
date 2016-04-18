//
//  ViewController.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController, DVGDiagramMovementsDelegate {

    var phAsset: PHAsset?
    @IBOutlet weak var waveformContainerView: UIView!
    var waveform: DVGWaveformController!

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Waveform Customization
        self.waveform = DVGWaveformController(containerView: self.waveformContainerView)
        
        // Get AVAsset from PHAsset
        if let phAsset = self.phAsset {
            let options = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {_ in return false}
            
            phAsset.requestContentEditingInputWithOptions(options) { contentEditingInput, info in
                dispatch_async(dispatch_get_main_queue()) { 
                    if let asset = contentEditingInput?.avAsset {
                        self.waveform.asset = asset
                        self.configureWaveform()
                    }
                }
            }
        }
    }
    
    func configureWaveform() {
        self.waveform.movementDelegate = self
        let waveform1 = self.waveform.maxValuesWaveform()
        waveform1?.lineColor = UIColor.redColor()
        
        let waveform2 = self.waveform.avgValuesWaveform()
        waveform2?.lineColor = UIColor.greenColor()
        self.waveform.numberOfPointsOnThePlot = 2000
    }
    
    func diagramDidSelect(dataRange: DataRange) {
        
    }
    
    func diagramMoved(scale scale: Double, start: Double) {
    
    }
    
    @IBAction func readAudioAndDrawWaveform() {
        self.waveform.readAndDrawSynchronously({
            if $0 != nil {
                print("error:", $0!)
            } else {
                print("waveform finished drawing")
            }
        })
    }
}
