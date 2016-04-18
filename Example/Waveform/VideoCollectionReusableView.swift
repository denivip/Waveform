//
//  VideoCollectionReusableView.swift
//  Waveform
//
//  Created by qqqqq on 18/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit
import Photos

class VideoCollectionReusableView: UICollectionReusableView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.titleLabel.adjustsFontSizeToFitWidth    = true
        self.subtitleLabel.adjustsFontSizeToFitWidth = true
        self.dateLabel.adjustsFontSizeToFitWidth     = true
        
        self.titleLabel.text    = nil;
        self.subtitleLabel.text = nil;
        self.dateLabel.text     = nil;
    }
    
    override func prepareForReuse() {
        super.prepareForReuse();
    
        self.titleLabel.text    = nil;
        self.subtitleLabel.text = nil;
        self.dateLabel.text     = nil;
    }
    
    func configureWithCollection(collection: PHAssetCollection) {
        
        if collection.localizedTitle != nil {
            self.titleLabel.text = collection.localizedTitle
        }
        
        if collection.localizedLocationNames.count > 0 {
            if self.titleLabel.text != nil {
                self.subtitleLabel.text = collection.localizedLocationNames.first
            } else {
                self.titleLabel.text = collection.localizedLocationNames.first
            }
        }
        
        let date = NSDateFormatter.localizedStringFromDate(collection.startDate!, dateStyle:.LongStyle, timeStyle:.NoStyle)
        
        if self.titleLabel.text != nil {
            self.dateLabel.text = date
        } else {
            self.titleLabel.text = date;
        }
        
        self.layoutIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    
        self.titleLabel.sizeToFit()
        self.subtitleLabel.sizeToFit()
        self.dateLabel.sizeToFit()
    
        let titleLabelTopOffsetWithNoSubtitle: CGFloat = 10;
        
        let titleLabelTopOffset: CGFloat       = 20;
        let subtitleLabelBottomOffset: CGFloat = 10;
        let horizontalBordersOffset: CGFloat   = 15;
        let dateLabelWidth: CGFloat            = 100 - horizontalBordersOffset;
    
        if (self.subtitleLabel.text?.characters.count == 0) {
    
            self.titleLabel.frame = CGRectMake(horizontalBordersOffset,
                                               titleLabelTopOffsetWithNoSubtitle,
                                               CGRectGetWidth(self.bounds) - dateLabelWidth,
                                               CGRectGetHeight(self.bounds) - titleLabelTopOffsetWithNoSubtitle)
            
            self.dateLabel.frame  = CGRectMake(CGRectGetWidth(self.bounds) - dateLabelWidth - horizontalBordersOffset,
                                               0 + titleLabelTopOffsetWithNoSubtitle,
                                               dateLabelWidth,
                                               CGRectGetHeight(self.bounds) - titleLabelTopOffsetWithNoSubtitle)
        } else {
            self.titleLabel.frame    = CGRectMake(horizontalBordersOffset,
                                                  titleLabelTopOffset,
                                                  CGRectGetWidth(self.bounds) - dateLabelWidth - 2 * horizontalBordersOffset,
                                                  CGRectGetHeight(self.titleLabel.bounds))
            
            self.subtitleLabel.frame = CGRectMake(horizontalBordersOffset,
                                                  CGRectGetHeight(self.bounds) - subtitleLabelBottomOffset - CGRectGetHeight(self.subtitleLabel.bounds),
                                                  CGRectGetWidth(self.bounds) - dateLabelWidth - 2 * horizontalBordersOffset,
                                                  CGRectGetHeight(self.subtitleLabel.bounds))
            
            self.dateLabel.frame     = CGRectMake(CGRectGetWidth(self.bounds) - dateLabelWidth - horizontalBordersOffset,
                                                  titleLabelTopOffset,
                                                  dateLabelWidth,
                                                  CGRectGetHeight(self.dateLabel.bounds) )
        }
    }
}
