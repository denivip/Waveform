//
//  ViewController.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    var phAsset: PHAsset?
    
    @IBOutlet weak var waveformView: DVGWaveformView!

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Waveform Customization
        let waveform1 = self.waveformView.maxValuesWaveform()
        waveform1?.lineColor = UIColor.redColor()
        
        let waveform2 = self.waveformView.avgValuesWaveform()
        waveform2?.lineColor = UIColor.greenColor()
        
        // Get AVAsset from PHAsset
        if let phAsset = self.phAsset {
            let options = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {_ in return false}
            
            phAsset.requestContentEditingInputWithOptions(options) { contentEditingInput, info in
                dispatch_async(dispatch_get_main_queue()) { 
                    if let asset = contentEditingInput?.avAsset {
                        self.waveformView.asset = asset
                    }
                }
            }
        }
    }
    
    @IBAction func readAudioAndDrawWaveform() {
        self.waveformView.readAndDrawSynchronously({
            if $0 != nil {
                print("error:", $0!)
            } else {
                print("waveform finished drawing")
            }
        })
    }
}
