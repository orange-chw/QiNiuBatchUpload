//
//  QNBatchUploadManager.h
//  TestDemo
//
//  Created by chw on 2018/3/30.
//  Copyright © 2018年 chw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 *  批量上传回调
 *
 *  @param  keyArray        图片组上传后的key数组
 *  @param  error           是否上传失败 如果为nil则上传成功
 *
 */
typedef void(^QNBatchpCompletionHandler)(NSArray <__kindof NSString *> * keyArray, NSError *error);
/*
 *  工具作用:批量上传图片
 *  封装对象:七牛上传文件接口
 */
@interface QNBatchUploadManager : NSObject
@property (nonatomic, strong) NSString *qiniuToken;
+ (instancetype)sharedManager;
/**
 *  上传图片组
 *
 *  @param  imgArray            图片数组
 *  @param  imageType           图片类型
 *  @param  completionHandler   上传成功的回调
 *
 */
- (void)uploadImageArray:(NSArray *)imgArray
               imageType:(NSString *)imageType
            successBlock:(QNBatchpCompletionHandler)completionHandler;
/**
 *  上传图片
 *
 *  @param  image               图片
 *  @param  imageType           图片类型
 *  @param  completionHandler   上传成功的回调
 *
 */
- (void)uploadImage:(UIImage *)image
          imageType:(NSString *)imageType
       successBlock:(QNBatchpCompletionHandler)completionHandler;
/**
 *  上传文件数据
 *
 *  @param  filePath            文件本地路径
 *  @param  completionHandler   上传成功的回调
 *
 */
- (void)uploadFileWithPath:(NSString *)filePath
              successBlock:(QNBatchpCompletionHandler)completionHandler;
@end
