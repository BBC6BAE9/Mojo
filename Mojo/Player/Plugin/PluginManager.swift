//
//  PluginManager.swift
//  Mojo
//
//  Created by Mojo on 12/7/25.
//

import Foundation

/// 插件管理器
/// 负责插件的注册、注销和事件分发
/// 生命周期与视频播放生命周期绑定
@MainActor
final class PluginManager {
    
    // MARK: - Properties
    
    /// 已注册的插件（以 pluginId 为 key）
    private var plugins: [String: PlayerPlugin] = [:]
    
    /// 播放器上下文（用于提供给插件控制播放器）
    weak var context: PlayerContext? {
        didSet {
            // context 设置后，通知所有已注册的插件
            if let context = context {
                for plugin in plugins.values {
                    plugin.pluginDidAttach(to: context)
                }
            }
        }
    }
    
    /// 当前播放器状态
    private(set) var currentState: PlayerState = .idle
    
    /// 当前视频时长
    private(set) var duration: TimeInterval = 0
    
    // MARK: - Plugin Registration
    
    /// 注册插件
    /// - Parameter plugin: 要注册的插件
    func register(_ plugin: PlayerPlugin) {
        plugins[plugin.pluginId] = plugin
        
        // 通知插件已注册，并提供播放器控制能力
        if let context = context {
            plugin.pluginDidAttach(to: context)
        }
    }
    
    /// 注销指定插件
    /// - Parameter pluginId: 插件唯一标识符
    func unregister(_ pluginId: String) {
        if let plugin = plugins[pluginId] {
            plugin.pluginWillDetach()
        }
        plugins.removeValue(forKey: pluginId)
    }
    
    /// 注销所有插件（视频关闭时调用）
    func unregisterAll() {
        for plugin in plugins.values {
            plugin.pluginWillDetach()
        }
        plugins.removeAll()
        currentState = .idle
        duration = 0
    }
    
    /// 获取已注册的插件数量
    var pluginCount: Int {
        plugins.count
    }
    
    // MARK: - Event Notification
    
    /// 通知所有插件状态变化
    /// - Parameters:
    ///   - state: 新状态
    ///   - previous: 之前的状态
    func notifyStateChange(_ state: PlayerState, previous: PlayerState) {
        guard state != previous else { return }
        currentState = state
        
        for plugin in plugins.values {
            plugin.playerStateDidChange(state, previous: previous)
        }
    }
    
    /// 通知所有插件时间变化
    /// - Parameters:
    ///   - time: 当前播放时间
    ///   - duration: 视频总时长
    func notifyTimeChange(_ time: TimeInterval, duration: TimeInterval) {
        self.duration = duration
        
        for plugin in plugins.values {
            plugin.playerTimeDidChange(time, duration: duration)
        }
    }
    
    /// 通知所有插件缓冲状态变化
    /// - Parameter isBuffering: 是否正在缓冲
    func notifyBufferingChange(_ isBuffering: Bool) {
        for plugin in plugins.values {
            plugin.playerBufferingDidChange(isBuffering)
        }
    }
    
    /// 通知所有插件音量变化
    /// - Parameters:
    ///   - volume: 当前音量 (0 ~ 100)
    ///   - isMuted: 是否静音
    func notifyVolumeChange(_ volume: Double, isMuted: Bool) {
        for plugin in plugins.values {
            plugin.playerVolumeDidChange(volume, isMuted: isMuted)
        }
    }
}

