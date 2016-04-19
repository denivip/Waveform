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
        
        // Waveform Instatiation
        self.waveform = DVGWaveformController(containerView: self.waveformContainerView)
        
        // Get AVAsset from PHAsset
        if let phAsset = self.phAsset {
            let options = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {_ in return false}
            
            phAsset.requestContentEditingInputWithOptions(options) { contentEditingInput, info in
                print(contentEditingInput, info)
                dispatch_async(dispatch_get_main_queue()) { 
                    if let asset = contentEditingInput?.avAsset {
                        self.waveform.asset = asset
                        self.configureWaveform()
                    } else {
                        print(info[PHContentEditingInputResultIsInCloudKey])
                        if let value = info[PHContentEditingInputResultIsInCloudKey] as? Int where value == 1 {
                            self.showAlert("Load video from iCloud first")
                        } else {
                            self.showAlert("Can't get audio from this video.")
                        }
                    }
                }
            }
        }
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
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
        print("\(#function), dataRange: \(dataRange)")
    }
    
    func diagramMoved(scale scale: Double, start: Double) {
        print("\(#function), scale: \(scale), start: \(start)")
    }
    
    @IBAction func readAudioAndDrawWaveform() {
        self.waveform.readAndDrawSynchronously({[weak self] in
            if $0 != nil {
                print("error:", $0!)
                self?.showAlert("Can't read asset")
            } else {
                print("waveform finished drawing")
            }
        })
    }
}
