//
//  PlayerPlugin.swift
//  Mojo
//
//  Created by Mojo on 12/7/25.
//

import Foundation

/// 播放器插件协议
/// 插件生命周期与视频播放生命周期绑定
/// 插件通过 PlayerContext 获得播放器控制能力
@MainActor
protocol PlayerPlugin: AnyObject {
    /// 插件唯一标识符
    var pluginId: String { get }
    
    /// 插件被注册时调用，获得播放器控制能力
    /// - Parameter context: 播放器上下文，用于控制播放器
    func pluginDidAttach(to context: PlayerContext)
    
    /// 插件被注销时调用
    func pluginWillDetach()
    
    /// 播放器状态发生变化时调用
    /// - Parameters:
    ///   - state: 新状态
    ///   - previous: 之前的状态
    func playerStateDidChange(_ state: PlayerState, previous: PlayerState)
    
    /// 播放时间发生变化时调用
    /// - Parameters:
    ///   - time: 当前播放时间（秒）
    ///   - duration: 视频总时长（秒）
    func playerTimeDidChange(_ time: TimeInterval, duration: TimeInterval)
    
    /// 缓冲状态发生变化时调用
    /// - Parameter isBuffering: 是否正在缓冲
    func playerBufferingDidChange(_ isBuffering: Bool)
    
    /// 音量发生变化时调用
    /// - Parameters:
    ///   - volume: 当前音量 (0 ~ 100)
    ///   - isMuted: 是否静音
    func playerVolumeDidChange(_ volume: Double, isMuted: Bool)
}

// MARK: - Default Implementation

extension PlayerPlugin {
    func pluginDidAttach(to context: PlayerContext) {
        // 默认空实现，插件可按需重写
    }
    
    func pluginWillDetach() {
        // 默认空实现，插件可按需重写
    }
    
    func playerStateDidChange(_ state: PlayerState, previous: PlayerState) {
        // 默认空实现，插件可按需重写
    }
    
    func playerTimeDidChange(_ time: TimeInterval, duration: TimeInterval) {
        // 默认空实现，插件可按需重写
    }
    
    func playerBufferingDidChange(_ isBuffering: Bool) {
        // 默认空实现，插件可按需重写
    }
    
    func playerVolumeDidChange(_ volume: Double, isMuted: Bool) {
        // 默认空实现，插件可按需重写
    }
}

