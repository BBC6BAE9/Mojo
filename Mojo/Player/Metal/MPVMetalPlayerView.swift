//
//  MPVMetalPlayerView.swift
//  Mojo
//

import Foundation
import SwiftUI

struct MPVMetalPlayerView: NSViewControllerRepresentable {
    
    /// 要播放的 URL
    var playUrl: URL?
    
    /// 要注册的插件列表
    var plugins: [PlayerPlugin] = []
    
    func makeNSViewController(context: Context) -> MPVMetalViewController {
        let player = MPVMetalViewController()
        player.playUrl = playUrl
        
        // 注册所有插件
        for plugin in plugins {
            player.pluginManager.register(plugin)
        }
        
        return player
    }
    
    func updateNSViewController(_ nsViewController: MPVMetalViewController, context: Context) {
        // 如果 URL 变化，加载新文件
        if let url = playUrl, url != nsViewController.playUrl {
            nsViewController.loadFile(url)
        }
    }
    
    // MARK: - Modifiers
    
    /// 设置要播放的 URL
    func play(_ url: URL) -> Self {
        var copy = self
        copy.playUrl = url
        return copy
    }
    
    /// 注册单个插件
    func registerPlugin(_ plugin: PlayerPlugin) -> Self {
        var copy = self
        copy.plugins.append(plugin)
        return copy
    }
    
    /// 注册多个插件
    func registerPlugins(_ plugins: [PlayerPlugin]) -> Self {
        var copy = self
        copy.plugins.append(contentsOf: plugins)
        return copy
    }
}
