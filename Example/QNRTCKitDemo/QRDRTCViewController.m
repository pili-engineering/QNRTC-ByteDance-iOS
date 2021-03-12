//
//  QRDRTCViewController.m
//  QNRTCKitDemo
//
//  Created by 冯文秀 on 2018/1/18.
//  Copyright © 2018年 PILI. All rights reserved.
//

#import "QRDRTCViewController.h"
#import <ReplayKit/ReplayKit.h>
#import "UIView+Alert.h"
#import <QNRTCKit/QNRTCKit.h>

#import "BEModernStickerPickerView.h"
#import "BEModernEffectPickerView.h"
#import "BETextSliderView.h"

@interface QRDRTCViewController ()

@property (nonatomic, strong) BEModernStickerPickerView *stickerListView;
@property (nonatomic, strong) BEModernEffectPickerView *effectListView;
@property (nonatomic, strong) PLSEffectDataManager *effectDataManager;
@property (nonatomic, strong) PLSEffectManager *effectManager;

@end

@implementation QRDRTCViewController

- (void)dealloc {
    NSLog(@"[dealloc]==> %@", self.description);
    [PLSEffectManager releaseManager];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = QRD_COLOR_RGBA(20, 20, 20, 1);
    
    self.videoEncodeSize = CGSizeFromString(_configDic[@"VideoSize"]);
    self.bitrate = [_configDic[@"Bitrate"] integerValue];
    [self setupEngine];
    
    [self setupBottomButtons];
    [self requestToken];
    
    if (self.needEffect) {
        [self setupEffect];
    }
    
    self.logButton = [[UIButton alloc] init];
    [self.logButton setImage:[UIImage imageNamed:@"log-btn"] forState:UIControlStateNormal];
    [self.logButton addTarget:self action:@selector(logAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.logButton];
    [self.view bringSubviewToFront:self.tableView];
    
    [self.logButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(0);
        make.top.equalTo(self.mas_topLayoutGuide);
        make.size.equalTo(CGSizeMake(50, 50));
    }];
    
    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.logButton);
        make.top.equalTo(self.logButton.mas_bottom);
        make.width.height.equalTo(self.view).multipliedBy(0.6);
    }];
    self.tableView.hidden = YES;
}

- (void)conferenceAction:(UIButton *)conferenceButton {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.effectListView updateSelectedEffect];
    [_effectManager updateSticker: self.stickerListView.selectedSticker];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stoptimer];
    [self.engine leaveRoom];
    
    [super viewDidDisappear:animated];
}

- (void)setTitle:(NSString *)title {
    if (nil == self.titleLabel) {
        self.titleLabel = [[UILabel alloc] init];
        if (@available(iOS 9.0, *)) {
            self.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:(UIFontWeightRegular)];
        } else {
            self.titleLabel.font = [UIFont systemFontOfSize:14];
        }
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.textColor = [UIColor whiteColor];
        [self.view addSubview:self.titleLabel];
    }
    self.titleLabel.text = title;
    [self.titleLabel sizeToFit];
    self.titleLabel.center = CGPointMake(self.view.center.x, self.logButton.center.y);
    [self.view bringSubviewToFront:self.titleLabel];
}

- (BEModernStickerPickerView *)stickerListView {
    if (!_stickerListView) {
        CGRect frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 200);
        _stickerListView = [[BEModernStickerPickerView alloc] initWithFrame:frame];
        _stickerListView.layer.backgroundColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:0.8].CGColor;
        _stickerListView.delegate = self;
        PLSEffectModel *clear = [[PLSEffectModel alloc] init];
        clear.displayName = @"无";
        clear.iconImage = [UIImage imageNamed:@"iconCloseButtonNormal"];
        NSMutableArray *stickers = [[NSMutableArray alloc] initWithObjects:clear, nil];
        [stickers addObjectsFromArray:[_effectDataManager fetchEffectListWithType:PLSEffectTypeSticker]];
        [_stickerListView refreshWithStickers:stickers];
    }
    return _stickerListView;
}

- (BEModernEffectPickerView *)effectListView {
    if (!_effectListView) {
        _effectListView = [[BEModernEffectPickerView alloc] initWithFrame:(CGRect)CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 220)];
    }
    return _effectListView;
}

- (void)joinRTCRoom {
    [self.view showNormalLoadingWithTip:@"加入房间中..."];
    [self.engine joinRoomWithToken:self.token];
}

- (void)requestToken {
    [self.view showFullLoadingWithTip:@"请求 token..."];
    __weak typeof(self) wself = self;
    [QRDNetworkUtil requestTokenWithRoomName:self.roomName appId:self.appId userId:self.userId completionHandler:^(NSError *error, NSString *token) {
        
        [wself.view hideFullLoading];
        
        if (error) {
            [wself addLogString:error.description];
            [wself.view showFailTip:error.description];
            wself.title = @"请求 token 出错，请检查网络";
        } else {
            NSString *str = [NSString stringWithFormat:@"获取到 token: %@", token];
            [wself addLogString:str];
            
            wself.token = token;
            [wself joinRTCRoom];
        }
    }];
}

- (void)setupEngine {
    
    self.engine = [[QNRTCEngine alloc] init];
    self.engine.delegate = self;
    self.engine.videoFrameRate = [_configDic[@"FrameRate"] integerValue];;
    self.engine.statisticInterval = 5;
    [self.engine setBeautifyModeOn:YES];
    
    [self.colorView addSubview:self.engine.previewView];
    [self.renderBackgroundView addSubview:self.colorView];
    
    [self.engine.previewView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.colorView);
    }];
    
    [self.colorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.renderBackgroundView);
    }];
    
    [self.engine startCapture];
}

- (void)setupEffect {
    // PLSEffect
    NSString *rootPath = [[NSBundle mainBundle] resourcePath];
    PLSEffectConfiguration *effectConfiguration = [PLSEffectConfiguration new];
    effectConfiguration.modelFileDirPath = [NSString pathWithComponents:@[rootPath, @"ModelResource.bundle"]];
    effectConfiguration.licenseFilePath = [NSString pathWithComponents:@[rootPath, @"LicenseBag.bundle", @"qiniu_20210310_20220331_com.qbox.QNRTCKitDemo.bytedance_v3.9.0.licbag"]];
    _effectDataManager = [[PLSEffectDataManager alloc] initWithRootPath:rootPath];
    
    self.effectManager = [PLSEffectManager sharedWith:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] configuration:effectConfiguration];
    self.effectListView.effectManager = self.effectManager;
    
    self.effectListView.dataManager = _effectDataManager;
    [self.effectListView loadData];
    
    self.effectButton = [[UIButton alloc] init];
    [self.effectButton setImage:[UIImage imageNamed:@"effect-open"] forState:(UIControlStateSelected)];
    [self.effectButton setBackgroundColor:QRD_COLOR_RGBA(0,0,0,0.3)];
    [self.effectButton setImageEdgeInsets:UIEdgeInsetsMake(8, 8, 8, 8)];
    [self.effectButton setImage:[UIImage imageNamed:@"effect-close"] forState:(UIControlStateNormal)];
    self.effectButton.layer.cornerRadius = 20;
    self.effectButton.clipsToBounds = YES;
    [self.effectButton addTarget:self action:@selector(effectButtonDidClick:) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:_effectButton];
    [self.effectButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.view).offset(-12);
        make.size.equalTo(CGSizeMake(40, 40));
        make.top.mas_equalTo(self.view.centerY);
    }];
    
    self.stickerButton = [[UIButton alloc] init];
    [self.stickerButton setImage:[UIImage imageNamed:@"sticker-open"] forState:(UIControlStateSelected)];
    [self.stickerButton setBackgroundColor:QRD_COLOR_RGBA(0,0,0,0.3)];
    [self.stickerButton setImageEdgeInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    [self.stickerButton setImage:[UIImage imageNamed:@"sticker-close"] forState:(UIControlStateNormal)];
    self.stickerButton.layer.cornerRadius = 20;
    self.stickerButton.clipsToBounds = YES;
    [self.stickerButton addTarget:self action:@selector(stickerButtonDidClick:) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:_stickerButton];
    [self.stickerButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.view).offset(-12);
        make.size.equalTo(CGSizeMake(40, 40));
        make.top.mas_equalTo(self.effectButton).offset(60);
    }];
}

- (void)setupBottomButtons {
    
    self.bottomButtonView = [[UIView alloc] init];
    [self.view addSubview:self.bottomButtonView];
    
    UIButton* buttons[6];
    NSString *selectedImage[] = {
        @"microphone",
        @"loudspeaker",
        @"video-open",
        @"face-beauty-open",
        @"close-phone",
        @"camera-switch-front",
    };
    NSString *normalImage[] = {
        @"microphone-disable",
        @"loudspeaker-disable",
        @"video-close",
        @"face-beauty-close",
        @"close-phone",
        @"camera-switch-end",
    };
    SEL selectors[] = {
        @selector(microphoneAction:),
        @selector(loudspeakerAction:),
        @selector(videoAction:),
        @selector(beautyButtonClick:),
        @selector(conferenceAction:),
        @selector(toggleButtonClick:)
    };
    
    UIView *preView = nil;
    for (int i = 0; i < ARRAY_SIZE(normalImage); i ++) {
        buttons[i] = [[UIButton alloc] init];
        [buttons[i] setImage:[UIImage imageNamed:selectedImage[i]] forState:(UIControlStateSelected)];
        [buttons[i] setImage:[UIImage imageNamed:normalImage[i]] forState:(UIControlStateNormal)];
        [buttons[i] addTarget:self action:selectors[i] forControlEvents:(UIControlEventTouchUpInside)];
        [self.bottomButtonView addSubview:buttons[i]];
    }
    int index = 0;
    _microphoneButton = buttons[index ++];
    _speakerButton = buttons[index ++];
    _speakerButton.selected = YES;
    _videoButton = buttons[index ++];
    _beautyButton = buttons[index ++];
    _conferenceButton = buttons[index ++];
    _togCameraButton = buttons[index ++];
    _beautyButton.selected = YES;//默认打开美颜
    
    CGFloat buttonWidth = 54;
    NSInteger space = (UIScreen.mainScreen.bounds.size.width - buttonWidth * 3)/4;
    
    NSArray *array = [NSArray arrayWithObjects:&buttons[3] count:3];
    [array mas_distributeViewsAlongAxis:(MASAxisTypeHorizontal) withFixedItemLength:buttonWidth leadSpacing:space tailSpacing:space];
    [array mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(buttonWidth);
        make.bottom.equalTo(self.bottomButtonView).offset(-space * 0.8);
    }];
    
    preView = buttons[3];
    array = [NSArray arrayWithObjects:buttons count:3];
    [array mas_distributeViewsAlongAxis:(MASAxisTypeHorizontal) withFixedItemLength:buttonWidth leadSpacing:space tailSpacing:space];
    [array mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(buttonWidth);
        make.bottom.equalTo(preView.mas_top).offset(-space * 0.8);
    }];
    
    preView = buttons[0];
    [self.bottomButtonView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.mas_bottomLayoutGuide);
        make.top.equalTo(preView.mas_top);
    }];
}

#pragma mark - effect picker delegate

- (void)stickerPicker:(BEModernStickerPickerView *)pickerView didSelectSticker:(PLSEffectModel *)sticker {
    [self.effectManager updateSticker:sticker];
}

#pragma mark - 连麦时长计算

- (void)startTimer {
    [self stoptimer];
    self.durationTimer = [NSTimer timerWithTimeInterval:1
                                                 target:self
                                               selector:@selector(timerAction)
                                               userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.durationTimer forMode:NSRunLoopCommonModes];
}

- (void)timerAction {
    self.duration ++;
    NSString *str = [NSString stringWithFormat:@"%02ld:%02ld", self.duration / 60, self.duration % 60];
    self.title = str;
}

- (void)stoptimer {
    if (self.durationTimer) {
        [self.durationTimer invalidate];
        self.durationTimer = nil;
    }
}

- (void)beautyButtonClick:(UIButton *)beautyButton {
    beautyButton.selected = !beautyButton.selected;
    [self.engine setBeautifyModeOn:beautyButton.selected];
}

- (void)toggleButtonClick:(UIButton *)button {
    [self.engine toggleCamera];
}

- (void)microphoneAction:(UIButton *)microphoneButton {
    self.microphoneButton.selected = !self.microphoneButton.isSelected;
    [self.engine muteAudio:!self.microphoneButton.isSelected];
}

- (void)loudspeakerAction:(UIButton *)loudspeakerButton {
    self.engine.muteSpeaker = !self.engine.isMuteSpeaker;
    loudspeakerButton.selected = !self.engine.isMuteSpeaker;
}

- (void)videoAction:(UIButton *)videoButton {
    videoButton.selected = !videoButton.isSelected;
    NSMutableArray *videoTracks = [[NSMutableArray alloc] init];
    if (self.screenTrackInfo) {
        self.screenTrackInfo.muted = !videoButton.isSelected;
        [videoTracks addObject:self.screenTrackInfo];
    }
    if (self.cameraTrackInfo) {
        [videoTracks addObject:self.cameraTrackInfo];
        self.cameraTrackInfo.muted = !videoButton.isSelected;
    }
    [self.engine muteTracks:videoTracks];
    
    self.engine.previewView.hidden = !videoButton.isSelected;
    [self checkSelfPreviewGesture];
}

- (void)logAction:(UIButton *)button {
    button.selected = !button.isSelected;
    if (button.selected) {
         if (self.tableView.numberOfSections) {
            NSInteger count = [self.tableView numberOfRowsInSection:0];
            if (count != self.logStringArray.count) {
                [self.tableView reloadData];
            }
         }
    }
    self.tableView.hidden = !button.selected;
}

- (void)effectButtonDidClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self showEffectView];
    } else {
        [self hideEffectView];
    }
}

- (void)stickerButtonDidClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self showStickerView];
    } else {
        [self hideStickerView];
    }
}

- (void)showEffectView {
    if (self.stickerButton.selected) {
        self.stickerButton.selected = NO;
        [self.stickerButton setBackgroundColor:QRD_COLOR_RGBA(0,0,0,0.3)];
        [UIView animateWithDuration:0.25 animations:^{
            self.stickerListView.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 220);
        } completion:^(BOOL finished) {
            [self.stickerListView removeFromSuperview];
        }];
    }
    [self.view insertSubview:self.effectListView aboveSubview:self.view.subviews.lastObject];
    [self.effectButton setBackgroundColor:[UIColor whiteColor]];
    [UIView animateWithDuration:0.25 animations:^{
        self.effectListView.frame = CGRectMake(0, self.view.frame.size.height - 200, self.view.frame.size.width, 200);
    } completion:nil];
}

- (void)hideEffectView {
    self.effectButton.selected = NO;
    [self.effectButton setBackgroundColor:QRD_COLOR_RGBA(0,0,0,0.3)];
    [UIView animateWithDuration:0.25 animations:^{
        self.effectListView.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 200);
    } completion:^(BOOL finished) {
        [self.effectListView removeFromSuperview];
    }];
}

- (void)showStickerView {
    if (self.effectButton.selected) {
        self.effectButton.selected = NO;
        [self.effectButton setBackgroundColor:QRD_COLOR_RGBA(0,0,0,0.3)];
        [UIView animateWithDuration:0.25 animations:^{
            self.effectListView.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 200);
        } completion:^(BOOL finished) {
            [self.effectListView removeFromSuperview];
        }];
    }
    [self.view insertSubview:self.stickerListView aboveSubview:self.view.subviews.lastObject];
    [self.stickerButton setBackgroundColor:[UIColor whiteColor]];
    [UIView animateWithDuration:0.25 animations:^{
        self.stickerListView.frame = CGRectMake(0, self.view.frame.size.height - 220, self.view.frame.size.width, 220);
    } completion:nil];
}

- (void)hideStickerView {
    self.stickerButton.selected = NO;
    [self.stickerButton setBackgroundColor:QRD_COLOR_RGBA(0,0,0,0.3)];
    [UIView animateWithDuration:0.25 animations:^{
        self.stickerListView.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 220);
    } completion:^(BOOL finished) {
        [self.stickerListView removeFromSuperview];
    }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UITouch * touch in touches) {
            if (![touch.view isEqual:self.effectListView] &&
                ![touch.view isEqual:self.stickerListView] &&
                ![touch.view.class isEqual:[BETextSliderView class]]) {
                [self hideEffectView];
                [self hideStickerView];
            }
        }
        
    });
}

- (void)publish {
    
    QNTrackInfo *audioTrack = [[QNTrackInfo alloc] initWithSourceType:QNRTCSourceTypeAudio master:YES];
    QNTrackInfo *cameraTrack =  [[QNTrackInfo alloc] initWithSourceType:(QNRTCSourceTypeCamera)
                                                                    tag:cameraTag
                                                                 master:YES
                                                             bitrateBps:self.bitrate
                                                        videoEncodeSize:self.videoEncodeSize];
    
    [self.engine publishTracks:@[audioTrack, cameraTrack]];
}

- (void)showAlertWithMessage:(NSString *)message completionHandler:(void (^)(void))handler
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"错误" message:message preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (handler) {
            handler();
        }
    }]];
    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark - QNRTCEngineDelegate

/**
 * SDK 运行过程中发生错误会通过该方法回调，具体错误码的含义可以见 QNTypeDefines.h 文件
 */
- (void)RTCEngine:(QNRTCEngine *)engine didFailWithError:(NSError *)error {
    [super RTCEngine:engine didFailWithError:error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view hiddenLoading];

        NSString *errorMessage = error.localizedDescription;
        if (error.code == QNRTCErrorReconnectTokenError) {
            errorMessage = @"重新进入房间超时";
        }
        [self showAlertWithMessage:errorMessage completionHandler:^{
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
    });
}

/**
 * 房间状态变更的回调。当状态变为 QNRoomStateReconnecting 时，SDK 会为您自动重连，如果希望退出，直接调用 leaveRoom 即可
 */
- (void)RTCEngine:(QNRTCEngine *)engine roomStateDidChange:(QNRoomState)roomState {
    [super RTCEngine:engine roomStateDidChange:roomState];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view hiddenLoading];
        
        if (QNRoomStateConnected == roomState || QNRoomStateReconnected == roomState) {
            [self startTimer];
        } else {
            [self stoptimer];
        }
        
        if (QNRoomStateConnected == roomState) {
            [self.view showSuccessTip:@"加入房间成功"];
            self.videoButton.selected = YES;
            self.microphoneButton.selected = YES;
            [self publish];
        } else if (QNRoomStateIdle == roomState) {
            self.videoButton.enabled = NO;
            self.videoButton.selected = NO;
        } else if (QNRoomStateReconnecting == roomState) {
            [self.view showNormalLoadingWithTip:@"正在重连..."];
            self.title = @"正在重连...";
            self.videoButton.enabled = NO;
            self.microphoneButton.enabled = NO;
        } else if (QNRoomStateReconnected == roomState) {
            [self.view showSuccessTip:@"重新加入房间成功"];
            self.videoButton.enabled = YES;
            self.microphoneButton.enabled = YES;
        }
    });
}

- (void)RTCEngine:(QNRTCEngine *)engine didPublishLocalTracks:(NSArray<QNTrackInfo *> *)tracks {
    [super RTCEngine:engine didPublishLocalTracks:tracks];
    
    dispatch_main_async_safe(^{
        [self.view hiddenLoading];
        [self.view showSuccessTip:@"发布成功了"];
        
        for (QNTrackInfo *trackInfo in tracks) {
            if (trackInfo.kind == QNTrackKindAudio) {
                self.microphoneButton.enabled = YES;
                self.isAudioPublished = YES;
                self.audioTrackInfo = trackInfo;
                continue;
            }
            if (trackInfo.kind == QNTrackKindVideo) {
                if ([trackInfo.tag isEqualToString:screenTag]) {
                    self.screenTrackInfo = trackInfo;
                    self.isScreenPublished = YES;
                } else {
                    self.videoButton.enabled = YES;
                    self.isVideoPublished = YES;
                    self.cameraTrackInfo = trackInfo;
                }
                continue;
            }
        }
    });
}

/**
 * 远端用户取消发布音/视频的回调
 */
- (void)RTCEngine:(QNRTCEngine *)engine didUnPublishTracks:(NSArray<QNTrackInfo *> *)tracks ofRemoteUserId:(NSString *)userId {
    [super RTCEngine:engine didUnPublishTracks:tracks ofRemoteUserId:userId];
    
    dispatch_main_async_safe(^{
        for (QNTrackInfo *trackInfo in tracks) {
            QRDUserView *userView = [self userViewWithUserId:userId];
            QNTrackInfo *tempInfo = [userView trackInfoWithTrackId:trackInfo.trackId];
            if (tempInfo) {
                [userView.traks removeObject:tempInfo];
                
                if (trackInfo.kind == QNTrackKindVideo) {
                    if ([trackInfo.tag isEqualToString:screenTag]) {
                        [userView hideScreenView];
                    } else {
                        [userView hideCameraView];
                    }
                } else {
                    [userView setMuteViewHidden:YES];
                }
                
                if (0 == userView.traks.count) {
                    [self removeRenderViewFromSuperView:userView];
                }
            }
        }
    });
}

/**
 * 被 userId 踢出的回调
 */
- (void)RTCEngine:(QNRTCEngine *)engine didKickoutByUserId:(NSString *)userId {
    //    [super RTCSession:session didKickoutByUserId:userId];
    
    NSString *str = [NSString stringWithFormat:@"你被用户 %@ 踢出房间", userId];
    
    dispatch_main_async_safe(^{
        [self.view showTip:str];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.presentingViewController) {
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        });
    });
}

- (void)RTCEngine:(QNRTCEngine *)engine didSubscribeTracks:(NSArray<QNTrackInfo *> *)tracks ofRemoteUserId:(NSString *)userId {
    [super RTCEngine:engine didSubscribeTracks:tracks ofRemoteUserId:userId];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        for (QNTrackInfo *trackInfo in tracks) {
            QRDUserView *userView = [self userViewWithUserId:userId];
            if (!userView) {
                userView = [self createUserViewWithTrackId:trackInfo.trackId userId:userId];
                [self.userViewArray addObject:userView];
                NSLog(@"createRenderViewWithTrackId: %@", trackInfo.trackId);
            }
            if (nil == userView.superview) {
                [self addRenderViewToSuperView:userView];
            }
            
            QNTrackInfo *tempInfo = [userView trackInfoWithTrackId:trackInfo.trackId];
            if (tempInfo) {
                [userView.traks removeObject:tempInfo];
            }
            [userView.traks addObject:trackInfo];
            
            if (trackInfo.kind == QNTrackKindVideo) {
                if ([trackInfo.tag isEqualToString:screenTag]) {
                    if (trackInfo.muted) {
                        [userView hideScreenView];
                    } else {
                        [userView showScreenView];
                    }
                } else {
                    if (trackInfo.muted) {
                        [userView hideCameraView];
                    } else {
                        [userView showCameraView];
                    }
                }
            } else if (trackInfo.kind == QNTrackKindAudio) {
                [userView setMuteViewHidden:NO];
                [userView setAudioMute:trackInfo.muted];
            }
        }
    });
}

/**
 * 远端用户视频首帧解码后的回调，如果需要渲染，则需要返回一个带 renderView 的 QNVideoRender 对象
 */
- (QNVideoRender *)RTCEngine:(QNRTCEngine *)engine firstVideoDidDecodeOfTrackId:(NSString *)trackId remoteUserId:(NSString *)userId {
    [super RTCEngine:engine firstVideoDidDecodeOfTrackId:trackId remoteUserId:userId];
    
    QRDUserView *userView = [self userViewWithUserId:userId];
    if (!userView) {
        [self.view showFailTip:@"逻辑错误了 firstVideoDidDecodeOfRemoteUserId 中没有获取到 VideoView"];
    }
    
    userView.contentMode = UIViewContentModeScaleAspectFit;
    QNVideoRender *render = [[QNVideoRender alloc] init];
    
    QNTrackInfo *trackInfo = [userView trackInfoWithTrackId:trackId];
    render.renderView =   [trackInfo.tag isEqualToString:screenTag] ? userView.screenView : userView.cameraView;
    return render;
}

/**
 * 远端用户视频取消渲染到 renderView 上的回调
 */
- (void)RTCEngine:(QNRTCEngine *)engine didDetachRenderView:(UIView *)renderView ofTrackId:(NSString *)trackId remoteUserId:(NSString *)userId {
    [super RTCEngine:engine didDetachRenderView:renderView ofTrackId:trackId remoteUserId:userId];
    
    QRDUserView *userView = [self userViewWithUserId:userId];
    if (userView) {
        QNTrackInfo *trackInfo = [userView trackInfoWithTrackId:trackId];
        if ([trackInfo.tag isEqualToString:screenTag]) {
            [userView hideScreenView];
        } else {
            [userView hideCameraView];
        }
        //        [self removeRenderViewFromSuperView:userView];
    }
}

/**
 * 远端用户音频状态变更为 muted 的回调
 */
- (void)RTCEngine:(QNRTCEngine *)engine didAudioMuted:(BOOL)muted ofTrackId:(NSString *)trackId byRemoteUserId:(NSString *)userId {
    [super RTCEngine:engine didAudioMuted:muted ofTrackId:trackId byRemoteUserId:userId];
    
    QRDUserView *userView = [self userViewWithUserId:userId];
    [userView setAudioMute:muted];
}

/**
 * 远端用户视频状态变更为 muted 的回调
 */
- (void)RTCEngine:(QNRTCEngine *)engine didVideoMuted:(BOOL)muted ofTrackId:(NSString *)trackId byRemoteUserId:(NSString *)userId {
    [super RTCEngine:engine didVideoMuted:muted ofTrackId:trackId byRemoteUserId:userId];
    
    QRDUserView *userView = [self userViewWithUserId:userId];
    QNTrackInfo *trackInfo = [userView trackInfoWithTrackId:trackId];
    if ([trackInfo.tag isEqualToString:screenTag]) {
        if (muted) {
            [userView hideScreenView];
        } else {
            [userView showScreenView];
        }
    } else {
        if (muted) {
            [userView hideCameraView];
        } else {
            [userView showCameraView];
        }
    }
}

/*
* 特效
*/
- (void)RTCEngine:(QNRTCEngine *)engine cameraSourceDidGetSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [super RTCEngine:engine cameraSourceDidGetSampleBuffer:sampleBuffer];
    
    if (self.effectManager) {
        // CMSampleBufferRef 转 CVPixelBufferRef 并获取 CMSampleTimingInfo
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CMSampleTimingInfo timingInfo;
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo);
                  
        double timestamp = timingInfo.presentationTimeStamp.value/timingInfo.presentationTimeStamp.timescale;
        [self.effectManager processBuffer:pixelBuffer withTimestamp:timestamp videoOrientation:self.engine.videoOrientation deviceOrientation:self.engine.videoOrientation];
    }
}
@end
