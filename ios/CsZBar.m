#import "CsZBar.h"
#import "AlmaZBarReaderViewController.h"
#import "WLScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Masonry.h>

#pragma mark - State

@interface CsZBar () <LBXScanViewControllerDelegate>
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property WLScanViewController *scanReader;
@property(nonatomic, strong) UIView *maskView;
@property(nonatomic, strong) UIView *scanView;
@property(nonatomic, strong) NSString *tip;
@property(nonatomic, strong) NSString *btnText;
@property(nonatomic, assign) CGSize tipSize;
@property(nonatomic, assign) CGFloat statusHeight;
@property(nonatomic, strong) UIView *lineView;
@property(nonatomic, strong) NSString *imgBaseStr;
@end

#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;

#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
    [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(didChangeRotate:)
                   name:UIApplicationDidChangeStatusBarFrameNotification
                 object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)willRotateToInterfaceOrientation:
        (UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {

    return;
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


#pragma mark - Lazy

- (NSString *)tip {
    if (nil == _tip) {
        _tip = @"请对准二维码";
    }
    return _tip;
}

- (CGSize)tipSize {
    if (CGSizeEqualToSize(_tipSize, CGSizeZero)) {
        _tipSize = [self.tip sizeWithFont:[UIFont boldSystemFontOfSize:16.0]
                        constrainedToSize:CGSizeMake(200, MAXFLOAT)];
    }
    NSLog(@"tip size === %f", _tipSize.height);
    return _tipSize;
}

- (CGFloat)statusHeight {
    if (0 == _statusHeight) {
        //获取状态栏的rect
        CGRect statusRect = [[UIApplication sharedApplication] statusBarFrame];
        _statusHeight = statusRect.size.height;
    }
    return _statusHeight;
}

#pragma mark - Plugin API

- (void)scan:(CDVInvokedUrlCommand *)command; {
    NSArray *arguments = command.arguments;
    if (arguments.count > 0) {
        NSDictionary *dict = arguments.firstObject;
        self.tip = dict[@"text_title"];
        self.btnText = dict[@"btn_text"];
        self.imgBaseStr = dict[@"text_instructions"];
    }
    if (self.scanInProgress) {
        [self.commandDelegate
                sendPluginResult:[CDVPluginResult
                        resultWithStatus:CDVCommandStatus_ERROR
                         messageAsString:@"A scan is already in progress."]
                      callbackId:[command callbackId]];
    } else {
        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [[WLScanViewController alloc] init];
        self.scanReader.isOpenInterestRect = YES;
        self.scanReader.delegate = self;

        // Get user parameters
        NSDictionary *params = (NSDictionary *) [command argumentAtIndex:0];
        NSString *camera = params[@"camera"];


        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;

        BOOL drawSight = params[@"drawSight"]
                ? [params[@"drawSight"] boolValue]
                : true;


        CGFloat dim =
                screenWidth < screenHeight ? screenWidth / 1.1 : screenHeight / 1.1;
        UIView *polygonView = [[UIView alloc]
                initWithFrame:CGRectMake((screenWidth / 2) - (dim / 2),
                        (screenHeight / 2) - (dim / 2), dim, dim)];


        UIButton *backButton = [[UIButton alloc]
                initWithFrame:CGRectMake(16, 6 + self.statusHeight, 34, 34)];
        [backButton setImage:[UIImage imageNamed:@"icon_back_white_34x34.png"]
                    forState:UIControlStateNormal];
        [backButton addTarget:self
                       action:@selector(backButtonClicked)
             forControlEvents:UIControlEventTouchUpInside];
        [self.scanReader.view addSubview:backButton];
        [backButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(self.scanReader.view.mas_top)
                    .mas_offset(6 + self.statusHeight);
            make.left.mas_equalTo(self.scanReader.view.mas_left).mas_offset(16);
            make.width.mas_equalTo(34);
            make.height.mas_equalTo(34);
        }];

        UILabel *tipLabel = [[UILabel alloc] init];
        [tipLabel setFont:[UIFont boldSystemFontOfSize:16.0]];
        tipLabel.text = self.tip;
        [tipLabel setTextColor:[UIColor whiteColor]];
        tipLabel.numberOfLines = 0;
        [tipLabel setTextAlignment:NSTextAlignmentCenter];
        [self.scanReader.view addSubview:tipLabel];
        CGFloat masOffset = 0;
        if ([UIScreen mainScreen].bounds.size.height > 667) {
            //      masOffset = -self.statusHeight - 6 - 34;
            masOffset = -self.statusHeight - 6;
        }
        [tipLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.mas_equalTo(self.scanReader.view.mas_centerX);
            make.centerY.mas_equalTo(self.scanReader.view.mas_centerY);
            make.width.mas_equalTo(self.scanReader.view.mas_width);
        }];
        [tipLabel.superview layoutIfNeeded];
        CGFloat imageX = screenWidth * 0.15;
        CGFloat imageY = screenWidth * 0.15 + 64;
        CGFloat scanW = [UIScreen mainScreen].bounds.size.width > 350 ? 250 : 200;
        CGFloat scanH = scanW;
        CGRect maskRect =
                CGRectMake((self.scanReader.view.frame.size.width - scanW) * 0.5,
                        6 + 34 + self.statusHeight, scanW, scanH);
        CGFloat marginY = (self.scanReader.view.frame.size.height - 6 - 34 -
                self.statusHeight - self.tipSize.height) *
                0.5 -
                scanH - 20;
        UIView *scanImage = [[UIView alloc] init];
        scanImage.frame = maskRect;
        [self.scanReader.view addSubview:scanImage];
        [scanImage mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.mas_equalTo(scanW);
            make.height.mas_equalTo(scanH);
            make.bottom.mas_equalTo(tipLabel.mas_top).mas_offset(-20);
            make.centerX.mas_equalTo(self.scanReader.view.mas_centerX);
        }];
        [scanImage.superview layoutIfNeeded];

        maskRect = scanImage.frame;
        UIView *lineView = [[UIView alloc] init];
        lineView.frame = CGRectMake(0, 0, scanH + 10, 2);

        CAGradientLayer *gl = [CAGradientLayer layer];
        gl.frame = lineView.frame;
        gl.startPoint = CGPointMake(0.5, 0);
        gl.endPoint = CGPointMake(0.5, 1);
        gl.colors = @[
                (__bridge id) [UIColor colorWithRed:118 / 255.0
                                              green:213 / 255.0
                                               blue:213 / 255.0
                                              alpha:1.0]
                        .CGColor,
                (__bridge id) [UIColor colorWithRed:65 / 255.0
                                              green:170 / 255.0
                                               blue:170 / 255.0
                                              alpha:1.0]
                        .CGColor
        ];
        gl.locations = @[@(0), @(1.0f)];
        [lineView.layer addSublayer:gl];
        lineView.layer.cornerRadius = 1;
        [scanImage addSubview:lineView];
        self.lineView = lineView;
        self.scanView = scanImage;
        [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(scanImage.mas_top).mas_offset(1);
            make.centerX.mas_equalTo(scanImage.mas_centerX);
            make.width.mas_equalTo(scanH + 10);
            make.height.mas_equalTo(2);
        }];
        [lineView.superview layoutIfNeeded];

        //添加全屏的黑色半透明蒙版
        UIView *maskView = [[UIView alloc]
                initWithFrame:CGRectMake(0, 0, self.scanReader.view.frame.size.width,
                        self.scanReader.view.frame.size.height)];
        maskView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        [self.scanReader.view addSubview:maskView];
        [maskView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self.scanReader.view.mas_left);
            make.right.mas_equalTo(self.scanReader.view.mas_right);
            make.top.mas_equalTo(self.scanReader.view.mas_top);
            make.bottom.mas_equalTo(self.scanReader.view.mas_bottom);
        }];
        self.maskView = maskView;

        [maskView.superview layoutIfNeeded];
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *effectView =
                [[UIVisualEffectView alloc] initWithEffect:blur];
        effectView.frame = maskView.frame;
        effectView.alpha = 0.9;
        [maskView addSubview:effectView];
        [effectView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(maskView);
        }];
        [scanImage layoutIfNeeded];

        NSURL *imageUrl = [NSURL URLWithString:self.imgBaseStr];
        UIImageView *tipImageView = [[UIImageView alloc]
                initWithImage:[UIImage
                        imageWithData:[NSData
                                dataWithContentsOfURL:imageUrl]]];
        tipImageView.layer.cornerRadius = 10.0;
        tipImageView.layer.masksToBounds = YES;
        [self.scanReader.view addSubview:tipImageView];
        if (self.imgBaseStr.length > 1) {
            tipImageView.hidden = false;
        } else {
            tipImageView.hidden = true;
        }
        [tipImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(tipLabel.mas_bottom).mas_offset(20);
            make.centerX.mas_equalTo(self.scanReader.view.mas_centerX);
            make.width.mas_equalTo(scanW);
            make.height.mas_equalTo(scanH);
        }];
        [tipImageView setContentMode:UIViewContentModeScaleAspectFit];
        [tipImageView.superview layoutIfNeeded];

        UIButton *skipBtn = [[UIButton alloc] init];
        [skipBtn setTitle:self.btnText forState:(UIControlStateNormal)];
        [skipBtn setTitleColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.8] forState:UIControlStateNormal];
        skipBtn.layer.cornerRadius = 5.0;
        skipBtn.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10);
        [skipBtn.layer setMasksToBounds:YES];
        [skipBtn.layer setBorderWidth:1.0];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGColorRef colorref = CGColorCreate(colorSpace,(CGFloat[]){ 255, 255, 255, 0.8 });
        [skipBtn.layer setBorderColor:colorref];
        skipBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [skipBtn addTarget:self
                       action:@selector(skipButtonClicked)
             forControlEvents:UIControlEventTouchUpInside];
        
        [self.scanReader.view addSubview:skipBtn];
        [skipBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(tipImageView.mas_bottom).mas_offset(25);
            make.centerX.mas_equalTo(self.scanReader.view.mas_centerX);
        }];
        [skipBtn setContentMode:UIViewContentModeScaleAspectFit];
        [skipBtn.superview layoutIfNeeded];
        
        
        //从蒙版中扣出扫描框那一块,这块的大小尺寸将来也设成扫描输出的作用域大小

        UIBezierPath *maskPath =
                [UIBezierPath bezierPathWithRect:self.scanReader.view.bounds];
        UIBezierPath *appendPath = [UIBezierPath bezierPathWithRoundedRect:maskRect
                                                              cornerRadius:10.0];
        [maskPath appendPath:[appendPath bezierPathByReversingPath]];

        CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
        maskLayer.path = maskPath.CGPath;
        maskView.layer.mask = maskLayer;

        [self.scanReader.view bringSubviewToFront:backButton];
        [self.scanReader.view bringSubviewToFront:scanImage];
        [self.scanReader.view bringSubviewToFront:tipImageView];
        [self.scanReader.view bringSubviewToFront:tipLabel];
        [self.scanReader.view bringSubviewToFront:skipBtn];
        CGRect sc = [self getScanRectWithPreView:self.scanReader.view];
        self.scanReader.cropRect = sc;
        self.scanReader.modalPresentationStyle = UIModalPresentationFullScreen;
        [self.viewController presentViewController:self.scanReader
                                          animated:YES
                                        completion:^{
                                            [self startAnim];
                                        }];
    }
}

- (void)startAnim {

    [UIView animateWithDuration:2.5
                          delay:0
                        options:UIViewAnimationOptionRepeat
                     animations:^{
                         [self.lineView
                                 mas_updateConstraints:^(MASConstraintMaker *make) {
                                     make.top.mas_equalTo(self.scanView.mas_top)
                                             .mas_offset(self.scanView.frame.size.height - 2);
                                 }];
                         [self.lineView.superview layoutIfNeeded];
                     }
                     completion:nil];
}

- (void)backButtonClicked {
    self.scanInProgress = NO;
    [self.scanReader dismissViewControllerAnimated:YES completion:nil];
}

- (void)skipButtonClicked {
    NSLog(@"skipButtonClicked");
    [self.scanReader
            dismissViewControllerAnimated:YES
                               completion:^(void) {
                                        self.scanInProgress = NO;
                                        [self sendScanResult:
                                                [CDVPluginResult
                                                        resultWithStatus:CDVCommandStatus_OK
                                                         messageAsString:@"skip"]];
                                    }];
    
}

//根据矩形区域，获取识别区域
- (CGRect)getScanRectWithPreView:(UIView *)view {
    [self.scanView layoutIfNeeded];
    int XRetangleLeft = self.scanView.frame.origin.x;
    CGSize sizeRetangle = CGSizeMake(view.frame.size.width - XRetangleLeft * 2, view.frame.size.width - XRetangleLeft * 2);
    //扫码区域Y轴最小坐标
    CGFloat my = (view.frame.size.height - self.scanView.frame.size.height ) * 0.5 - self.scanView.frame.origin.y;
    CGFloat YMinRetangle = view.frame.size.height / 2.0 - sizeRetangle.height / 2.0 - my;

    //扫码区域坐标
    CGRect cropRect = CGRectMake(XRetangleLeft, YMinRetangle, sizeRetangle.width, sizeRetangle.height);

    //计算兴趣区域
    CGRect rectOfInterest;
    CGSize size = view.bounds.size;
    CGFloat p1 = size.height / size.width;
    CGFloat p2 = 1920. / 1080.;  //使用了1080p的图像输出
    if (p1 < p2) {
        CGFloat fixHeight = size.width * 1920. / 1080.;
        CGFloat fixPadding = (fixHeight - size.height) / 2;
        rectOfInterest = CGRectMake((cropRect.origin.y + fixPadding) / fixHeight,
                cropRect.origin.x / size.width,
                cropRect.size.height / fixHeight,
                cropRect.size.width / size.width);


    } else {
        CGFloat fixWidth = size.height * 1080. / 1920.;
        CGFloat fixPadding = (fixWidth - size.width) / 2;
        rectOfInterest = CGRectMake(cropRect.origin.y / size.height,
                (cropRect.origin.x + fixPadding) / fixWidth,
                cropRect.size.height / size.height,
                cropRect.size.width / fixWidth);


    }

    return rectOfInterest;
}


//根据矩形区域，获取zxing识别区域
- (CGRect)getZXingScanRectWithPreView:(UIView *)view {
    [self.scanView layoutIfNeeded];
    int XRetangleLeft = self.scanView.frame.origin.x;
    CGSize sizeRetangle = CGSizeMake(view.frame.size.width - XRetangleLeft * 2, view.frame.size.width - XRetangleLeft * 2);
    //扫码区域Y轴最小坐标
    CGFloat my = (view.frame.size.height - self.scanView.frame.size.height - self.scanView.frame.origin.y) * 0.5;
    CGFloat YMinRetangle = view.frame.size.height / 2.0 - sizeRetangle.height / 2.0 - my;

    XRetangleLeft = XRetangleLeft / view.frame.size.width * 1080;
    YMinRetangle = YMinRetangle / view.frame.size.height * 1920;
    CGFloat width = sizeRetangle.width / view.frame.size.width * 1080;
    CGFloat height = sizeRetangle.height / view.frame.size.height * 1920;

    //扫码区域坐标
    CGRect cropRect = CGRectMake(XRetangleLeft, YMinRetangle, width, height);

    return cropRect;
}


- (CGRect)getPortraitModeScanCropRect:(CGRect)overlayCropRect
                       forOverlayView:(UIView *)readerView {
    CGRect scanCropRect = CGRectMake(0, 0, 1, 1); /*default full screen*/

    float x = overlayCropRect.origin.x;
    float y = overlayCropRect.origin.y;
    float width = overlayCropRect.size.width;
    float height = overlayCropRect.size.height;

    float A = y / readerView.bounds.size.height;
    float B = 1 - (x + width) / readerView.bounds.size.width;
    float C = (y + height) / readerView.bounds.size.height;
    float D = 1 - x / readerView.bounds.size.width;

    scanCropRect = CGRectMake(A, B, C, D);

    return scanCropRect;
}

#pragma mark - Helpers

- (void)sendScanResult:(CDVPluginResult *)result {
    [self.commandDelegate sendPluginResult:result callbackId:self.scanCallbackId];
}

#pragma mark - WLScanViewControllerDelegate

- (void)scanResultWithArray:(NSArray<LBXScanResult *> *)array {
    if (!array || array.count < 1) {
        // 没扫到
        [self.scanReader
                dismissViewControllerAnimated:YES
                                   completion:^(void) {
                                       self.scanInProgress = NO;
                                       [self sendScanResult:
                                               [CDVPluginResult
                                                       resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"Failed"]];
                                   }];
        return;
    }

    //经测试，可以ZXing同时识别2个二维码，不能同时识别二维码和条形码


    LBXScanResult *scanResult = array[0];

    NSString *strResult = scanResult.strScanned;


    if (!strResult) {

        // 没扫到
        [self.scanReader
                dismissViewControllerAnimated:YES
                                   completion:^(void) {
                                       self.scanInProgress = NO;
                                       [self sendScanResult:
                                               [CDVPluginResult
                                                       resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"Failed"]];
                                   }];
        return;
    }

    [self.scanReader
            dismissViewControllerAnimated:YES
                               completion:^(void) {
                                   self.scanInProgress = NO;
                                   [self sendScanResult:
                                           [CDVPluginResult
                                                   resultWithStatus:CDVCommandStatus_OK
                                                    messageAsString:strResult]];
                               }];

}

#pragma mark - ZBarReaderDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingImage:(UIImage *)image
                  editingInfo:(NSDictionary *)editingInfo {
    return;
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
    if ([self.scanReader isBeingDismissed]) {
        return;
    }

    id <NSFastEnumeration> results =
            [info objectForKey:ZBarReaderControllerResults];

    ZBarSymbol *symbol = nil;
    for (symbol in results)
        break; // get the first result

    [self.scanReader
            dismissViewControllerAnimated:YES
                               completion:^(void) {
                                   self.scanInProgress = NO;
                                   [self sendScanResult:
                                           [CDVPluginResult
                                                   resultWithStatus:CDVCommandStatus_OK
                                                    messageAsString:symbol.data]];
                               }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self.scanReader
            dismissViewControllerAnimated:YES
                               completion:^(void) {
                                   self.scanInProgress = NO;
                                   [self sendScanResult:
                                           [CDVPluginResult
                                                   resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:@"cancelled"]];
                               }];
}

- (void)readerControllerDidFailToRead:(ZBarReaderController *)reader
                            withRetry:(BOOL)retry {
    [self.scanReader
            dismissViewControllerAnimated:YES
                               completion:^(void) {
                                   self.scanInProgress = NO;
                                   [self sendScanResult:
                                           [CDVPluginResult
                                                   resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:@"Failed"]];
                               }];
}

@end
