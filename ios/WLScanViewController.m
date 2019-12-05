//
//  WLScanViewController.m
//  Siemens Home
//
//  Created by Vitta on 2019/11/9.
//

#import "WLScanViewController.h"
#import "LBXScanTypes.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>


@interface WLScanViewController ()

@end

@implementation WLScanViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {

        self.edgesForExtendedLayout = UIRectEdgeNone;
    }

    self.view.backgroundColor = [UIColor blackColor];

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self drawScanView];

    [self requestCameraPemissionWithResult:^(BOOL granted) {

        if (granted) {

            //不延时，可能会导致界面黑屏并卡住一会
            [self performSelector:@selector(startScan) withObject:nil afterDelay:0.3];

        }
    }];

}

//绘制扫描区域
- (void)drawScanView {

}

- (void)reStartDevice {
    [_scanObj startScan];

}


- (CGRect)getPortraitModeScanCropRect:(CGRect)overlayCropRect
                       forOverlayView:(UIView *)readerView {
    CGRect scanCropRect = CGRectMake(0, 0, 1, 1); /*default full screen*/

    float x = (float) overlayCropRect.origin.x;
    float y = (float) overlayCropRect.origin.y;
    float width = (float) overlayCropRect.size.width;
    float height = (float) overlayCropRect.size.height;

    float A = (float) (y / readerView.bounds.size.height);
    float B = (float) (1 - (x + width) / readerView.bounds.size.width);
    float C = (float) ((y + height) / readerView.bounds.size.height);
    float D = (float) (1 - x / readerView.bounds.size.width);

    scanCropRect = CGRectMake(A, B, C, D);

    return scanCropRect;
}

//启动设备
- (void)startScan {
    UIView *videoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame))];
    videoView.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:videoView atIndex:0];

    if (!_scanObj) {
        NSString *strCode = AVMetadataObjectTypeQRCode;
        if (_scanCodeType != SCT_BarCodeITF) {

            strCode = [self nativeCodeWithType:_scanCodeType];
        }

        __weak __typeof(self) weakSelf = self;
        self.scanObj = [[LBXScanNative alloc] initWithPreView:videoView ObjectType:@[strCode] cropRect:self.cropRect success:^(NSArray<LBXScanResult *> *array) {

            [weakSelf scanResultWithArray:array];
        }];
    }
    [_scanObj startScan];

    self.view.backgroundColor = [UIColor clearColor];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    [self stopScan];

}

- (void)stopScan {
    [_scanObj stopScan];
}

#pragma mark -扫码结果处理

- (void)scanResultWithArray:(NSArray<LBXScanResult *> *)array {
    //设置了委托的处理
    if (_delegate) {
        [_delegate scanResultWithArray:array];
    }

    //也可以通过继承LBXScanViewController，重写本方法即可
}


//开关闪光灯
- (void)openOrCloseFlash {

    switch (_libraryType) {
        case SLT_Native: {
#ifdef LBXScan_Define_Native
            [_scanObj changeTorch];
#endif
        }
            break;
        case SLT_ZXing: {
#ifdef LBXScan_Define_ZXing
            [_zxingObj openOrCloseTorch];
#endif
        }
            break;
        case SLT_ZBar: {
#ifdef LBXScan_Define_ZBar
            [_zbarObj openOrCloseFlash];
#endif
        }
            break;
        default:
            break;
    }
    self.isOpenFlash = !self.isOpenFlash;
}


#pragma mark --打开相册并识别图片

/*!
 *  打开本地照片，选择图片识别
 */
- (void)openLocalPhoto:(BOOL)allowsEditing {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];

    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

    picker.delegate = self;

    //部分机型有问题
    picker.allowsEditing = allowsEditing;


    [self presentViewController:picker animated:YES completion:nil];
}



//当选择一张图片后进入这里

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    __block UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];

    if (!image) {
        image = [info objectForKey:UIImagePickerControllerOriginalImage];
    }

    __weak __typeof(self) weakSelf = self;

    switch (_libraryType) {
        case SLT_Native: {
#ifdef LBXScan_Define_Native
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
                [LBXScanNative recognizeImage:image success:^(NSArray<LBXScanResult *> *array) {
                    [weakSelf scanResultWithArray:array];
                }];
            } else {
                [self showError:@"native低于ios8.0系统不支持识别图片条码"];
            }
#endif
        }
            break;
        case SLT_ZXing: {
#ifdef LBXScan_Define_ZXing

            [ZXingWrapper recognizeImage:image block:^(ZXBarcodeFormat barcodeFormat, NSString *str) {

                LBXScanResult *result = [[LBXScanResult alloc]init];
                result.strScanned = str;
                result.imgScanned = image;
                result.strBarCodeType = [self convertZXBarcodeFormat:barcodeFormat];

                [weakSelf scanResultWithArray:@[result]];
            }];
#endif

        }
            break;
        case SLT_ZBar: {
#ifdef LBXScan_Define_ZBar
            [LBXZBarWrapper recognizeImage:image block:^(NSArray<LBXZbarResult *> *result) {

                //测试，只使用扫码结果第一项
                LBXZbarResult *firstObj = result[0];

                LBXScanResult *scanResult = [[LBXScanResult alloc]init];
                scanResult.strScanned = firstObj.strScanned;
                scanResult.imgScanned = firstObj.imgScanned;
                scanResult.strBarCodeType = [LBXZBarWrapper convertFormat2String:firstObj.format];

                [weakSelf scanResultWithArray:@[scanResult]];

            }];
#endif

        }
            break;

        default:
            break;
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    NSLog(@"cancel");

    [picker dismissViewControllerAnimated:YES completion:nil];
}


#ifdef LBXScan_Define_ZXing
- (NSString*)convertZXBarcodeFormat:(ZXBarcodeFormat)barCodeFormat
{
    NSString *strAVMetadataObjectType = nil;

    switch (barCodeFormat) {
        case kBarcodeFormatQRCode:
            strAVMetadataObjectType = AVMetadataObjectTypeQRCode;
            break;
        case kBarcodeFormatEan13:
            strAVMetadataObjectType = AVMetadataObjectTypeEAN13Code;
            break;
        case kBarcodeFormatEan8:
            strAVMetadataObjectType = AVMetadataObjectTypeEAN8Code;
            break;
        case kBarcodeFormatPDF417:
            strAVMetadataObjectType = AVMetadataObjectTypePDF417Code;
            break;
        case kBarcodeFormatAztec:
            strAVMetadataObjectType = AVMetadataObjectTypeAztecCode;
            break;
        case kBarcodeFormatCode39:
            strAVMetadataObjectType = AVMetadataObjectTypeCode39Code;
            break;
        case kBarcodeFormatCode93:
            strAVMetadataObjectType = AVMetadataObjectTypeCode93Code;
            break;
        case kBarcodeFormatCode128:
            strAVMetadataObjectType = AVMetadataObjectTypeCode128Code;
            break;
        case kBarcodeFormatDataMatrix:
            strAVMetadataObjectType = AVMetadataObjectTypeDataMatrixCode;
            break;
        case kBarcodeFormatITF:
            strAVMetadataObjectType = AVMetadataObjectTypeITF14Code;
            break;
        case kBarcodeFormatRSS14:
            break;
        case kBarcodeFormatRSSExpanded:
            break;
        case kBarcodeFormatUPCA:
            break;
        case kBarcodeFormatUPCE:
            strAVMetadataObjectType = AVMetadataObjectTypeUPCECode;
            break;
        default:
            break;
    }


    return strAVMetadataObjectType;
}
#endif


- (NSString *)nativeCodeWithType:(SCANCODETYPE)type {
    switch (type) {
        case SCT_QRCode:
            return AVMetadataObjectTypeQRCode;
            break;
        case SCT_BarCode93:
            return AVMetadataObjectTypeCode93Code;
            break;
        case SCT_BarCode128:
            return AVMetadataObjectTypeCode128Code;
            break;
        case SCT_BarCodeITF:
            return @"ITF条码:only ZXing支持";
            break;
        case SCT_BarEAN13:
            return AVMetadataObjectTypeEAN13Code;
            break;

        default:
            return AVMetadataObjectTypeQRCode;
            break;
    }
}

- (void)showError:(NSString *)str {

}

- (void)requestCameraPemissionWithResult:(void (^)(BOOL granted))completion {
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
        AVAuthorizationStatus permission =
                [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

        switch (permission) {
            case AVAuthorizationStatusAuthorized:
                completion(YES);
                break;
            case AVAuthorizationStatusDenied:
            case AVAuthorizationStatusRestricted:
                completion(NO);
                break;
            case AVAuthorizationStatusNotDetermined: {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                         completionHandler:^(BOOL granted) {

                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 if (granted) {
                                                     completion(true);
                                                 } else {
                                                     completion(false);
                                                 }
                                             });

                                         }];
            }
                break;

        }
    }


}

+ (BOOL)photoPermission {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.0) {
        ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];

        if (author == ALAuthorizationStatusDenied) {

            return NO;
        }
        return YES;
    }

    PHAuthorizationStatus authorStatus = [PHPhotoLibrary authorizationStatus];
    if (authorStatus == PHAuthorizationStatusDenied) {

        return NO;
    }
    return YES;
}

#pragma mark    禁止横屏

- (BOOL)shouldAutorotate {

    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return (toInterfaceOrientation == UIInterfaceOrientationMaskPortrait);

}


- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;

}


@end
