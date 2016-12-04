//
//  XHLaunchAd.m
//  XHLaunchAdExample
//
//  Created by zhuxiaohui on 2016/6/13.
//  Copyright © 2016年 CoderZhuXH. All rights reserved.
//  代码地址:https://github.com/CoderZhuXH/XHLaunchAd

#import "XHLaunchAd.h"
#import "XHLaunchAdView.h"
#import "UIImageView+XHLaunchAdCache.h"
#import "UIImage+XHLaunchAd.h"
#import "NSString+XHLaunchAd.h"
#import "XHLaunchAdDownloader.h"
#import "XHLaunchAdCache.h"
#import "XHLaunchImageView.h"

static NSInteger defaultWaitDataDuration = 3;

@interface XHLaunchAd()

@property(nonatomic,strong)XHLaunchImageView *launchImageView;
@property(nonatomic,strong)XHLaunchImageAdView *adView;
@property(nonatomic,strong)XHLaunchVideoAdView *adVideoView;
@property(nonatomic,strong)XHLaunchAdButton *adSkipButton;

@property(nonatomic,strong)UIWindow *window;

@property(nonatomic,copy)dispatch_source_t waitDataTimer;
@property(nonatomic,copy)dispatch_source_t skipTimer;

@property(nonatomic,strong)XHLaunchImageAdConfiguratuon *imageAdConfiguratuon;
@property(nonatomic,strong)XHLaunchVideoAdConfiguratuon *videoAdConfiguratuon;
@property(nonatomic,assign)NSInteger waitDataDuration;

@property(nonatomic,strong)UIImageView *cutView;

@end

@implementation XHLaunchAd

+(void)setWaitDataDuration:(NSInteger )waitDataDuration
{
    XHLaunchAd *launchAd = [XHLaunchAd shareLaunchAd];
    launchAd.waitDataDuration = waitDataDuration;
}

+(XHLaunchAd *)imageAdWithImageAdConfiguration:(XHLaunchImageAdConfiguratuon *)imageAdconfiguration
{
    return [XHLaunchAd imageAdWithImageAdConfiguration:imageAdconfiguration delegate:nil];
}

+(XHLaunchAd *)imageAdWithImageAdConfiguration:(XHLaunchImageAdConfiguratuon *)imageAdconfiguration delegate:(id)delegate;
{
    XHLaunchAd *launchAd = [XHLaunchAd shareLaunchAd];
    if(delegate) launchAd.delegate = delegate;
    launchAd.imageAdConfiguratuon = imageAdconfiguration;
    return launchAd;
}
+(XHLaunchAd *)videoAdWithVideoAdConfiguration:(XHLaunchVideoAdConfiguratuon *)videoAdconfiguration
{
    return [XHLaunchAd videoAdWithVideoAdConfiguration:videoAdconfiguration delegate:nil];
}
+(XHLaunchAd *)videoAdWithVideoAdConfiguration:(XHLaunchVideoAdConfiguratuon *)videoAdconfiguration delegate:(nullable id)delegate;
{
    XHLaunchAd *launchAd = [XHLaunchAd shareLaunchAd];
    if(delegate) launchAd.delegate = delegate;
    launchAd.videoAdConfiguratuon = videoAdconfiguration;
    return launchAd;
}
+(void)downLoadImageAndCacheWithURLArray:(NSArray <NSURL *> * )urlArray
{
    if(urlArray.count==0) return;
    [[XHLaunchAdDownloader sharedDownloader] downLoadImageAndCacheWithURLArray:urlArray];
}
+(void)downLoadVideoAndCacheWithURLArray:(NSArray <NSURL *> * )urlArray
{
    if(urlArray.count==0) return;
    [[XHLaunchAdDownloader sharedDownloader] downLoadVideoAndCacheWithURLArray:urlArray ];
}
+(void)skipAction
{
    [[XHLaunchAd shareLaunchAd] adSkipButtonClick];
}
+(void)clearDiskCache
{
    [XHLaunchAdCache clearDiskCache];
}

+(float)diskCacheSize
{
    return [XHLaunchAdCache diskCacheSize];
}
+(NSString *)xhLaunchAdCachePath
{
    return [XHLaunchAdCache xhLaunchAdCachePath];
}

#pragma mark - private
+(XHLaunchAd *)shareLaunchAd{
    
    static XHLaunchAd *instance = nil;
    static dispatch_once_t oneToken;
    dispatch_once(&oneToken,^{
        
        instance = [[XHLaunchAd alloc] init];
        
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        //应用启动, 首次开屏广告
//        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        
            [self setupLaunchAd];
            
        //}];
        //        ///进入后台
        //        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        //            //[self request];
        //        }];
        //后台启动,二次开屏广告
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            
            if(_imageAdConfiguratuon&&_imageAdConfiguratuon.showEnterForeground)
            {
                [self setupLaunchAd];
                [self setupImageAdForConfiguration:_imageAdConfiguratuon];
                return ;
            }
            if(_videoAdConfiguratuon&&_videoAdConfiguratuon.showEnterForeground)
            {
                [self setupLaunchAd];
                [self setupVideoAdForConfiguration:_videoAdConfiguratuon];
            }

        }];
    }
    return self;
}

-(void)setupLaunchAd
{
    //初始化一个Window， 做到对业务视图无干扰。
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.rootViewController = [UIViewController new];
    window.rootViewController.view.backgroundColor = [UIColor clearColor];
    window.rootViewController.view.userInteractionEnabled = NO;
    
    //设置为最顶层，防止 AlertView 等弹窗的覆盖
    window.windowLevel = UIWindowLevelStatusBar + 1;
    
    //默认为YES，当你设置为NO时，这个Window就会显示了
    window.hidden = NO;
    window.alpha = 1;
    
    //防止释放，显示完后  要手动设置为 nil
    self.window = window;
    
    //添加launchImage
    [self.window addSubview:self.launchImageView];
    
    //数据等待
    [self startWaitDataDispathTiemr];
}

//图片
-(void)setupImageAdForConfiguration:(XHLaunchImageAdConfiguratuon *)configuration
{
    [self removeSubViewsExceptLaunchAdImageView];
    
    [self.window addSubview:self.adView];
    
    //frame
    if(configuration.frame.size.width>0&&configuration.frame.size.height>0)
    {
        self.adView.frame = configuration.frame;
    }
    //填充模式
    if(configuration.contentMode)
    {
        self.adView.contentMode = configuration.contentMode;
    }
    //image 数据源
    if(configuration.imageNameOrURLString.length>0)
    {
        //image
        if(configuration.imageNameOrURLString.xh_isURLString)
        {
            //自设图片
            if ([self.delegate respondsToSelector:@selector(xhLaunchAd:launchAdImageView:URL:)]) {
                [self.delegate xhLaunchAd:self launchAdImageView:self.adView URL:[NSURL URLWithString:configuration.imageNameOrURLString]];
            }
            else
            {
                if(!configuration.imageOption) configuration.imageOption = XHLaunchAdImageDefault;
                __weak typeof(self) weakSelf = self;
                [self.adView xh_setImageWithURL:[NSURL URLWithString:configuration.imageNameOrURLString] placeholderImage:nil options:configuration.imageOption completed:^(UIImage *image,NSError *error,NSURL *url) {
                    
                    if ([weakSelf.delegate respondsToSelector:@selector(xhLaunchAd:imageDownLoadFinish:)]) {
                        [weakSelf.delegate xhLaunchAd:self imageDownLoadFinish:image];
                    }
                }];
            }
        }
        else
        {
            
            UIImage *image = [UIImage xh_imageWithName:configuration.imageNameOrURLString];
            if(image)
            {
                if ([self.delegate respondsToSelector:@selector(xhLaunchAd:imageDownLoadFinish:)]) {
                    [self.delegate xhLaunchAd:self imageDownLoadFinish:image];
                }
                self.adView.image = image;
            }
            else
            {
                NSLog(@"Error:图片未找到,或名称有误!");
            }
            
        }
        //timer
        [self startSkipDispathTimer];
        
        //skipButton
        [self addSkipButtonForConfiguration:configuration];
        
        //点击
        __weak __typeof(self) weakSelf = self;
        self.adView.adClick = ^()
        {
            [weakSelf adClickAction];
        };
        
    }
    
}

-(void)addSkipButtonForConfiguration:(XHLaunchAdConfiguratuon *)configuration
{
    if(!configuration.duration) configuration.duration = 5;
    if(!configuration.skipButtonType) configuration.skipButtonType = SkipTypeTimeText;
    
    if(configuration.customSkipView)
    {
        [self.window addSubview:configuration.customSkipView];
    }
    else
    {
        [self.window addSubview:self.adSkipButton];
        [self.adSkipButton stateWithskipType:configuration.skipButtonType andDuration:configuration.duration];
    }
}

//视频
-(void)setupVideoAdForConfiguration:(XHLaunchVideoAdConfiguratuon *)configuration
{
    [self removeSubViewsExceptLaunchAdImageView];
    
    [self.window addSubview:self.adVideoView];
    
    //frame
    if(configuration.frame.size.width>0&&configuration.frame.size.height>0)
    {
        self.adVideoView.frame = configuration.frame;
    }
    //填充模式
    if(configuration.scalingMode)
    {
        self.adVideoView.adVideoScalingMode = configuration.scalingMode;
    }
    //video 数据源
    if(configuration.videoNameOrURLString)
    {
        if(configuration.videoNameOrURLString.xh_isURLString)
        {
            NSURL *pathURL = [XHLaunchAdCache getCacheVideoWithURL:[NSURL URLWithString:configuration.videoNameOrURLString]];
            //NSURL *pathURL = [NSURL URLWithString:configuration.videoNameOrURLString];
            if(pathURL)
            {
                if ([self.delegate respondsToSelector:@selector(xhLaunchAd:videoDownLoadFinish:)]) {
                    [self.delegate xhLaunchAd:self videoDownLoadFinish:pathURL];
                }
                self.adVideoView.adVideoPlayer.contentURL = pathURL;
                [self.adVideoView.adVideoPlayer prepareToPlay];
            }
            else
            {
                
                [[XHLaunchAdDownloader sharedDownloader] downloadVideoWithURL:[NSURL URLWithString:configuration.videoNameOrURLString] progress:^(unsigned long long total, unsigned long long current) {
                    
                    if ([self.delegate respondsToSelector:@selector(xhLaunchAd:videoDownLoadProgress:total:current:)]) {
                        [self.delegate xhLaunchAd:self videoDownLoadProgress:current/(float)total total:total current:current];
                    }
                    
                }  completed:^(NSURL * _Nullable location, NSError * _Nullable error) {
                    
                    if ([self.delegate respondsToSelector:@selector(xhLaunchAd:videoDownLoadFinish:)]) {
                        [self.delegate xhLaunchAd:self videoDownLoadFinish:location];
                    }
                }];
                
#pragma mark - 视频缓存,提前显示完成
                [self remove];//完成显示
                return;
            }
        }
        else
        {
            NSString *path = [[NSBundle mainBundle]pathForResource:configuration.videoNameOrURLString ofType:nil];
            if(path)
            {
                NSURL *pathURL = [NSURL fileURLWithPath:path];
                if ([self.delegate respondsToSelector:@selector(xhLaunchAd:videoDownLoadFinish:)]) {
                    [self.delegate xhLaunchAd:self videoDownLoadFinish:pathURL];
                }
                self.adVideoView.adVideoPlayer.contentURL = pathURL;;
                [self.adVideoView.adVideoPlayer prepareToPlay];
            }
            else
            {
                NSLog(@"Error:视频文件未找到,或名称有误!");
            }
            
        }
        [self startSkipDispathTimer];
        //skipButton
        [self addSkipButtonForConfiguration:configuration];
        
        //点击
        __weak __typeof(self) weakSelf = self;
        self.adVideoView.adClick = ^()
        {
            [weakSelf adClickAction];
        };
        
    }
    
}

#pragma mark - set
-(void)setImageAdConfiguratuon:(XHLaunchImageAdConfiguratuon *)imageAdConfiguratuon
{
    _imageAdConfiguratuon = imageAdConfiguratuon;
    _videoAdConfiguratuon = nil;
    
    [self setupImageAdForConfiguration:imageAdConfiguratuon];
    
}
-(void)setVideoAdConfiguratuon:(XHLaunchVideoAdConfiguratuon *)videoAdConfiguratuon
{
    _videoAdConfiguratuon = videoAdConfiguratuon;
    _imageAdConfiguratuon = nil;
    
    [self setupVideoAdForConfiguration:videoAdConfiguratuon];
    
}

#pragma mark - 懒加载
-(XHLaunchImageView *)launchImageView
{
    if(_launchImageView==nil)
    {
        _launchImageView = [[XHLaunchImageView alloc] init];
    }
    return _launchImageView;
}
-(XHLaunchImageAdView *)adView
{
    if(_adView==nil)
    {
        _adView = [[XHLaunchImageAdView alloc] init];
    }
    return _adView;
}
-(XHLaunchVideoAdView *)adVideoView
{
    if(_adVideoView==nil)
    {
        _adVideoView = [[XHLaunchVideoAdView alloc] init];
    }
    return _adVideoView;
}
-(XHLaunchAdButton *)adSkipButton
{
    if(_adSkipButton == nil)
    {
        _adSkipButton = [[XHLaunchAdButton alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width-70,25, 70, 40)];
        _adSkipButton.hidden = YES;
        [_adSkipButton addTarget:self action:@selector(adSkipButtonClick) forControlEvents:UIControlEventTouchUpInside];
        _adSkipButton.leftRightSpace = 5;
        _adSkipButton.topBottomSpace = 5;
    }
    return _adSkipButton;
}
-(UIImageView *)cutView
{
    if(_cutView==nil)
    {
        _cutView = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _cutView.image = [self cutFromView:self.window];
        _cutView.userInteractionEnabled = YES;
    }
    return _cutView;

}
#pragma mark - Action
-(void)adSkipButtonClick
{
    [self removeAndAnimate];
}
-(void)adClickAction
{
    
    if ([self.delegate respondsToSelector:@selector(xhLaunchAd:clickAndOpenURLString:)]) {
        
        [[UIApplication sharedApplication].keyWindow.rootViewController.view addSubview:self.cutView];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [self.cutView removeFromSuperview];
        });
        
        XHLaunchAdConfiguratuon * configuratuon = [self commonConfiguratuon];
        [self.delegate xhLaunchAd:self clickAndOpenURLString:configuratuon.openURLString];
        
        [self remove];
    }
    
}

-(XHLaunchAdConfiguratuon *)commonConfiguratuon
{
    XHLaunchAdConfiguratuon *configuratuon;
    if(_videoAdConfiguratuon)
    {
        configuratuon = _videoAdConfiguratuon;
    }
    else
    {
        configuratuon = _imageAdConfiguratuon;
    }
    return configuratuon;
}
-(void)startWaitDataDispathTiemr
{
    __block NSInteger duration = defaultWaitDataDuration;
    
    if(_waitDataDuration) duration = _waitDataDuration;
    
    NSTimeInterval period = 1.0;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _waitDataTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_waitDataTimer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_waitDataTimer, ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(duration==0)
            {
                dispatch_source_cancel(_waitDataTimer);
                
                [self remove];
            }
            
            duration--;
        });
    });
    dispatch_resume(_waitDataTimer);
}
-(void)startSkipDispathTimer
{
    XHLaunchAdConfiguratuon * configuratuon = [self commonConfiguratuon];
    if(_waitDataTimer)
    {
        dispatch_source_cancel(_waitDataTimer);
        _waitDataTimer = nil;
    }
    if(!configuratuon.skipButtonType) configuratuon.skipButtonType = SkipTypeTimeText;//默认
    __block NSInteger duration = 5;//默认
    if(configuratuon.duration) duration = configuratuon.duration;
    
    NSTimeInterval period = 1.0;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _skipTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_skipTimer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_skipTimer, ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([self.delegate respondsToSelector:@selector(xhLaunchAd:customSkipView:duration:)]) {
                
                [self.delegate xhLaunchAd:self customSkipView:configuratuon.customSkipView duration:duration];
            }
            if(!configuratuon.customSkipView)
            {
                 [self.adSkipButton stateWithskipType:configuratuon.skipButtonType andDuration:duration];
            }
            if(duration==0)
            {
                dispatch_source_cancel(_skipTimer);
                
                [self removeAndAnimate];
            }
            duration--;
        });
    });
    dispatch_resume(_skipTimer);
}

-(void)removeAndAnimate{
    
    XHLaunchAdConfiguratuon * configuratuon = [self commonConfiguratuon];
    
    if(!configuratuon.showFinishAnimate) configuratuon.showFinishAnimate = ShowFinishAnimateFadein;
    
    if(configuratuon.showFinishAnimate == ShowFinishAnimateLite)
    {
        [UIView animateWithDuration:1.5 animations:^{
            
            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            self.window.transform=CGAffineTransformMakeScale(2.f, 2.f);
            self.window.alpha = 0;
            
        } completion:^(BOOL finished) {
            
            [self remove];
            
        }];
    }
    else if(configuratuon.showFinishAnimate == ShowFinishAnimateFadein)
    {
        [UIView animateWithDuration:0.3 animations:^{
            self.window.alpha = 0;
        } completion:^(BOOL finished) {
            [self remove];
        }];
    }
    else
    {
        [self remove];
    }
}
-(void)remove{
    
    if(_waitDataTimer)
    {
        dispatch_source_cancel(_waitDataTimer);
        _waitDataTimer = nil;
    }
    if(_skipTimer)
    {
        dispatch_source_cancel(_skipTimer);
        _skipTimer = nil;
    }
    [self.window.subviews.copy enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    self.window.hidden = YES;
    self.window = nil;
    
    if ([self.delegate respondsToSelector:@selector(xhLaunchShowFinish:)]) {
        
        [self.delegate xhLaunchShowFinish:self];
    }
}
-(void)removeSubViewsExceptLaunchAdImageView
{
    [self.window.subviews.copy enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if(![obj isKindOfClass:[XHLaunchImageView class]])
        {
            [obj removeFromSuperview];
        }
    }];

}
- (UIImage *)cutFromView:(UIView *)view {
    
    CGSize size = view.bounds.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGRect rect = view.frame;
    [view drawViewHierarchyInRect:rect afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end
