//
//  ViewController.swift
//  Video Editing Template
//
//  Created by developer on 03/02/16.
//  Copyright © 2016 developer. All rights reserved.
//

import UIKit
import Photos

@objc
class VideoCollectionViewController: UICollectionViewController {

    var assetsFetchResults: [PHFetchResult] = []
    var moments: [PHAssetCollection]        = []

    var userAlbumsFetchPredicate       = NSPredicate(format: "estimatedAssetCount > 0")
    var userAlbumsFetchSortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
    var inAlbumItemsFetchPredicate     = NSPredicate(format: "mediaType == %d", PHAssetMediaType.Video.rawValue)
    
    var selectedSnapshotView: UIView?
    
    private struct Constants {
        static let collectionViewCellReuseId = "video_collection_view_cell"
        static let collectionHeaderReuseId   = "video_collection_view_header"
        static let collectionFooterReuseId   = "FooterView"

        static func collectionSupplementaryElementReuseIdForKind(kind: String) -> String {
            switch kind {
            case UICollectionElementKindSectionHeader:
                return self.collectionHeaderReuseId
            case UICollectionElementKindSectionFooter:
                return self.collectionFooterReuseId
            default:
                fatalError()
            }
        }

        static let preview_width: CGFloat    = 150.0
        static let preview_height: CGFloat   = preview_width * 3/4
    }
    
    // MARK: - Constuctor/Destructor
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    deinit{
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    // MARK: - View Controller Lifetime
    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide nav bar bottom line
        let navBarHairlineImageView: UIImageView? = navigationController?.barHairlineImageView()
        navBarHairlineImageView?.hidden           = true;
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        clearApplicationTmpDirectory()

        if self.assetsFetchResults.count == 0 {
            updateAssetsFetchResultsAndMoments()
            collectionView?.reloadData()
        }
    }
}


// MARK: - UICollectionViewDataSource
extension VideoCollectionViewController {
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return assetsFetchResults.count
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assetsFetchResults[section].count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(Constants.collectionViewCellReuseId, forIndexPath:indexPath)
        
        if let cell = cell as? VideoCollectionViewCell,
            let asset = self.assetsFetchResults[indexPath.section][indexPath.row] as? PHAsset {
                cell.videoSource = asset
        } else {
            fatalError()
        }
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {

        let reuseId = Constants.collectionSupplementaryElementReuseIdForKind(kind)
        let reusableView = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: reuseId, forIndexPath: indexPath)

        switch (kind, reusableView) {
        case (UICollectionElementKindSectionHeader, let headerView as VideoCollectionReusableView):
            headerView.configureWithCollection(self.moments[indexPath.section])
        case (UICollectionElementKindSectionFooter, _): ()
        default:
            fatalError()
        }
        
        return reusableView
    }
}


// MARK: - UICollectionViewDelegateFlowLayout
extension VideoCollectionViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        let count = floor(self.view.bounds.width/Constants.preview_width);
        let width = CGRectGetWidth(self.view.bounds)/count;
        return CGSizeMake(width, Constants.preview_height);
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsZero
    }
}

// MARK: - Navigation/Transition
extension VideoCollectionViewController {
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let controller     = segue.destinationViewController as! ViewController
        let cell           = sender as! VideoCollectionViewCell
        controller.phAsset = cell.videoSource
    }
}


// MARK: - Content Update
extension VideoCollectionViewController {

    func updateAssetsFetchResultsAndMoments() {
        var assets  = [PHFetchResult]()
        var moments = [PHAssetCollection]()
        
        let userAlbumsFetchOptions             = PHFetchOptions()
        userAlbumsFetchOptions.predicate       = userAlbumsFetchPredicate
        userAlbumsFetchOptions.sortDescriptors = userAlbumsFetchSortDescriptors
        
        let userAlbumsFetchResult = PHAssetCollection.fetchMomentsWithOptions(userAlbumsFetchOptions)
        
        let inAlbumItemsFetchOptions       = PHFetchOptions()
        inAlbumItemsFetchOptions.predicate = inAlbumItemsFetchPredicate
        
        userAlbumsFetchResult.enumerateObjectsUsingBlock { (collection, _, _) -> Void in
            guard let collection = collection as? PHAssetCollection else {
                return
            }
            
            let assetsFetchResult = PHAsset.fetchAssetsInAssetCollection(collection, options: inAlbumItemsFetchOptions)
            
            if assetsFetchResult.count > 0 {
                assets.append(assetsFetchResult)
                moments.append(collection)
            }
        }
        
        self.moments            = moments
        self.assetsFetchResults = assets
    }
}


// MARK: - View Controller Auto Rotation
extension VideoCollectionViewController {
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }
}


// MARK: - PHPhotoLibraryChangeObserver
extension VideoCollectionViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(changeInstance: PHChange) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.updateAssetsFetchResultsAndMoments()
            self.collectionView?.reloadData()
        }
    }
}


// MARK:  -
// MARK:  - UINavigationController ex
extension UINavigationController {
    func barHairlineImageView() -> UIImageView? {
        return view.findSubview { $0.bounds.height <= 1.0 }
    }
}


// MARK: - UIView ex
extension UIView {
    func findSubview<T: UIView>(predicate: (T) -> (Bool)) -> T? {
        
        if let self_ = self as? T where predicate(self_) {
            return self_
        }
        
        for subview in subviews {
            if let targetView = subview.findSubview(predicate) {
                return targetView
            }
        }
        return nil
    }
}

// MARK: - Utility
func clearApplicationTmpDirectory() {
    do {
        let tmpDirectoryContent = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(NSTemporaryDirectory())
        for file in tmpDirectoryContent {
            let filePath = NSTemporaryDirectory() + file
            try NSFileManager.defaultManager().removeItemAtPath(filePath)
        }
    } catch (let error) {
        print("\(#function), catched error:\(error)")
    }
}


