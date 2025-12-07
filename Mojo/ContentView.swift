//
//  ContentView.swift
//  Mojo
//
//  Created by hong on 12/6/25.
//

import SwiftUI

struct ContentView: View {
    /// 控制栏插件
    @StateObject private var controlBar = ControlBarPlugin()
    
    @State private var showControlOverlay = false
    
    // 播控拖拽位置（默认向上偏移 60pt）
    @State private var controlOffset: CGSize = CGSize(width: 0, height: -60)
    
    var body: some View {
        VStack {
            MPVMetalPlayerView()
                .play(URL(string: "http://192.161.51.202:8096/emby/Videos/327842/stream?Static=true&api_key=0188a76fdedf433183c338f0fec97e92")!)
                .registerPlugin(controlBar)
        }
        .containerBackground(.yellow, for: .window)
        .focusable()
        .focusEffectDisabled()
        .overlay(alignment: .bottom) {
            ControlView(plugin: controlBar, offset: $controlOffset)
        }
        .onHover { hover in
            showControlOverlay = hover
        }
        .onKeyPress(action: { key in
            debugPrint("key: \(key.characters)")
            return .handled
        })
        .onKeyPress(.leftArrow, action: {
            controlBar.backward()
            return .handled
        })
        .onKeyPress(.rightArrow, action: {
            controlBar.forward()
            return .handled
        })
        .onKeyPress(.space, action: {
            controlBar.togglePlayPause()
            return .handled
        })
        .overlay(overlayView)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var overlayView: some View {
        if controlBar.isBuffering {
            ProgressView()
        } else {
            EmptyView()
        }
    }
}
