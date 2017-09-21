## Dispatch_source

使用 Dispatch Source 而不使用 dispatch_async 的唯一原因就是利用联结的优势。

联结的大致流程：在任一线程上调用它的一个函数 dispatch_source_merge_data 后，会在相应quene执行 Dispatch Source 事先定义好的句柄（可以把句柄简单理解为一个 block ）。

这个过程叫 Custom event ，用户事件。是 dispatch source 支持处理的一种事件。

简单地说，这种事件是由你调用 dispatch\_source\_merge\_data 函数来向自己发出的信号。



#### 一、创建dispatch源

```
dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, dispatch_get_main_queue());

```

##### 参数:

| 参数         | 意义            		  | 
|:-----------:|:---------------      | 
| type        | dispatch源可处理的事件类型 |
| handle      | 可以理解为索引、id或句柄，假如要监听进程，需要传入进程的ID |
| mask        | 可以理解为描述，提供更详细的描述，让它知道具体要监听什么   | 
| queue       | 自定义源需要的一个队列，用来处理所有的响应句柄（block）   | 


##### Dispatch Source可处理的所有事件:

| 名称                            | 意义                 | 
|:------------------------------ |:---------------      | 
| DISPATCH\_SOURCE\_TYPE\_DATA\_ADD  | 自定义的事件，变量增加 |
| DISPATCH\_SOURCE\_TYPE\_DATA\_OR   | 自定义的事件，变量OR | 
| DISPATCH\_SOURCE\_TYPE\_MACH\_SEND | MACH端口发送 | 
| DISPATCH\_SOURCE\_TYPE\_MACH\_RECV | MACH端口接收 | 
| DISPATCH\_SOURCE\_TYPE\_PROC      | 进程监听,如进程的退出、创建一个或更多的子线程、进程收到UNIX信号 | 
| DISPATCH\_SOURCE\_TYPE\_READ      | IO操作，如对文件的操作、socket操作的读响应 | 
| DISPATCH\_SOURCE\_TYPE\_SIGNAL	    | 接收到UNIX信号时响应 | 
| DISPATCH\_SOURCE\_TYPE\_TIMER     | 定时器 | 
| DISPATCH\_SOURCE\_TYPE\_VNODE     | 文件状态监听，文件被删除、移动、重命名 | 
| DISPATCH\_SOURCE\_TYPE\_WRITE     | IO操作，如对文件的操作、socket操作的写响应 | 

自定义事件可以使用的只有`DISPATCH_SOURCE_TYPE_DATA_ADD`和`DISPATCH_SOURCE_TYPE_DATA_OR`这两种类型，我们这里也只讨论这两种类型。

#### 二、其他函数:

```
dispatch_suspend(queue) //挂起队列

dispatch_resume(source) //分派源创建时默认处于挂起状态，在分派源分派处理程序之前必须先恢复

dispatch_source_merge_data(source, 1) //向分派源发送事件，需要注意的是，不可以传递0值(事件不会被触发)，同样也不可以传递负数。

dispatch_source_set_event_handler(source, block) //设置响应分派源事件的block，在分派源指定的队列上运行

dispatch_source_get_data(source) //得到分派源的数据

```

#### 三、代码:
```
//创建source，以DISPATCH_SOURCE_TYPE_DATA_ADD的方式进行累加，而DISPATCH_SOURCE_TYPE_DATA_OR是对结果进行二进制或运算
dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, dispatch_get_main_queue());

//设置事件触发后执行的句柄
dispatch_source_set_event_handler(source,^{
    NSLog(@"监听函数：%lu",dispatch_source_get_data(source));
});

//开启source
dispatch_resume(source);

dispatch_queue_t myqueue =dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

dispatch_async(myqueue, ^ {
    
    for(int i = 1; i <= 4; i ++){
        
        NSLog(@"~~~~~~~~~~~~~~%d", i);
        
        //异步线程触发事件，向source发送事件，这里i不能为0，否则触发不了事件
        dispatch_source_merge_data(source,i);
        
        //当Interval的事件越长，则每次的句柄都会触发
        //[NSThread sleepForTimeInterval:1.0];
    }
});

```

上面的这个例子，因为for循环运算速度非常快，系统会自动把这4次事件联结起来，可以看到最终事件触发的句柄只会执行一次。打印出来的结果为:

```
~~~~~~~~~~~~~~1
~~~~~~~~~~~~~~2
~~~~~~~~~~~~~~3
~~~~~~~~~~~~~~4
监听函数：10
```

这里的10就是把每次的事件值`i`相加得到的(1+2+3+4)。这里如果把`DISPATCH_SOURCE_TYPE_DATA_ADD`替换为`DISPATCH_SOURCE_TYPE_DATA_OR`，结果会是7，也就是把每次的事件值`i`或运算得到(1|2|3|4)。

如果把`[NSThread sleepForTimeInterval:1.0]`的注释打开，因为事件间隔太长，系统不会联结，此时类似于`dispatch_async()`，打印结果如下：

```
~~~~~~~~~~~~~~1
监听函数：1
~~~~~~~~~~~~~~2
监听函数：2
~~~~~~~~~~~~~~3
监听函数：3
~~~~~~~~~~~~~~4
监听函数：4
```

此时不论type是`DISPATCH_SOURCE_TYPE_DATA_ADD`或`DISPATCH_SOURCE_TYPE_DATA_OR`，结果都是这个，因为这两种type只影响联结时的value。对非联结的情况没有影响。


#### 四、例子:
当我们更新进度条时，可能在多个线程上同时做很多任务，每个任务完成后，刷新界面，更新一点进度条的进度，因为每个任务都更新一次进度条，造成界面刷新次数太多，可能会导致界面卡顿，所以此时利用Dispatch Source能很好的解决这种情况，因为Dispatch Source在刷新太频繁的时候会自动联结起来，下面就用代码实现一下这个场景。

```
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

```

上面相等于启动了100个任务，每个任务耗时0.02秒，打印结果如下：

```
进度：0.25
进度：0.32
进度：0.37
进度：0.41
进度：0.55
进度：0.61
进度：0.63
进度：0.64
进度：0.76
进度：0.89
进度：0.96
进度：1
```