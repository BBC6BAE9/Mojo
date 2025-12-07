//
//  ControlView.swift
//  Mojo
//
//  Created by hong on 12/7/25.
//

import SwiftUI

struct ControlView: View {
    @State private var volume: Double = 0.8
    @State private var progress: Double = 0.08
    @State private var isPlaying: Bool = false
    
    // 拖拽相关
    @Binding var offset: CGSize
    @GestureState private var dragOffset: CGSize = .zero
    
    // 示例时间
    private let currentTime: TimeInterval = 3
    private let totalTime: TimeInterval = 36
    
    var body: some View {
        VStack(spacing: 16) {
            // MARK: - 上排控制栏
            HStack(spacing: 0) {
                // 左侧：音量控制
                HStack(spacing: 10) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    
                    Slider(value: $volume, in: 0...1)
                        .tint(.white)
                        .frame(width: 90)
                }
                .frame(width: 140)
                
                Spacer()
                
                // 中间：播放控制
                HStack(spacing: 24) {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: { isPlaying.toggle() }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: {}) {
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
                Text(formatTime(currentTime))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .trailing)
                
                Slider(value: $progress, in: 0...1)
                    .tint(.white)
                
                Text(formatTime(totalTime))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
    ZStack {
        Color.black
        ControlView(offset: .constant(.zero))
    }
}
