//
//  AlmaZBarReaderViewController.m
//  BarCodeMix
//
//  Created by eCompliance on 23/01/15.

#import "AlmaZBarReaderViewController.h"
#import "CsZbar.h"

@interface AlmaZBarReaderViewController ()

@end

@implementation AlmaZBarReaderViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [[UIApplication sharedApplication] setStatusBarHidden:YES];
  // Do any additional setup after loading the view.
  UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  //[button setTitle:@"Flash" forState:UIControlStateNormal];
  [button sizeToFit];
  CGRect screenRect = [[UIScreen mainScreen] bounds];
  //[button setContentEdgeInsets:UIEdgeInsetsMake(20, 30, 20, 30)];
  CGRect frame;

  self.view.frame =
      CGRectMake(0, 0, screenRect.size.width, screenRect.size.height);
  if (screenRect.size.height > (screenRect.size.width)) {
    frame = CGRectMake(0, 0, screenRect.size.width * (0.15),
                       screenRect.size.height * 0.15);
  } else {
    frame = CGRectMake(0, 0, screenRect.size.width * (0.10),
                       screenRect.size.height * 0.20);
  }

  button.frame = frame;
  button.layer.cornerRadius = 10;
  button.clipsToBounds = YES;

  [button addTarget:self
                action:@selector(buttonPressed:)
      forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:button];
}

- (BOOL)prefersStatusBarHidden {
  return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

// Techedge Changes NSS fase 2
- (void)buttonPressed:(UIButton *)button {
  CsZBar *obj = [[CsZBar alloc] init];

  [obj toggleflash];
}

- (BOOL)shouldAutorotate {
  return NO;
}

- (void)didRotateFromInterfaceOrientation:
    (UIInterfaceOrientation)fromInterfaceOrientation {
  // AlmaZBarReaderViewController.scanner.scanner.cameraOverlayView = poli
  // NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
  BOOL drawSight = true; //[params objectForKey:@"drawSight"] ? [[params
                         // objectForKey:@"drawSight"] boolValue] : true;

  if (drawSight) {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat dim =
        screenWidth < screenHeight ? screenWidth / 1.1 : screenHeight / 1.1;
    UIView *polygonView = [[UIView alloc]
        initWithFrame:CGRectMake((screenWidth / 2) - (dim / 2),
                                 (screenHeight / 2) - (dim / 2), dim, dim)];

    // UIView *lineView =
    //     [[UIView alloc] initWithFrame:CGRectMake(0, dim / 2, dim, 1)];
    // lineView.backgroundColor = [UIColor redColor];
    // [polygonView addSubview:lineView];
    self.cameraOverlayView = polygonView;
  }
}

@end
