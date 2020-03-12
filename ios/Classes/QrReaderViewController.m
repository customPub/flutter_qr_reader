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

@interface QrReaderViewController()<AVCaptureMetadataOutputObjectsDelegate>;

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
    }
//    if (!_cameraInvokeMsg) {
////        _cameraInvokeMsg = NSLocalizedString(@"wating...", nil);
//    }
    [_qRScanView startDeviceReadyingWithText:@""];
}
//启动设备
- (void)startScan
{
//    CGFloat width = screen_width*0.85;
//    CGFloat height = width;
    __weak typeof(self) weakSelf = self;
    UIView *videoView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame))];
    videoView.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:videoView atIndex:0];
    if (!_zxingObj) {
        self.zxingObj = [[ZXingWrapper alloc]initWithPreView:videoView block:^(ZXBarcodeFormat barcodeFormat, NSString *str, UIImage *scanImg) {
            if (str == nil) {
                str = @"";
            }
//            if (barcodeFormat != kBarcodeFormatQRCode && barcodeFormat != kBarcodeFormatEan13) {
//                str = @"";
//            }
            NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
            [dic setObject:str forKey:@"text"];
            [self->_channel invokeMethod:@"onQRCodeRead" arguments:dic];
            [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            self->_isReading = NO;
//            if (barcodeFormat == kBarcodeFormatQRCode || barcodeFormat == kBarcodeFormatEan13) {
//                if (str != nil && str.length > 0) {
//                    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
//                    [dic setObject:str forKey:@"text"];
//                    [self->_channel invokeMethod:@"onQRCodeRead" arguments:dic];
//                    [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
//                    self->_isReading = NO;
//                    return;
//                }
//            }
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
        [_zxingObj start];
    } else if ([call.method isEqualToString:@"stopCamera"]) {
        [self stopReading];
//        [_zxingObj stop];
    }
}

- (nonnull UIView *)view
{
    return _qRScanView;
}



-(void)stopReading{
    [_zxingObj stop];
    _isReading = NO;
}

// 手电筒开关
- (void) setFlashlight
{
    [_zxingObj openOrCloseTorch];
    isOpenFlash = !isOpenFlash;
    
//    [captureDevice lockForConfiguration:nil];
//    if (isOpenFlash == NO) {
//        [captureDevice setTorchMode:AVCaptureTorchModeOn];
//        isOpenFlash = YES;
//    } else {
//        [captureDevice setTorchMode:AVCaptureTorchModeOff];
//        isOpenFlash = NO;
//    }
//
//    [captureDevice unlockForConfiguration];
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

