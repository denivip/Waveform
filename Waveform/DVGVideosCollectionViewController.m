//
//  DenoiseVideosViewControllerCollectionViewController.m
//  Denoise
//
//  Created by Denis Bulichenko on 11/11/14.
//  Copyright (c) 2014 DENIVIP Group. All rights reserved.
//

#import "DVGVideosCollectionViewController.h"
#import "DenoiseCollectionViewCell.h"
//#import "AudioWaveformView.h"
//#import "PhotoEditingViewController.h"
#import "DVGCollectionReusableView.h"
//#import "DVGLaunchViewController.h"
//#import "DVGLaunchTransitionController.h"
#import "DVGDenivipAppearance.h"
#import "Waveform-Swift.h"

#define PREVIEW_WIDTH 150
#define PREVIEW_HEIGHT PREVIEW_WIDTH*(3.0/4.0)

@import Photos;
@import CoreMedia;
@import Accelerate;

@implementation NSIndexSet (DVGExtensions)
- (NSArray *)dvg_indexPathsFromIndexesWithSection:(NSInteger)section {
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [indexPaths addObject:[NSIndexPath indexPathForItem:(NSInteger)idx inSection:section]];
    }];
    return indexPaths;
}
@end

static NSString *const reuseIdentifier = @"Cell";

@interface DVGVideosCollectionViewController () <PHPhotoLibraryChangeObserver, UIViewControllerTransitioningDelegate>

@property (nonatomic, strong) NSArray *assetsFetchResults;
@property (nonatomic, strong) NSArray *moments;
@property (nonatomic, assign) BOOL needShowLaunchScreen;

@property (nonatomic, weak) UIImageView *navBarHairlineImageView;

@end

@implementation DVGVideosCollectionViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        self.titleScreen = @"Videos";
        self.needShowLaunchScreen = YES;
    }
    return self;
}

- (void)dealloc
{
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

#pragma mark - UIViewController

- (BOOL)shouldAutorotate {
    return NO;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@" " style:UIBarButtonItemStylePlain target:nil action:nil];
    

    self.navBarHairlineImageView = [self findHairlineImageViewUnder:self.navigationController.view];
    //[self.assetsFetchResults count];
}

- (UIImageView *)findHairlineImageViewUnder:(UIView *)view {
    if ([view isKindOfClass:UIImageView.class] && view.bounds.size.height <= 1.0) {
        return (UIImageView *)view;
    }
    for (UIView *subview in view.subviews) {
        UIImageView *imageView = [self findHairlineImageViewUnder:subview];
        if (imageView) {
            return imageView;
        }
    }
    return nil;
}

+ (void)clearTmpDirectory
{
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
    }
}

-(void)viewDidAppear:(BOOL)animated {
    
    [DVGVideosCollectionViewController clearTmpDirectory];
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    [self assetsFetchResults];
    [self.assetsFetchResults count];
    [self.collectionView reloadData];
}



-(void)viewDidDisappear:(BOOL)animated {
    NSLog(@"viewDidDisappear");
    [super viewDidDisappear:animated];
    self.transitioningDelegate = nil;
}

-(NSArray *)assetsFetchResults{
    if (_assetsFetchResults == nil) {
        NSLog(@"assetsFetchResults is nil");
        PHFetchOptions *userAlbumsOptions = [PHFetchOptions new];
        userAlbumsOptions.predicate = [NSPredicate predicateWithFormat:@"estimatedAssetCount > 0"];
        userAlbumsOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:NO]];
        PHFetchResult *userAlbums = [PHAssetCollection fetchMomentsWithOptions:userAlbumsOptions];
        NSMutableArray *assets = @[].mutableCopy;
        NSMutableArray *moments = @[].mutableCopy;
        
        PHFetchOptions *fetchOptions = [PHFetchOptions new];
        fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
        [userAlbums enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
            PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
            if ([assetsFetchResult count] > 0) {
                [assets addObject:assetsFetchResult];
                [moments addObject:collection];
            }
        }];
        _moments = moments;
        _assetsFetchResults = assets;
    }
    return _assetsFetchResults;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    ViewController            *vc   = [segue destinationViewController];
    DenoiseCollectionViewCell *cell = sender;
    vc.phAsset = cell.videoSource;
//    PhotoEditingViewController *controller = (id)[segue destinationViewController];
  
//    [controller startContentEditingWithAsset:cell.videoSource preview:cell.videoThumbnail];
//    _selectedSnapshotView = cell.imageView;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    NSLog(@"photoLibraryDidChange");
    dispatch_async(dispatch_get_main_queue(), ^{
        self.assetsFetchResults = nil;
        [self.assetsFetchResults count];
        [self.collectionView reloadData];
    });
}

#pragma mark - UICollectionViewDataSource

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    if (_assetsFetchResults == nil) {
        return 0;
    } else {
        return [self.assetsFetchResults count];
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (_assetsFetchResults == nil) {
        return 0;
    } else {
        PHFetchResult *assetsFetchResult = self.assetsFetchResults[section];
        return [assetsFetchResult count];
    }
}

#pragma mark – UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger count = floor(CGRectGetWidth(self.view.bounds)/PREVIEW_WIDTH);
    CGFloat width = CGRectGetWidth(self.view.bounds)/count;
    return CGSizeMake(width, PREVIEW_HEIGHT);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    if (collectionView == self.collectionView) {
        return UIEdgeInsetsZero;
    }
    
    return UIEdgeInsetsZero;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    DenoiseCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    PHFetchResult *assetsFetchResult = self.assetsFetchResults[indexPath.section];
    
    PHAsset *asset = assetsFetchResult[indexPath.row];
    cell.videoSource = asset;
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionReusableView *reusableview = nil;
    
    if (kind == UICollectionElementKindSectionHeader) {
        DVGCollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"DVGCollectionReusableView" forIndexPath:indexPath];
        [self configureHeader:headerView forMoment:self.moments[indexPath.section]];
        reusableview = headerView;
    }
    
    if (kind == UICollectionElementKindSectionFooter) {
        UICollectionReusableView *footerview = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"FooterView" forIndexPath:indexPath];
        
        reusableview = footerview;
    }
    
    return reusableview;
}

-(void)configureHeader:(DVGCollectionReusableView *)header forMoment:(PHAssetCollection *)collection{
    if (collection.localizedTitle) {
        header.titleLabel.text = collection.localizedTitle;
    }
    
    if ([collection.localizedLocationNames count] > 0) {
        if (header.titleLabel.text) {
            header.subtitleLabel.text = [collection.localizedLocationNames firstObject];
        }
        else{
            header.titleLabel.text = [collection.localizedLocationNames firstObject];
        }
    }
    
    NSString *date = [NSDateFormatter localizedStringFromDate:[collection startDate]
                                                    dateStyle:NSDateFormatterLongStyle
                                                    timeStyle:NSDateFormatterNoStyle].mutableCopy;
    if(header.titleLabel.text){
        header.dateLabel.text = date;
    }
    else{
        header.titleLabel.text = date;
    }
    [header layoutIfNeeded];
}

#pragma mark - View Controller transitioning delegate

//- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
//    DVGLaunchTransitionController *transition = [[DVGLaunchTransitionController alloc] init];
//    return transition;
//}
//
//- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
//    DVGLaunchTransitionController *transition = [[DVGLaunchTransitionController alloc] init];
//    transition.reversed = YES;
//    return transition;
//}


@end
