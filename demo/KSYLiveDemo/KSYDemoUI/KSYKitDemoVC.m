//
//  KSYKitDemoVC.m
//  KSYGPUStreamerDemo
//
//  Created by yiqian on 6/23/16.
//  Copyright © 2016 ksyun. All rights reserved.
//

#import "KSYKitDemoVC.h"
#import <libksygpulive/libksygpulive.h>
#import <libksygpulive/libksygpuimage.h>


@interface KSYKitDemoVC () {
    id _filterBtn;
    UILabel* label;
    NSDateFormatter * _dateFormatter;
    int64_t _seconds;
}

@end

@implementation KSYKitDemoVC


#pragma mark - UIViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    _kit = [[KSYGPUStreamerKit alloc] initWithDefaultCfg];
    // 获取streamerBase, 方便进行推流相关操作, 也可以直接 _kit.streamerBase.xxx
    self.streamerBase = _kit.streamerBase;
    // 采集相关设置初始化
    [self setCaptureCfg];
    //推流相关设置初始化
    [self setStreamerCfg];
    
    // 获取背景音乐播放器
    self.bgmPlayer = _kit.bgmPlayer;

    // 打印版本号信息
    NSLog(@"version: %@", [_kit getKSYVersion]);
    [self setupLogo];
    
    //addObserver
    NSNotificationCenter *notiftication = [NSNotificationCenter defaultCenter];
    [notiftication addObserver:self
                      selector:@selector(willResignned:)
                          name:UIApplicationWillResignActiveNotification
                        object:nil];
    [notiftication addObserver:self
                      selector:@selector(becameActive:)
                          name:UIApplicationDidBecomeActiveNotification
                        object:nil];
}
//app will resigned
- (void)willResignned:(NSNotification *)not{
    [_kit.capDev removeAllTargets];
}
//app becameAction
- (void) becameActive:(NSNotification *)not{
    [_kit setupFilter:self.ksyFilterView.curFilter];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.ctrlView.btnQuit setTitle: @"退出kit"
                           forState: UIControlStateNormal];
    if (_kit) {
        // init with default filter
        [_kit setupFilter:self.ksyFilterView.curFilter];
        [_kit startPreview:self.view];
    }
}
//remove notification
- (void)viewDidDisappear:(BOOL)animated{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void) setCaptureCfg {
    _kit.videoDimension = [self.presetCfgView capResolution];
    KSYVideoDimension strDim = [self.presetCfgView strResolution];
    if(_kit.videoDimension != strDim){
        _kit.bCustomStreamDimension = YES;
        _kit.streamDimension = [self.presetCfgView strResolutionSize ];
    }
    _kit.videoFPS       = [self.presetCfgView frameRate];
    _kit.cameraPosition = [self.presetCfgView cameraPos];
    _kit.bInterruptOtherAudio = NO;
    _kit.bDefaultToSpeaker    = YES; // 没有耳机的话音乐播放从扬声器播放
    _kit.videoProcessingCallback = ^(CMSampleBufferRef buf){
    };
}
- (void) setupLogo{
    NSString *logoFile=[NSHomeDirectory() stringByAppendingString:@"/Documents/ksvc.png"];
    UIImage *logoImg=[[UIImage alloc]initWithContentsOfFile:logoFile];
    CGRect rect = CGRectMake(10, 10, 80, 80);
    [_kit addLogo:logoImg toRect:rect trans:0.5];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(0,100, 500, 100)];
    label.textColor = [UIColor whiteColor];
    //label.font = [UIFont systemFontOfSize:17.0]; // 非等宽字体, 可能导致闪烁
    label.font = [UIFont fontWithName:@"Courier-Bold" size:20.0];
    label.backgroundColor = [UIColor clearColor];
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateFormat = @"MM-dd HH:mm:ss";
    NSDate *now = [[NSDate alloc] init];
    label.text = [_dateFormatter stringFromDate:now];
    rect.origin.y += (rect.size.height+5);
    [_kit addTextLabel:label toPos:rect.origin];
}

#pragma mark -  state change
- (void)onTimer:(NSTimer *)theTimer{
    [super onTimer:theTimer];
    _seconds++;
    UIApplicationState appState = [UIApplication sharedApplication].applicationState;
    if (_seconds%5 == 0 && // update label every 5 second
        appState == UIApplicationStateActive){
        NSDate *now = [[NSDate alloc] init];
        label.text = [_dateFormatter stringFromDate:now];
        [_kit updateTextLable:label];
    }
}

- (void) onCaptureStateChange:(NSNotification *)notification{
    NSLog(@"new capStat: %@", _kit.getCurCaptureStateName );
    self.ctrlView.lblStat.text = [_kit getCurCaptureStateName];
    if (_kit.captureState == KSYCaptureStateCapturing){
        self.capDev = _kit.capDev;
    }
    else {
        self.capDev = nil;
    }
}

- (void) onPipPlayerNotify:(NSNotification *)notification{
    if (MPMediaPlaybackIsPreparedToPlayDidChangeNotification == notification.name) {
        [_kit.player play]; // 准备好后开始播放
    }
    if (MPMoviePlayerPlaybackDidFinishNotification == notification.name) {
        [_kit.player stop]; // 播放完成
    }
}

- (void) onFlash {
    [_kit toggleTorch];
}

- (void) onCameraToggle{
    [_kit switchCamera];
    [super onCameraToggle];
}

- (void) onCapture{
    if (!_kit.capDev.isRunning){
        [_kit startPreview:self.view];
    }
    else {
        [_kit stopPreview];
        [_kit.audioCapDev stopCapture];
    }
}
- (void) updateStreamCfg: (BOOL) bStart {
    _kit.streamerBase.liveScene       =  self.miscView.liveScene;
    _kit.streamerBase.videoEncodePerf =  self.miscView.vEncPerf;
    _kit.streamerBase.bWithVideo = !self.miscView.swAudioOnly.on;
    _seconds = 0;
    if (bStart){
        self.streamerBase = _kit.streamerBase;
    }
    else{
        self.streamerBase = nil;
    }
    self.miscView.liveSceneSeg.enabled = !bStart;
    self.miscView.vEncPerfSeg.enabled = !bStart;
}
- (void) onStream{
    
    if (_kit.streamerBase.streamState == KSYStreamStateIdle ||
        _kit.streamerBase.streamState == KSYStreamStateError) {
        [self updateStreamCfg:YES];
        [_kit.streamerBase startStream:self.hostURL];
    }
    else {
        [self updateStreamCfg:NO];
        [_kit.streamerBase stopStream];
    }
}


- (void) onQuit{  // quit current demo
    [_kit.streamerBase stopStream];
    self.streamerBase = nil;
    if (_kit.player){
        [self onPipStop];
    }
    [_kit stopPreview];
    [super onQuit];
}

- (void) onFilterChange:(id)sender{
    if (self.ksyFilterView.curFilter != _kit.filter){
        // use a new filter
        [_kit setupFilter:self.ksyFilterView.curFilter];
    }
}

- (void) onFilterBtn:(id)sender{
    NSLog(@"onFilterBtn");
}

- (void) onFilterSwitch:(id)sender{ // see kit or block
    UISwitch* sw = sender;
    if (sw == self.ksyFilterView.swPrevewFlip){
        [_kit setPreviewMirrored:sw.on];
    }
    else if (sw == self.ksyFilterView.swStreamFlip){
        [_kit setStreamerMirrored:sw.on];
    }
}
// volume change
- (void)onAMixerSlider:(KSYNameSlider *)slider {
    float val = 0.0;
    if ([slider isKindOfClass:[KSYNameSlider class]]) {
        val = slider.normalValue;
    }
    else {
        return;
    }
    if ( slider == self.audioMixerView.bgmVol){
        [_kit.audioMixer setMixVolume:val of: _kit.bgmTrack];
    }
    else if ( slider == self.audioMixerView.micVol){
        [_kit.audioMixer setMixVolume:val of: _kit.micTrack];
    }
    else if ( slider == self.audioMixerView.pipVol){
        [_kit.audioMixer setMixVolume:val of: _kit.pipTrack];
    }
}

#pragma mark - reverb action
- (void)onReverbType:(UISegmentedControl *)seg{
    if (seg != self.reverbView.reverbType){
        return;
    }
    int t = (int)self.reverbView.reverbType.selectedSegmentIndex;
    _kit.audioCapDev.reverbType = t;
}

#pragma mark - pip ctrl
// pip start
- (void)onPipPlay{
    [_kit startPipWithPlayerUrl:self.ksyPipView.pipURL
                          bgPic:self.ksyPipView.bgpURL
                        capRect:CGRectMake(0.6, 0.6, 0.3, 0.3)];

}
- (void)onPipStop{
    [_kit stopPip];
}
- (void)onPipNext{
    if (_kit.player){
        [_kit stopPip];
        [self onPipPlay];
    }
}

- (void)onPipPause{
    if (_kit.player && _kit.player.playbackState == MPMoviePlaybackStatePlaying) {
        [_kit.player pause];
    }
    else if (_kit.player && _kit.player.playbackState == MPMoviePlaybackStatePaused){
        [_kit.player play];
    }
}

- (void)onBgpNext{
    if ( _kit.player ){
        [_kit startPipWithPlayerUrl:nil
                              bgPic:self.ksyPipView.bgpURL
                            capRect:CGRectMake(0.6, 0.6, 0.3, 0.3)];
    }
}

- (void)pipVolChange:(id)sender{
    if (_kit.player && sender == self.ksyPipView.volumSl) {
        float vol = self.ksyPipView.volumSl.normalValue;
        [_kit.player setVolume:vol rigthVolume:vol];
    }
}

#pragma mark - AUAudioCapture
// 是否开启音频采集、耳返
- (void)onMiscSwitch:(UISwitch *)sw{
    if (sw == self.miscView.swPlayCapture){
        if ( ![KSYAUAudioCapture isHeadsetPluggedIn] ) {
            [self toast:@"没有耳机, 开启耳返会有刺耳的声音"];
            sw.on = NO;
            return;
        }
        _kit.audioCapDev.bPlayCapturedAudio = sw.isOn;
    }
    
    [super onMiscSwitch:sw];
}

// 调节耳返音量
- (void)onMiscSlider:(KSYNameSlider *)slider {
    if (slider == self.miscView.micmVol){
        if (_kit.audioCapDev){
            _kit.audioCapDev.micVolume = slider.normalValue;
        }
    }
}
@end