//
//  ControlBarPlugin.swift
//  Mojo
//
//  Created by Mojo on 12/7/25.
//

import Foundation
internal import Combine

/// 播放控制栏插件
/// 提供播放状态、时间、进度等信息，供 UI 绑定使用
@MainActor
final class ControlBarPlugin: PlayerPlugin, ObservableObject {
    
    // MARK: - PlayerPlugin
    
    let pluginId = "mojo.control-bar"
    
    /// 播放器上下文（用于控制播放器）
    private weak var context: PlayerContext?
    
    // MARK: - Published Properties (供 UI 绑定)
    
    /// 当前播放状态
    @Published private(set) var state: PlayerState = .idle
    
    /// 当前播放时间（秒）
    @Published private(set) var currentTime: TimeInterval = 0
    
    /// 视频总时长（秒）
    @Published private(set) var duration: TimeInterval = 0
    
    /// 是否正在缓冲
    @Published private(set) var isBuffering: Bool = false
    
    /// 当前音量 (0 ~ 100)
    @Published private(set) var volume: Double = 100
    
    /// 是否静音
    @Published private(set) var isMuted: Bool = false
    
    // MARK: - Computed Properties
    
    /// 是否正在播放
    var isPlaying: Bool {
        state == .playing
    }
    
    /// 播放进度 (0.0 ~ 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    /// 剩余时间（秒）
    var remainingTime: TimeInterval {
        max(0, duration - currentTime)
    }
    
    // MARK: - Playback Controls
    
    /// 播放
    func play() {
        context?.play()
    }
    
    /// 暂停
    func pause() {
        context?.pause()
    }
    
    /// 切换播放/暂停
    func togglePlayPause() {
        context?.togglePlayPause()
    }
    
    /// 快进（相对 seek）
    func forward(_ seconds: TimeInterval = 10) {
        context?.seek(relative: seconds)
    }
    
    /// 快退（相对 seek）
    func backward(_ seconds: TimeInterval = 10) {
        context?.seek(relative: -seconds)
    }
    
    /// 跳转到指定时间
    func seek(to time: TimeInterval) {
        context?.seek(absolute: time)
    }
    
    /// 跳转到指定进度 (0.0 ~ 1.0)
    func seek(progress: Double) {
        context?.seek(progress: progress)
    }
    
    // MARK: - Volume Controls (音量控制)
    
    /// 设置音量 (0 ~ 100)
    func setVolume(_ volume: Double) {
        context?.setVolume(volume)
    }
    
    /// 设置静音
    func setMuted(_ muted: Bool) {
        context?.setMuted(muted)
    }
    
    /// 切换静音
    func toggleMute() {
        context?.toggleMute()
    }
    
    // MARK: - PlayerPlugin Implementation
    
    func pluginDidAttach(to context: PlayerContext) {
        self.context = context
        // 同步当前状态
        self.state = context.state
        self.currentTime = context.currentTime
        self.duration = context.duration
        self.isBuffering = context.isBuffering
        self.volume = context.volume
        self.isMuted = context.isMuted
    }
    
    func pluginWillDetach() {
        context = nil
        state = .idle
        currentTime = 0
        duration = 0
        isBuffering = false
        volume = 100
        isMuted = false
    }
    
    func playerStateDidChange(_ state: PlayerState, previous: PlayerState) {
        self.state = state
    }
    
    func playerTimeDidChange(_ time: TimeInterval, duration: TimeInterval) {
        self.currentTime = time
        self.duration = duration
    }
    
    func playerBufferingDidChange(_ isBuffering: Bool) {
        self.isBuffering = isBuffering
    }
    
    func playerVolumeDidChange(_ volume: Double, isMuted: Bool) {
        self.volume = volume
        self.isMuted = isMuted
    }
}

// MARK: - Time Formatting

extension ControlBarPlugin {
    /// 格式化时间为 mm:ss 或 hh:mm:ss
    static func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "00:00" }
        
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// 当前时间格式化字符串
    var currentTimeFormatted: String {
        Self.formatTime(currentTime)
    }
    
    /// 总时长格式化字符串
    var durationFormatted: String {
        Self.formatTime(duration)
    }
    
    /// 剩余时间格式化字符串
    var remainingTimeFormatted: String {
        Self.formatTime(remainingTime)
    }
}

