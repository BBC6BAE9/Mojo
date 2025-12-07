//
//  PlayerState.swift
//  Mojo
//
//  Created by Mojo on 12/7/25.
//

import Foundation

/// 播放器的互斥状态
enum PlayerState: Int, Equatable {
    /// 初始/空闲状态，无文件加载
    case idle
    
    /// 文件加载中
    case loading
    
    /// 播放中
    case playing
    
    /// 暂停
    case paused
    
    /// 已停止（文件关闭）
    case stopped
}

