//
//  ReReaderViewController.m
//  flutter_qr_reader
//
//  Created by 王贺天 on 2019/6/7.
//

#import "QrReaderViewController.h"
#import "ZXingWrapper.h"
#import <LBXScanView.h>

#define screen_width [UIScreen mainScreen].bounds.size.width
#define screen_height [UIScreen mainScreen].bounds.size.height

@interface QrReaderViewController()<AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic, strong) ZXingWrapper *zxingObj;
@property (nonatomic,strong) LBXScanView* qRScanView;
@property (nonatomic, strong) LBXScanViewStyle *style;

@end

@implementation QrReaderViewController{
    UIView* _qrcodeview;
    int64_t _viewId;
    FlutterMethodChannel* _channel;
    NSObject<FlutterPluginRegistrar>* _registrar;
    NSNumber *height;
    NSNumber *width;
    BOOL isOpenFlash;
    BOOL _isReading;
    AVCaptureDevice *captureDevice;
    NSArray<AVMetadataObjectType> *_metadataObjectTypes;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
{
    if ([super init]) {
        _metadataObjectTypes = @[
           AVMetadataObjectTypeEAN13Code,
           AVMetadataObjectTypeQRCode,
        ];
        _registrar = registrar;
        _viewId = viewId;
        NSString *channelName = [NSString stringWithFormat:@"me.hetian.flutter_qr_reader.reader_view_%lld", viewId];
        _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:registrar.messenger];
        __weak __typeof__(self) weakSelf = self;
        [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            [weakSelf onMethodCall:call result:result];
        }];
        width = args[@"width"];
        height = args[@"height"];
        NSLog(@"%@,%@", width, height);
        
//        _qrcodeview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width.floatValue, height.floatValue) ];
////        _qrcodeview.opaque = NO;
//        _qrcodeview.backgroundColor = [UIColor blackColor];
        
        isOpenFlash = NO;
        _isReading = NO;
        
        [self drawScanView];
        [self requestCameraPemissionWithResult:^(BOOL granted) {
            if (granted) {
                //不延时，可能会导致界面黑屏并卡住一会
                [self performSelector:@selector(startScan) withObject:nil afterDelay:0.3];
            }else{
                [weakSelf.qRScanView stopDeviceReadying];
            }
        }];
    }
    return self;
}
- (void)requestCameraPemissionWithResult:(void(^)( BOOL granted))completion
{
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
    {
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
            case AVAuthorizationStatusNotDetermined:
            {
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


//绘制扫描区域
- (void)drawScanView
{
    if (!_qRScanView)
    {
        CGRect rect = CGRectMake(0, 0, screen_width, screen_height);
        _style = [[LBXScanViewStyle alloc] init];
        _style.isNeedShowRetangle = NO;
        _style.colorRetangleLine = [UIColor clearColor];
        _style.colorAngle = [UIColor clearColor];
        _style.anmiationStyle = LBXScanViewAnimationStyle_None;
        _style.xScanRetangleOffset = screen_width*0.15/2;
        self.qRScanView = [[LBXScanView alloc]initWithFrame:rect style:_style];
        
//        [self.view addSubview:_qRScanView];
    }
//    if (!_cameraInvokeMsg) {
////        _cameraInvokeMsg = NSLocalizedString(@"wating...", nil);
//    }
    [_qRScanView startDeviceReadyingWithText:@""];
}
//启动设备
- (void)startScan
{
    CGFloat width = screen_width*0.85;
    CGFloat height = width;
    UIView *videoView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame))];
    videoView.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:videoView atIndex:0];
    if (!_zxingObj) {
        self.zxingObj = [[ZXingWrapper alloc]initWithPreView:videoView block:^(ZXBarcodeFormat barcodeFormat, NSString *str, UIImage *scanImg) {
            if (str != nil && str.length > 0) {
                NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
                [dic setObject:str forKey:@"text"];
                [self->_channel invokeMethod:@"onQRCodeRead" arguments:dic];
                [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
                self->_isReading = NO;
            }
        }];
        //设置只识别框内区域
        CGRect cropRect = [LBXScanView getZXingScanRectWithPreView:videoView style:_style];
                            
         [_zxingObj setScanRect:cropRect];
//        [self.zxingObj setScanRect:CGRectMake((screen_width - width)/2, (screen_height - height)/2, width, height)];
    }
    [_zxingObj start];
    [_qRScanView stopDeviceReadying];
    [_qRScanView startScanAnimation];
    self.view.backgroundColor = [UIColor clearColor];
}



- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result
{
    if ([call.method isEqualToString:@"flashlight"]) {
        [self setFlashlight];
    }else if ([call.method isEqualToString:@"startCamera"]) {
//        [self startReading];
        [_zxingObj start];
    } else if ([call.method isEqualToString:@"stopCamera"]) {
//        [self stopReading];
        [_zxingObj stop];
    }
}

- (nonnull UIView *)view {
//    return _qrcodeview;
    return _qRScanView;
}

- (BOOL)startReading {
    if (_isReading) return NO;
    _isReading = YES;
    NSError *error;
    _captureSession = [[AVCaptureSession alloc] init];
    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    [_captureSession addInput:input];
    
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    
    
//    CGRect intersetRect = CGRectMake(self.view.frame.origin.y/screen_height, self.view.frame.origin.x/screen_width, self.view.frame.size.height/screen_height, self.view.frame.size.width/screen_width);
    CGRect intersetRect = CGRectMake(self.view.frame.origin.y/screen_height, self.view.frame.origin.x/screen_width, height.floatValue, width.floatValue);
    NSLog(@"%@", NSStringFromCGRect(intersetRect));
    //设置识别区域
    //深坑，这个值是按比例0~1设置，而且X、Y要调换位置，width、height调换位置
    captureMetadataOutput.rectOfInterest = intersetRect;
    __weak typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter]
     addObserverForName:AVCaptureInputPortFormatDescriptionDidChangeNotification
         object:nil
         queue:[NSOperationQueue mainQueue]
         usingBlock:^(NSNotification * _Nonnull note) {
            if (weakSelf){
                //调整扫描区域
                captureMetadataOutput.rectOfInterest = intersetRect;
            }
    }];
    
    
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatch_queue_create("myQueue", NULL)];
    
    
    [_captureSession addOutput:captureMetadataOutput];
//    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    [captureMetadataOutput setMetadataObjectTypes:_metadataObjectTypes];
    
    
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_videoPreviewLayer setFrame:_qrcodeview.layer.bounds];
    [_qrcodeview.layer addSublayer:_videoPreviewLayer];
    [_captureSession startRunning];
    return YES;
}


-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    NSLog(@"%@",metadataObjects);
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
//        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
        if ([_metadataObjectTypes containsObject:[metadataObj type]]) {
            NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
            [dic setObject:[metadataObj stringValue] forKey:@"text"];
            [_channel invokeMethod:@"onQRCodeRead" arguments:dic];
            [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            _isReading = NO;
        }
    }
}


-(void)stopReading{
    [_captureSession stopRunning];
    _captureSession = nil;
    [_videoPreviewLayer removeFromSuperlayer];
    _isReading = NO;
}

// 手电筒开关
- (void) setFlashlight
{
    [captureDevice lockForConfiguration:nil];
    if (isOpenFlash == NO) {
        [captureDevice setTorchMode:AVCaptureTorchModeOn];
        isOpenFlash = YES;
    } else {
        [captureDevice setTorchMode:AVCaptureTorchModeOff];
        isOpenFlash = NO;
    }
    
    [captureDevice unlockForConfiguration];
}

@end

@implementation QrReaderViewFactory{
    NSObject<FlutterPluginRegistrar>* _registrar;
}
- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar
{
    self = [super init];
    if (self) {
        _registrar = registrar;
    }
    return self;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args
{
    QrReaderViewController* viewController = [[QrReaderViewController alloc] initWithFrame:frame
                                                                            viewIdentifier:viewId
                                                                                 arguments:args
                                                                           binaryRegistrar:_registrar];
    return viewController;
}
@end

