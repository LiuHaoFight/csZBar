#import "CsZBar.h"
#import "AlmaZBarReaderViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Masonry.h>

#pragma mark - State

@interface CsZBar ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property AlmaZBarReaderViewController *scanReader;
@property(nonatomic, strong) UIView *maskView;
@property(nonatomic, strong) UIView *scanView;
@property(nonatomic, strong) NSString *tip;
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

- (void)didChangeRotate:(NSNotification *)notice {
  if (nil != self.maskView) {
    CGFloat maskW = self.maskView.frame.size.width;
    CGFloat maskH = self.maskView.frame.size.height;
    CGFloat maskX = self.maskView.frame.origin.x;
    CGFloat maskY = self.maskView.frame.origin.y;
    //        CGFloat scanW = self.scanView.frame.size.width;
    //        CGFloat scanH = self.scanView.frame.size.height;
    CGFloat scanW = 200;
    CGFloat scanH = 200;
    CGFloat scanX = self.scanView.frame.origin.x;
    CGFloat scanY = self.scanView.frame.origin.y;
    CGRect maskRect =
        CGRectMake((self.scanReader.view.frame.size.width - 200) * 0.5,
                   6 + 34 + self.statusHeight, scanW, scanH);
    [self.scanReader.view
        setFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width,
                            [UIScreen mainScreen].bounds.size.height)];
    [self.maskView layoutIfNeeded];
    [self.scanView layoutIfNeeded];

    //从蒙版中扣出扫描框那一块,这块的大小尺寸将来也设成扫描输出的作用域大小

    UIBezierPath *maskPath =
        [UIBezierPath bezierPathWithRect:self.scanReader.view.bounds];
    UIBezierPath *appendPath = [UIBezierPath bezierPathWithRoundedRect:maskRect
                                                          cornerRadius:12.0];
    [maskPath appendPath:[appendPath bezierPathByReversingPath]];

    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.path = maskPath.CGPath;
    [self.maskView.layer.mask removeFromSuperlayer];
    self.maskView.layer.mask = maskLayer;
    CGRect sc = [self getScanCrop:maskRect
                 readerViewBounds:self.scanReader.readerView.bounds];
    self.scanReader.scanCrop = sc;
  }
}

- (void)willRotateToInterfaceOrientation:
            (UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {

  return;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
    (UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

#pragma mark - Lazy

- (NSString *)tip {
  if (nil == _tip) {
    _tip = @"请扫描设备后盖的二维码";
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

- (void)scan:(CDVInvokedUrlCommand *)command;
{
  NSArray *arguments = command.arguments;
  if (arguments.count > 0) {
    self.imgBaseStr = [NSString stringWithFormat:@"%@", arguments.firstObject];
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
    self.scanReader = [AlmaZBarReaderViewController new];

    self.scanReader.readerDelegate = self;
    self.scanReader.supportedOrientationsMask =
        ZBarOrientationMask(UIInterfaceOrientationPortrait);

    // Get user parameters
    NSDictionary *params = (NSDictionary *)[command argumentAtIndex:0];
    NSString *camera = [params objectForKey:@"camera"];
    if ([camera isEqualToString:@"front"]) {
      // We do not set any specific device for the default "back" setting,
      // as not all devices will have a rear-facing camera.
      self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    }
    self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;

    NSString *flash = [params objectForKey:@"flash"];

    if ([flash isEqualToString:@"on"]) {
      self.scanReader.cameraFlashMode =
          UIImagePickerControllerCameraFlashModeOn;
    } else if ([flash isEqualToString:@"off"]) {
      self.scanReader.cameraFlashMode =
          UIImagePickerControllerCameraFlashModeOff;
    } else if ([flash isEqualToString:@"auto"]) {
      self.scanReader.cameraFlashMode =
          UIImagePickerControllerCameraFlashModeAuto;
    }

    // Hack to hide the bottom bar's Info button... originally based on
    // http://stackoverflow.com/a/16353530
    NSInteger infoButtonIndex;
    if ([[[UIDevice currentDevice] systemVersion]
            compare:@"10.0"
            options:NSNumericSearch] != NSOrderedAscending) {
      infoButtonIndex = 1;
    } else {
      infoButtonIndex = 3;
    }

    UIView *toolView = self.scanReader.view.subviews[2];
    UIToolbar *tb = toolView.subviews[0];
    [toolView removeFromSuperview];
    //        tb.frame = CGRectMake(0, 0, 320, 22);
    NSMutableArray *barButtonItems = [NSMutableArray arrayWithArray:tb.items];
    [barButtonItems removeLastObject];
    [tb setItems:barButtonItems];

    // UIView *infoButton = [[[[[self.scanReader.view.subviews objectAtIndex:2]
    // subviews] objectAtIndex:0] subviews] objectAtIndex:infoButtonIndex];
    // [infoButton setHidden:YES];

    // UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; [button
    // setTitle:@"Press Me" forState:UIControlStateNormal]; [button sizeToFit];
    // [self.view addSubview:button];
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;

    BOOL drawSight = [params objectForKey:@"drawSight"]
                         ? [[params objectForKey:@"drawSight"] boolValue]
                         : true;
    UIToolbar *toolbarViewFlash = [[UIToolbar alloc] init];

    // The bar length it depends on the orientation
    toolbarViewFlash.frame = CGRectMake(
        0.0, 0, (screenWidth > screenHeight ? screenWidth : screenHeight),
        44.0);
    toolbarViewFlash.barStyle = UIBarStyleBlackOpaque;
    UIBarButtonItem *buttonFlash =
        [[UIBarButtonItem alloc] initWithTitle:@"Flash"
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(toggleflash)];

    NSArray *buttons = [NSArray arrayWithObjects:buttonFlash, nil];
    [toolbarViewFlash setItems:buttons animated:NO];
    //        [self.scanReader.view addSubview:toolbarViewFlash];

    //        if (drawSight) {
    CGFloat dim =
        screenWidth < screenHeight ? screenWidth / 1.1 : screenHeight / 1.1;
    UIView *polygonView = [[UIView alloc]
        initWithFrame:CGRectMake((screenWidth / 2) - (dim / 2),
                                 (screenHeight / 2) - (dim / 2), dim, dim)];

    //    UIView *lineView =
    //        [[UIView alloc] initWithFrame:CGRectMake(0, dim / 2, dim, 1)];
    //    lineView.backgroundColor = [UIColor redColor];
    //    [polygonView addSubview:lineView];

    self.scanReader.cameraOverlayView = polygonView;
    //        }
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

    CGFloat imageX = screenWidth * 0.15;
    CGFloat imageY = screenWidth * 0.15 + 64;
    CGFloat scanW = 200;
    CGFloat scanH = 200;
    CGRect maskRect =
        CGRectMake((self.scanReader.view.frame.size.width - 200) * 0.5,
                   6 + 34 + self.statusHeight, scanW, scanH);
    CGFloat marginY = (self.scanReader.view.frame.size.height - 6 - 34 -
                       self.statusHeight - self.tipSize.height) *
                          0.5 -
                      200 - 20;
    UIView *scanImage = [[UIView alloc] init];
    scanImage.frame = maskRect;
    [self.scanReader.view addSubview:scanImage];
    [scanImage mas_makeConstraints:^(MASConstraintMaker *make) {
      make.width.mas_equalTo(scanW);
      make.height.mas_equalTo(scanH);
      make.top.mas_equalTo(backButton.mas_bottom).mas_offset(marginY);
      make.centerX.mas_equalTo(self.scanReader.view.mas_centerX);
    }];
    [scanImage.superview layoutIfNeeded];

    UIView *lineView = [[UIView alloc] init];
    lineView.frame = CGRectMake(0, 0, 210, 2);

    CAGradientLayer *gl = [CAGradientLayer layer];
    gl.frame = lineView.frame;
    gl.startPoint = CGPointMake(0.5, 0);
    gl.endPoint = CGPointMake(0.5, 1);
    gl.colors = @[
      (__bridge id)[UIColor colorWithRed:118 / 255.0
                                   green:213 / 255.0
                                    blue:213 / 255.0
                                   alpha:1.0]
          .CGColor,
      (__bridge id)[UIColor colorWithRed:65 / 255.0
                                   green:170 / 255.0
                                    blue:170 / 255.0
                                   alpha:1.0]
          .CGColor
    ];
    gl.locations = @[ @(0), @(1.0f) ];
    [lineView.layer addSublayer:gl];
    lineView.layer.cornerRadius = 1;
    [scanImage addSubview:lineView];
    self.lineView = lineView;
    self.scanView = scanImage;
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
      make.top.mas_equalTo(scanImage.mas_top);
      make.centerX.mas_equalTo(scanImage.mas_centerX);
      make.width.mas_equalTo(210);
      make.height.mas_equalTo(2);
    }];
    [self.scanView layoutIfNeeded];

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
    effectView.alpha = 0.7;
    [maskView addSubview:effectView];
    [effectView mas_makeConstraints:^(MASConstraintMaker *make) {
      make.edges.mas_equalTo(maskView);
    }];
    [scanImage layoutIfNeeded];
    CGFloat maskW = maskView.frame.size.width;
    CGFloat maskH = maskView.frame.size.height;
    CGFloat maskX = maskView.frame.origin.x;
    CGFloat maskY = maskView.frame.origin.y;
    //        CGFloat scanW = scanImage.frame.size.width;
    //        CGFloat scanH = scanImage.frame.size.height;
    CGFloat scanX = scanImage.frame.origin.x;
    CGFloat scanY = scanImage.frame.origin.y;

    UILabel *tipLabel = [[UILabel alloc] init];
    [tipLabel setFont:[UIFont boldSystemFontOfSize:16.0]];
    tipLabel.text = self.tip;
    [tipLabel setTextColor:[UIColor whiteColor]];
    tipLabel.numberOfLines = 0;
    [self.scanReader.view addSubview:tipLabel];
    CGFloat masOffset = 0;
    if ([UIScreen mainScreen].bounds.size.height > 667) {
      masOffset = -self.statusHeight - 6 - 34;
    }
    [tipLabel mas_makeConstraints:^(MASConstraintMaker *make) {
      make.centerX.mas_equalTo(self.scanReader.view.mas_centerX);
      make.centerY.mas_equalTo(self.scanReader.view.mas_centerY)
          .mas_offset(masOffset);
    }];
    [tipLabel.superview layoutIfNeeded];

    UIImageView *tipImageView = [[UIImageView alloc]
        initWithImage:[UIImage imageWithData:[self.imgBaseStr
                                                 dataUsingEncoding:
                                                     NSUTF8StringEncoding]]];
    tipImageView.layer.cornerRadius = 10.0;
    tipImageView.layer.masksToBounds = YES;
    tipImageView.backgroundColor = [UIColor whiteColor];
    [self.scanReader.view addSubview:tipImageView];
    [tipImageView mas_makeConstraints:^(MASConstraintMaker *make) {
      make.top.mas_equalTo(tipLabel.mas_bottom).mas_offset(20);
      make.centerX.mas_equalTo(self.scanReader.view.mas_centerX);
      make.width.mas_equalTo(scanW);
      make.height.mas_equalTo(scanH);
    }];
    [tipImageView.superview layoutIfNeeded];

    //从蒙版中扣出扫描框那一块,这块的大小尺寸将来也设成扫描输出的作用域大小

    UIBezierPath *maskPath =
        [UIBezierPath bezierPathWithRect:self.scanReader.view.bounds];
    UIBezierPath *appendPath = [UIBezierPath bezierPathWithRoundedRect:maskRect
                                                          cornerRadius:10.0];
    [maskPath appendPath:[appendPath bezierPathByReversingPath]];

    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.path = maskPath.CGPath;
    maskView.layer.mask = maskLayer;
    CGRect sc = [self getScanCrop:maskRect
                 readerViewBounds:self.scanReader.readerView.bounds];

    self.scanReader.scanCrop = sc;
    for (int i = 0; i <= self.scanReader.view.subviews.count - 1; i++) {
      UIView *tempView = self.scanReader.view.subviews[i];
      if (![tempView isKindOfClass:NSClassFromString(@"ZBarReaderViewImpl")]) {
        continue;
      } else {
        [tempView mas_makeConstraints:^(MASConstraintMaker *make) {
          make.edges.mas_equalTo(self.scanReader.view);
        }];
        [tempView.superview layoutIfNeeded];
      }
    }

    [self.scanReader.view bringSubviewToFront:backButton];
    [self.scanReader.view bringSubviewToFront:scanImage];
    [self.scanReader.view bringSubviewToFront:tipImageView];
    [self startAnim];
    [self.viewController presentViewController:self.scanReader
                                      animated:YES
                                    completion:nil];
  }
}

- (void)startAnim {

  [UIView animateWithDuration:3
                        delay:0
                      options:UIViewAnimationOptionRepeat
                   animations:^{
                     // todo 不生效
                     //        [self.lineView
                     //        mas_updateConstraints:^(MASConstraintMaker *make)
                     //        {
                     //            make.top.mas_equalTo(self.scanView.mas_top).mas_offset(self.scanView.frame.size.height);
                     //        }];
                     //        [self.scanView layoutIfNeeded];
                   }
                   completion:nil];
}

- (void)backButtonClicked {
  self.scanInProgress = NO;
  [self.scanReader dismissViewControllerAnimated:YES completion:nil];
}

- (CGRect)getScanCrop:(CGRect)rect readerViewBounds:(CGRect)readerViewBounds {
  CGFloat x, y, width, height;

  x = rect.origin.x / readerViewBounds.size.width;
  y = rect.origin.y / readerViewBounds.size.height;
  width = rect.size.width / readerViewBounds.size.width;
  height = rect.size.height / readerViewBounds.size.height;

  return CGRectMake(x, y, width, height);
}

- (void)toggleflash {
  AVCaptureDevice *device =
      [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

  [device lockForConfiguration:nil];
  if (device.torchAvailable == 1) {
    if (device.torchMode == 0) {
      [device setTorchMode:AVCaptureTorchModeOn];
      [device setFlashMode:AVCaptureFlashModeOn];
    } else {
      [device setTorchMode:AVCaptureTorchModeOff];
      [device setFlashMode:AVCaptureFlashModeOff];
    }
  }

  [device unlockForConfiguration];
}

#pragma mark - Helpers

- (void)sendScanResult:(CDVPluginResult *)result {
  [self.commandDelegate sendPluginResult:result callbackId:self.scanCallbackId];
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

  id<NSFastEnumeration> results =
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
