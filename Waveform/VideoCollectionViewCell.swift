//
//  VideoCollectionViewCell.swift
//  Waveform
//
//  Created by qqqqq on 18/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit
import Photos

class VideoCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var timeLabelContainer: UIView!
    
    var imageManager = PHCachingImageManager()
    var videoSource: PHAsset? {
        didSet {
            guard let videoSource = videoSource else {
                return
            }
            self.timeLabel.text = self.stringWithTime(videoSource.duration)
            self.timeLabelContainer.layer.cornerRadius = self.timeLabelContainer.bounds.size.height/2;
            
        
            imageManager.requestImageForAsset(videoSource, targetSize:self.bounds.size, contentMode:.AspectFill, options:nil, resultHandler: {result, _ in
                    self.imageView.image = result;
            })
        }
    }
    
    func stringWithTime(time:NSTimeInterval) -> String {
        var seconds = time;
        var minutes = seconds/60;
        seconds = seconds%60;
        let hours = minutes/60;
        minutes = minutes%60;
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", Int(hours), Int(minutes), Int(seconds));
        } else if minutes > 0 {
            return String(format:"%d:%02d", Int(minutes), Int(seconds));
        } else {
            return String(format:"0:%02d", Int(seconds));
        }
    }
}
