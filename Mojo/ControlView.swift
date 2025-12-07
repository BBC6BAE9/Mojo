//
//  ControlView.swift
//  Mojo
//
//  Created by hong on 12/7/25.
//

import SwiftUI

struct ControlView: View {
    /// 控制栏插件（提供播放状态和控制能力）
    @ObservedObject var plugin: ControlBarPlugin
    
    /// 用户是否正在拖动进度条
    @State private var isSeeking: Bool = false
    /// 拖动时的进度值
    @State private var seekProgress: Double = 0
    /// 是否正在等待 seek 完成
    @State private var isWaitingForSeek: Bool = false
    
    // 拖拽相关
    @Binding var offset: CGSize
    @GestureState private var dragOffset: CGSize = .zero
    
    /// 是否应该显示拖动位置（拖动中或等待 seek 完成）
    private var shouldShowSeekPosition: Bool {
        isSeeking || isWaitingForSeek
    }
    
    /// 当前显示的时间
    private var displayTime: String {
        if shouldShowSeekPosition {
            let time = plugin.duration * seekProgress
            return ControlBarPlugin.formatTime(time)
        } else {
            return plugin.currentTimeFormatted
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // MARK: - 上排控制栏
            HStack(spacing: 0) {
                // 左侧：音量控制
                HStack(spacing: 10) {
                    Button(action: { plugin.toggleMute() }) {
                        Image(systemName: volumeIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                    }
                    .buttonStyle(.plain)
                    
                    Slider(
                        value: Binding(
                            get: { plugin.volume / 100.0 },
                            set: { plugin.setVolume($0 * 100.0) }
                        ),
                        in: 0...1
                    )
                    .tint(.white)
                    .frame(width: 90)
                }
                .frame(width: 140)
                
                Spacer()
                
                // 中间：播放控制
                HStack(spacing: 24) {
                    Button(action: { plugin.backward() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: { plugin.togglePlayPause() }) {
                        Image(systemName: plugin.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: { plugin.forward() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .foregroundStyle(.white)
                .buttonStyle(ControlButtonStyle())
                
                Spacer()
                
                // 右侧：功能按钮
                HStack(spacing: 20) {
                    Button(action: {}) {
                        Image(systemName: "airplayvideo")
                            .font(.system(size: 16, weight: .medium))
                            
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "chevron.forward.2")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundStyle(.secondary)
                .buttonStyle(ControlButtonStyle())
                .frame(width: 140)
            }
            
            // MARK: - 下排进度条
            HStack(spacing: 12) {
                Text(displayTime)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
                
                Slider(
                    value: Binding(
                        get: { shouldShowSeekPosition ? seekProgress : plugin.progress },
                        set: { seekProgress = $0 }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        if editing {
                            // 开始拖动，记录当前进度
                            isSeeking = true
                            isWaitingForSeek = false
                            seekProgress = plugin.progress
                        } else {
                            // 结束拖动，执行 seek，保持显示 seekProgress 直到播放位置接近
                            isSeeking = false
                            isWaitingForSeek = true
                            plugin.seek(progress: seekProgress)
                        }
                    }
                )
                .tint(.white)
                .onChange(of: plugin.progress) { _, newProgress in
                    // 当播放位置接近 seek 目标时，停止等待
                    if isWaitingForSeek && abs(newProgress - seekProgress) < 0.02 {
                        isWaitingForSeek = false
                    }
                }
                
                Text(plugin.durationFormatted)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(width: 480)
        .contentShape(Rectangle())
        .glassEffect(in: .rect(cornerRadius: 16))
        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                }
        )
    }
    
    // MARK: - Helpers
    
    private var volumeIcon: String {
        if plugin.isMuted || plugin.volume == 0 {
            return "speaker.slash.fill"
        } else if plugin.volume < 33 {
            return "speaker.wave.1.fill"
        } else if plugin.volume < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Button Style

struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    @Previewable @StateObject var plugin = ControlBarPlugin()
    
    ZStack {
        Color.black
        ControlView(plugin: plugin, offset: .constant(.zero))
    }
}
