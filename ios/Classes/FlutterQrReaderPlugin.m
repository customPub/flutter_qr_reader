#import "FlutterQrReaderPlugin.h"
#import "QrReaderViewController.h"
#import <LBXZBarWrapper.h>
#import <ZXingWrapper.h>

@implementation FlutterQrReaderPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    // 注册原生视图
    QrReaderViewFactory *viewFactory = [[QrReaderViewFactory alloc] initWithRegistrar:registrar];
    [registrar registerViewFactory:viewFactory withId:@"me.hetian.flutter_qr_reader.reader_view"];
    
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"me.hetian.flutter_qr_reader"
                                     binaryMessenger:[registrar messenger]];
    FlutterQrReaderPlugin* instance = [[FlutterQrReaderPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"imgQrCode" isEqualToString:call.method]) {
        [self scanQRCode:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)scanQRCode:(FlutterMethodCall*)call result:(FlutterResult)result{
    NSString *path = call.arguments[@"file"];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    [ZXingWrapper recognizeImage:image block:^(ZXBarcodeFormat barcodeFormat, NSString *str) {
        NSLog(@"format = %u", barcodeFormat);
        NSLog(@"str = %@", str);
        if (str != nil && str.length > 0) {
            result(str);
        }else{
            result(NULL);
        }
    }];
//    [LBXZBarWrapper recognizeImage:image block:^(NSArray<LBXZbarResult *> *resultArr) {
//        NSLog(@"resultArr = %@", resultArr);
//        if (resultArr.count >= 1) {
//            LBXZbarResult *res = resultArr.firstObject;
//            result(res.strScanned);
//        }else{
//            result(NULL);
//        }
//    }];
}

@end
