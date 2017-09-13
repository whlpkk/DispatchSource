//
//  ViewController.m
//  DispatchSource
//
//  Created by YZK on 2017/9/4.
//  Copyright © 2017年 MOMO. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end



@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    //创建source，以DISPATCH_SOURCE_TYPE_DATA_ADD的方式进行累加，而DISPATCH_SOURCE_TYPE_DATA_OR是对结果进行二进制或运算
//    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_OR, 0, 0, dispatch_get_main_queue());
//
//    //事件触发后执行的句柄
//    dispatch_source_set_event_handler(source,^{
//        NSLog(@"监听函数：%lu",dispatch_source_get_data(source));
//    });
//    
//    //开启source
//    dispatch_resume(source);
//    
//    dispatch_queue_t myqueue =dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    
//    dispatch_async(myqueue, ^ {
//        
//        for(int i = 1; i <= 4; i ++){
//            
//            NSLog(@"~~~~~~~~~~~~~~%d", i);
//            
//            //触发事件，向source发送事件，这里i不能为0，否则触发不了事件
//            dispatch_source_merge_data(source,i);
//
//            //当Interval的事件越长，则每次的句柄都会触发
//            [NSThread sleepForTimeInterval:0.1];
//        }
//    });
    
    
    
    //1、指定DISPATCH_SOURCE_TYPE_DATA_ADD，做成Dispatch Source(分派源)。设定Main Dispatch Queue 为追加处理的Dispatch Queue
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, dispatch_get_main_queue());
    __block NSUInteger totalComplete = 0;
    dispatch_source_set_event_handler(source, ^{
        //当处理事件被最终执行时，计算后的数据可以通过dispatch_source_get_data来获取。这个数据的值在每次响应事件执行后会被重置，所以totalComplete的值是最终累积的值。
        NSUInteger value = dispatch_source_get_data(source);
        totalComplete += value;
        NSLog(@"进度：%@", @((CGFloat)totalComplete/100));
    });
    
    //分派源创建时默认处于暂停状态，在分派源分派处理程序之前必须先恢复。
    dispatch_resume(source);
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    for (NSUInteger index = 0; index < 100; index++) {
        dispatch_async(queue, ^{
            usleep(20000);//0.02秒
            dispatch_source_merge_data(source, 1);
        });
    }
}




@end
