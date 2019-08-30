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
@property(nonatomic, strong) UIImageView *scanView;
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
    [self.scanReader.view
        setFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width,
                            [UIScreen mainScreen].bounds.size.height)];
    [self.maskView layoutIfNeeded];
    [self.scanView layoutIfNeeded];
    CGFloat maskW = self.maskView.frame.size.width;
    CGFloat maskH = self.maskView.frame.size.height;
    CGFloat maskX = self.maskView.frame.origin.x;
    CGFloat maskY = self.maskView.frame.origin.y;
    CGFloat scanW = self.scanView.frame.size.width;
    CGFloat scanH = self.scanView.frame.size.height;
    CGFloat scanX = self.scanView.frame.origin.x;
    CGFloat scanY = self.scanView.frame.origin.y;
    //从蒙版中扣出扫描框那一块,这块的大小尺寸将来也设成扫描输出的作用域大小
    UIBezierPath *maskPath =
        [UIBezierPath bezierPathWithRect:self.scanReader.view.bounds];
    UIBezierPath *appendPath = [UIBezierPath
        bezierPathWithRect:CGRectMake((maskH - scanH) * 0.5,
                                      (maskW - scanW) * 0.5, scanH, scanW)];
    [maskPath appendPath:[appendPath bezierPathByReversingPath]];

    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.path = maskPath.CGPath;
    [self.maskView.layer.mask removeFromSuperlayer];
    self.maskView.layer.mask = maskLayer;
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

#pragma mark - Plugin API

- (void)scan:(CDVInvokedUrlCommand *)command;
{
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
    [self.scanReader.view addSubview:toolbarViewFlash];

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

    CGFloat imageX = screenWidth * 0.15;
    CGFloat imageY = screenWidth * 0.15 + 64;
    UIImageView *scanImage =
        [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"saoyisao"]];
    scanImage.frame =
        CGRectMake(imageX, imageY + 44, screenWidth * 0.7, screenWidth * 0.7);
    [self.scanReader.view addSubview:scanImage];
    [scanImage mas_makeConstraints:^(MASConstraintMaker *make) {
      make.width.mas_equalTo(self.scanReader.view.frame.size.width * 0.7);
      make.height.mas_equalTo(self.scanReader.view.frame.size.width * 0.7);
      make.center.mas_equalTo(self.scanReader.view);
    }];

    //添加全屏的黑色半透明蒙版
    UIView *maskView = [[UIView alloc]
        initWithFrame:CGRectMake(0, 44, self.scanReader.view.frame.size.width,
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
    self.scanView = scanImage;
    [maskView layoutIfNeeded];
    [scanImage layoutIfNeeded];
    CGFloat maskW = maskView.frame.size.width;
    CGFloat maskH = maskView.frame.size.height;
    CGFloat maskX = maskView.frame.origin.x;
    CGFloat maskY = maskView.frame.origin.y;
    CGFloat scanW = scanImage.frame.size.width;
    CGFloat scanH = scanImage.frame.size.height;
    CGFloat scanX = scanImage.frame.origin.x;
    CGFloat scanY = scanImage.frame.origin.y;
    //从蒙版中扣出扫描框那一块,这块的大小尺寸将来也设成扫描输出的作用域大小
    UIBezierPath *maskPath =
        [UIBezierPath bezierPathWithRect:self.scanReader.view.bounds];
    UIBezierPath *appendPath = [UIBezierPath
        bezierPathWithRect:CGRectMake((maskW - scanW) * 0.5,
                                      (maskH - scanH) * 0.5, scanW, scanH)];
    [maskPath appendPath:[appendPath bezierPathByReversingPath]];

    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.path = maskPath.CGPath;
    maskView.layer.mask = maskLayer;
    [self.viewController presentViewController:self.scanReader
                                      animated:YES
                                    completion:nil];
  }
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
