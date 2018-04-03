//
//  QNBatchUploadManager.m
//  TestDemo
//
//  Created by chw on 2018/3/30.
//  Copyright © 2018年 chw. All rights reserved.
//

#import "QNBatchUploadManager.h"
#import "QiniuSDK.h"


@implementation NSString(Qiniu)
/**
 *  字符串判空
 *
 *  @param  string     需要判空的自字符串
 *  @return BOOL类型,YES为空字符
 *
 */
+ (BOOL)isEmpty:(NSString *)string {
    return [string isEqual:[NSNull null]] || string == nil || string.length == 0;
}
/**
 *  七牛key值定义
 *
 *  @param  type       图片用途type
 *  @param  suffix     图片类型后缀jpg或者是png或者其它
 *
 */
+ (NSString *)qiniuKeyType:(NSString *)type suffix:(NSString *)suffix{
    NSTimeInterval time_interval = [[[NSDate date]dateByAddingTimeInterval:[[NSTimeZone systemTimeZone]secondsFromGMT]] timeIntervalSince1970];
    return [NSString stringWithFormat:@"%@_%.f_%04i%@",type,time_interval,(u_int32_t)arc4random()%10000,suffix];
}

@end

@implementation UIImage(Qiniu)

/**
 *  图片压缩
 *  先按照尺寸比例压缩，再进行质量压缩 使用尺寸为480*800
 *  如果宽度小于高度 则会以宽度为480为基准压缩图片尺寸
 *  返之，则会以高度为800为基准压缩图片尺寸
 *
 */
- (NSData *)scaleImage{
    CGFloat width = 480;
    CGFloat height = 800;
    CGFloat imageWith = self.size.width;
    CGFloat imageHeight = self.size.height;
    
    CGSize size = CGSizeZero;
    if (imageWith > imageHeight) {
        if(width < imageWith){
            size = CGSizeMake(width, width/(imageWith/imageHeight));
        }else{
            size = self.size;
        }
    }else{
        if (height < imageHeight) {
            size = CGSizeMake(imageWith/imageHeight*height, height);
        }else{
            size = self.size;
        }
    }
    UIGraphicsBeginImageContext(size);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *scaleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return UIImageJPEGRepresentation(scaleImage, 0.5);;
}

@end

@implementation NSData(Qiniu)
//获取图片格式
- (NSString *) imageFormatType{
    uint8_t c;
    [self getBytes:&c length:1];
    switch (c) {
        case 0xFF: return @".jpeg";
        case 0x89: return @".png";
        case 0x47: return @".gif";
        case 0x49:
        case 0x4D: return @".tiff";
        default: return @".undefine";
    }
    return nil;
}

@end

@interface QNBatchUploadManager ()
{
    QNUploadManager *_manager;
}
@end

@implementation QNBatchUploadManager
+ (instancetype)sharedManager{
    static QNBatchUploadManager *manager = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (!manager) {
            manager = [[QNBatchUploadManager alloc] init];
        }
    });
    return manager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _manager = [QNUploadManager sharedInstanceWithConfiguration:nil];
    }
    return self;
}

//批量上传图片接口
- (void)uploadImageArray:(NSArray *)imgArray
               imageType:(NSString *)imageType
            successBlock:(QNBatchpCompletionHandler)completionHandler{
    //七牛token
    if ([NSString isEmpty:self.qiniuToken]) {
        NSError *error = [NSError errorWithDomain:@"七牛token为空" code:100 userInfo:@{NSLocalizedDescriptionKey:@"七牛token为空,请重新获取"}];
        !completionHandler ? : completionHandler(nil,error);
        return;
    }
    NSString *token = self.qiniuToken.copy;
    
    //如果无图片可上传 直接执行block
    //这里无图片等上传此处作为成功处理 error传nil
    if (imgArray.count == 0) {
        !completionHandler ? : completionHandler(@[],nil);
        return;
    }

    //初始化上传需要的参数
    NSMutableArray *dataArray = @[].mutableCopy;
    NSMutableArray *keyArray = @[].mutableCopy;
    for (UIImage *image in imgArray) {
        //imageData转换
        NSData *data = [image scaleImage];
        [dataArray addObject:data];
        //imageKey获取x
        NSString *key = [NSString qiniuKeyType:imageType suffix:[data imageFormatType]];
        [keyArray addObject:key];
    }
    //回调数组
    NSMutableArray *resultArray = @[].mutableCopy;
    //获取全局并发队列
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    //创建group
    dispatch_group_t group = dispatch_group_create();
    //记录上传失败的error;
    __block NSError *error = nil;
    //GCD遍历图片数组
    __weak __typeof(_manager)weakManager = _manager;
    dispatch_apply(imgArray.count, queue, ^(size_t index){
        dispatch_group_enter(group);
        //采用group的异步执行方法将block追加到定义的全局并发队列queue中，并且等待全部结束处理执行
        __strong __typeof(weakManager)strongManager = weakManager;
        dispatch_group_async(group, queue, ^{
            [strongManager putData:dataArray[index] key:keyArray[index] token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
                if (!info.error && resp) {
                    //上传成功
                    [resultArray addObject:key];
                }else{
                    //上传失败
                    error = info.error;
                }
                dispatch_group_leave(group);
            } option:nil];
        });
    });
    //group内的任务完成通知
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (resultArray.count == keyArray.count) {
            !completionHandler ? : completionHandler(keyArray,nil);
        }else{
            !completionHandler ? : completionHandler(keyArray,error);
        }
    });
}

//上传单个图片
- (void)uploadImage:(UIImage *)image
          imageType:(NSString *)imageType
       successBlock:(QNBatchpCompletionHandler)completionHandler{
    //如果图片为nil 默认上传成功
    if (image == nil) {
        !completionHandler ? : completionHandler(@[],nil);
        return;
    }
    [self uploadImageArray:@[image] imageType:imageType successBlock:completionHandler];
}

//上传文件
- (void)uploadFileWithPath:(NSString *)filePath
              successBlock:(QNBatchpCompletionHandler)completionHandler{
    //七牛token
    if ([NSString isEmpty:self.qiniuToken]) {
        NSError *error = [NSError errorWithDomain:@"七牛token为空" code:100 userInfo:@{NSLocalizedDescriptionKey:@"七牛token为空,请重新获取"}];
        !completionHandler ? : completionHandler(nil,error);
        return;
    }
    NSString *token = self.qiniuToken.copy;
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    //如果data为空，默认上传成功
    if (data.length == 0) {
        !completionHandler ? : completionHandler(@[],nil);
        return;
    }

    //上传的key
    NSString *last = [[filePath componentsSeparatedByString:@"／"] lastObject];
    NSArray *fileNameArray = [last componentsSeparatedByString:@"."];
    NSString *suffix = fileNameArray.count < 2 ? @"" : fileNameArray.lastObject;
    NSString *key = [NSString qiniuKeyType:fileNameArray.firstObject suffix:suffix];;
    
    [_manager putData:data key:key token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        if (!info.error && resp) {
            !completionHandler ? : completionHandler(@[key],nil);
        }else{
            !completionHandler ? : completionHandler(@[key],info.error);
        }
    } option:nil];
}

@end

