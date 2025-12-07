//
//  PlayerContext.swift
//  Mojo
//
//  Created by Mojo on 12/7/25.
//

import Foundation

/// 播放器上下文
/// 提供播放器控制能力，插件通过此接口与播放器交互
@MainActor
protocol PlayerContext: AnyObject {
    
    // MARK: - State (只读状态)
    
    /// 当前播放状态
    var state: PlayerState { get }
    
    /// 当前播放时间（秒）
    var currentTime: TimeInterval { get }
    
    /// 视频总时长（秒）
    var duration: TimeInterval { get }
    
    /// 是否正在缓冲
    var isBuffering: Bool { get }
    
    /// 当前音量 (0 ~ 100)
    var volume: Double { get }
    
    /// 是否静音
    var isMuted: Bool { get }
    
    // MARK: - Playback Controls (播放控制)
    
    /// 播放
    func play()
    
    /// 暂停
    func pause()
    
    /// 切换播放/暂停
    func togglePlayPause()
    
    /// 相对 seek
    func seek(relative time: TimeInterval)
    
    /// 绝对 seek
    func seek(absolute time: TimeInterval)
    
    /// 通过进度 seek (0.0 ~ 1.0)
    func seek(progress: Double)
    
    /// 加载文件
    func loadFile(_ url: URL, time: Double?)
    
    // MARK: - Volume Controls (音量控制)
    
    /// 设置音量 (0 ~ 100)
    func setVolume(_ volume: Double)
    
    /// 设置静音
    func setMuted(_ muted: Bool)
    
    /// 切换静音
    func toggleMute()
}

// MARK: - Default Implementation

extension PlayerContext {
    func loadFile(_ url: URL) {
        loadFile(url, time: nil)
    }
    
    func seek(progress: Double) {
        guard duration > 0 else { return }
        let targetTime = duration * max(0, min(1, progress))
        seek(absolute: targetTime)
    }
}

