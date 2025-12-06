import Foundation
import AppKit
import CoreMedia
import Libmpv

// warning: metal API validation has been disabled to ignore crash when playing HDR videos.
// Edit Scheme -> Run -> Diagnostics -> Metal API Validation -> Turn it off
// https://github.com/KhronosGroup/MoltenVK/issues/2226
final class MPVMetalViewController: NSViewController {
    
    // MARK: - Properties
    
    var metalLayer = MetalLayer()
    var mpv: OpaquePointer!
    var playDelegate: MPVPlayerDelegate?
    var edrRange: CGFloat?
    lazy var queue = DispatchQueue(label: "mpv", qos: .userInitiated)
    
    var playUrl: URL?
    var hdrAvailable: Bool = false
    var hdrEnabled = false {
        didSet {
            // FIXME: target-colorspace-hint does not support being changed at runtime.
            // this option should be set when mpv init otherwise can cause player slow and hangs.
            // not recommended to use this way.
            queue.async { [weak self] in
                guard let self, self.mpv != nil else { return }
                if self.hdrEnabled {
                    self.checkError(mpv_set_option_string(self.mpv, "target-colorspace-hint", "yes"))
                } else {
                    self.checkError(mpv_set_option_string(self.mpv, "target-colorspace-hint", "no"))
                }
            }
        }
    }
    
    // MARK: - Screen Adaptation Properties (屏幕自适应相关属性)
    
    /// 视频显示容器视图
    var videoDisplayView: NSView?
    
    /// 视频原始尺寸
    var videoSize: CGSize?
    
    /// 播放设置是否完成
    var playSetupFinished = false
    
    // MARK: - Lifecycle
    
    override func loadView() {
        self.view = NSView(frame: .init(x: 0, y: 0, width: NSScreen.main!.frame.width, height: NSScreen.main!.frame.height))
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.black.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 使用默认尺寸初始化播放逻辑
        videoSize = CGSize(width: 1920, height: 1080)
        setupPlayLogic()
        
        // observer EDR range value change
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] value in
            guard let self = self else { return }
            
            if let screen = NSScreen.screens.first {
                let maxRange = screen.maximumExtendedDynamicRangeColorComponentValue
                DispatchQueue.main.async {
                    self.playDelegate?.propertyChange(mpv: self.mpv, propertyName: "edr", data: maxRange)
                }
            }
        }
        
        // 监听窗口大小变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: nil
        )
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        if playSetupFinished {
            setVideoViewCenter()
        }
    }
    
    @objc private func windowDidResize(_ notification: Notification) {
        if playSetupFinished {
            setVideoViewCenter()
        }
    }
    
    // MARK: - Screen Adaptation Methods (屏幕自适应方法)
    
    /// 设置播放逻辑
    func setupPlayLogic() {
        guard let videoSize = videoSize else {
            print("❌ videoSize is nil, cannot setup play logic")
            return
        }
        
        // 移除旧的视频显示视图
        if videoDisplayView != nil {
            metalLayer.removeFromSuperlayer()
            videoDisplayView?.removeFromSuperview()
            videoDisplayView = nil
        }
        
        // 创建视频显示容器视图 - 使用原始视频尺寸作为 bounds
        // 类似 iOS 的做法：bounds 保持原始尺寸，通过 transform 进行缩放
        videoDisplayView = NSView(frame: CGRect(origin: .zero, size: videoSize))
        videoDisplayView!.wantsLayer = true
        view.addSubview(videoDisplayView!)
        
        print("🎬 Setup video display view with video size: \(videoSize)")
        print("🎬 Container view bounds: \(view.bounds)")
        
        // 设置 Metal Layer 属性
        let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.contentsScale = backingScale
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = NSColor.black.cgColor
        
        // 设置 metalLayer 的 frame 为原始视频尺寸
        metalLayer.frame = CGRect(origin: .zero, size: videoSize)
        // 注意：不要手动设置 drawableSize，让 mpv/MoltenVK 自己管理，避免主线程阻塞
        
        // 添加 metalLayer 作为子图层（不是 backing layer）
        // 这样我们可以在 videoDisplayView 上应用 transform
        videoDisplayView!.layer?.addSublayer(metalLayer)
        
        print("🎬 Initial metalLayer setup: frame=\(metalLayer.frame), drawableSize=\(metalLayer.drawableSize)")
        
        // 设置 MPV（在后台线程执行以避免阻塞主线程）
        queue.async { [weak self] in
            guard let self else { return }
            self.setupMpv()
            
            DispatchQueue.main.async {
                self.playSetupFinished = true
                // 立即进行一次布局
                self.setVideoViewCenter()
                
                // 如果有待播放的 URL，开始加载
                if let url = self.playUrl {
                    self.loadFile(url)
                }
            }
        }
    }
    
    /// 设置视频视图居中并缩放以适应容器（iOS 风格的 transform 缩放）
    private func setVideoViewCenter() {
        guard let videoDisplayView = videoDisplayView,
              let videoSize = videoSize else { return }
        
        // 使用控制器视图作为容器
        let containerBounds = view.bounds
        let containerSize = containerBounds.size
        guard containerSize.width > 0, containerSize.height > 0 else { return }
        
        // 确定源视频尺寸
        let sourceSize: CGSize = {
            if videoSize.width > 0, videoSize.height > 0 {
                return videoSize
            }
            return CGSize(width: 16, height: 9)
        }()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // 1. 重置 transform 到 identity（避免叠加缩放）
        videoDisplayView.layer?.setAffineTransform(.identity)
        
        // 2. 设置 bounds 为原始视频尺寸（不是缩放后的尺寸）
        videoDisplayView.setBoundsSize(sourceSize)
        
        // 3. 计算等比缩放因子
        let scale = min(containerSize.width / sourceSize.width,
                        containerSize.height / sourceSize.height)
        
        // 4. 将视图定位到容器中心
        // 注意：在 macOS 中，需要先设置 frame origin，再应用 transform
        // frame origin 应该基于原始尺寸计算居中位置
        let centerX = containerBounds.midX
        let centerY = containerBounds.midY
        videoDisplayView.setFrameOrigin(NSPoint(
            x: centerX - sourceSize.width / 2,
            y: centerY - sourceSize.height / 2
        ))
        
        // 5. 应用缩放 transform 到图层
        // 设置 anchorPoint 为中心，确保从中心缩放
        videoDisplayView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        videoDisplayView.layer?.position = CGPoint(x: centerX, y: centerY)
        videoDisplayView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        
        // 6. metalLayer 保持原始视频尺寸
        metalLayer.frame = CGRect(origin: .zero, size: sourceSize)
        // 注意：不要手动设置 drawableSize，让 mpv/MoltenVK 自己管理
        
        CATransaction.commit()
    }
    
    // MARK: - MPV Setup
    
    func setupMpv(hdrPass: Bool = false) {
        mpv = mpv_create()
        if mpv == nil {
            print("failed creating context\n")
            exit(1)
        }
        
        // https://mpv.io/manual/stable/#options
#if DEBUG
        checkError(mpv_request_log_messages(mpv, "debug"))
#else
        checkError(mpv_request_log_messages(mpv, "no"))
#endif
#if os(macOS)
        checkError(mpv_set_option_string(mpv, "input-media-keys", "yes"))
#endif
        checkError(mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &metalLayer))
        checkError(mpv_set_option_string(mpv, "subs-match-os-language", "yes"))
        checkError(mpv_set_option_string(mpv, "subs-fallback", "yes"))
        checkError(mpv_set_option_string(mpv, "vo", "gpu-next"))
        checkError(mpv_set_option_string(mpv, "gpu-api", "vulkan"))
        checkError(mpv_set_option_string(mpv, "gpu-context", "moltenvk"))
        checkError(mpv_set_option_string(mpv, "hwdec", "videotoolbox"))
        checkError(mpv_set_option_string(mpv, "ytdl", "no"))
        
        // 保持宽高比设置
        checkError(mpv_set_option_string(mpv, "keepaspect", "yes"))
        checkError(mpv_set_option_string(mpv, "keepaspect-window", "no"))
        checkError(mpv_set_option_string(mpv, "video-unscaled", "no"))
        checkError(mpv_set_option_string(mpv, "auto-window-resize", "yes"))
        
        //        checkError(mpv_set_option_string(mpv, "target-colorspace-hint", "yes")) // HDR passthrough
        //        checkError(mpv_set_option_string(mpv, "tone-mapping-visualize", "yes"))  // only for debugging purposes
        //        checkError(mpv_set_option_string(mpv, "profile", "fast"))   // can fix frame drop in poor device when play 4k
        
        
        checkError(mpv_initialize(mpv))
        
        mpv_observe_property(mpv, 0, MPVProperty.videoParamsSigPeak, MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, MPVProperty.videoParamsColormatrix, MPV_FORMAT_STRING)
        mpv_observe_property(mpv, 0, MPVProperty.pausedForCache, MPV_FORMAT_FLAG)
        // 观察视频尺寸变化
        mpv_observe_property(mpv, 0, "video-params/w", MPV_FORMAT_INT64)
        mpv_observe_property(mpv, 0, "video-params/h", MPV_FORMAT_INT64)
        
        mpv_set_wakeup_callback(self.mpv, { (ctx) in
            guard let client = ctx else { return }
            let viewController = Unmanaged<MPVMetalViewController>.fromOpaque(client).takeUnretainedValue()
            viewController.readEvents()
        }, Unmanaged.passRetained(self).toOpaque())
    }
    
    // MARK: - File Loading
    
    func loadFile(
        _ url: URL,
        time: Double? = nil
    ) {
        self.playUrl = url
        
        var args = [url.absoluteString]
        var options = [String]()
        
        args.append("replace")
        args.append("-1")
        
        if let time, time > 0 {
            options.append("start=\(Int(time))")
        }
        
        if !options.isEmpty {
            args.append(options.joined(separator: ","))
        }
        
        command("loadfile", args: args)
    }
    
    // MARK: - Playback Controls
    
    func play() {
        setFlag("pause", false)
    }
    
    func pause() {
        setFlag("pause", true)
    }
    
    func seek(relative time: TimeInterval) {
        command("seek", args: [String(time), "relative"])
    }
    
    func seek(absolute time: TimeInterval) {
        command("seek", args: [String(time), "absolute"])
    }
    
    // MARK: - MPV Property Accessors
    
    private func getDouble(_ name: String) -> Double {
        guard mpv != nil else { return 0.0 }
        var data = Double()
        mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
        return data
    }
    
    private func getInt(_ name: String) -> Int {
        guard mpv != nil else { return 0 }
        var data = Int64()
        mpv_get_property(mpv, name, MPV_FORMAT_INT64, &data)
        return Int(data)
    }
    
    private func getString(_ name: String) -> String? {
        guard mpv != nil else { return nil }
        let cstr = mpv_get_property_string(mpv, name)
        let str: String? = cstr == nil ? nil : String(cString: cstr!)
        mpv_free(cstr)
        return str
    }
    
    func setFlag(_ name: String, _ flag: Bool) {
        queue.async { [weak self] in
            guard let self, self.mpv != nil else { return }
            var data: Int = flag ? 1 : 0
            mpv_set_property(self.mpv, name, MPV_FORMAT_FLAG, &data)
        }
    }
    
    func command(
        _ command: String,
        args: [String?] = [],
        checkForErrors: Bool = true,
        returnValueCallback: ((Int32) -> Void)? = nil
    ) {
        queue.async { [weak self] in
            guard let self, self.mpv != nil else { return }
            
            var cargs = self.makeCArgs(command, args).map { $0.flatMap { UnsafePointer<CChar>(strdup($0)) } }
            defer {
                for ptr in cargs where ptr != nil {
                    free(UnsafeMutablePointer(mutating: ptr!))
                }
            }
            let returnValue = mpv_command(self.mpv, &cargs)
            if checkForErrors {
                self.checkError(returnValue)
            }
            if let cb = returnValueCallback {
                DispatchQueue.main.async {
                    cb(returnValue)
                }
            }
        }
    }
    
    private func makeCArgs(_ command: String, _ args: [String?]) -> [String?] {
        if !args.isEmpty, args.last == nil {
            fatalError("Command do not need a nil suffix")
        }
        
        var strArgs = args
        strArgs.insert(command, at: 0)
        strArgs.append(nil)
        
        return strArgs
    }
    
    // MARK: - Event Handling
    
    func readEvents() {
        queue.async { [weak self] in
            guard let self else { return }

            while self.mpv != nil {
                let event = mpv_wait_event(self.mpv, 0)
                if event?.pointee.event_id == MPV_EVENT_NONE {
                    break
                }
                
                switch event!.pointee.event_id {
                case MPV_EVENT_PROPERTY_CHANGE:
                    let dataOpaquePtr = OpaquePointer(event!.pointee.data)
                    if let property = UnsafePointer<mpv_event_property>(dataOpaquePtr)?.pointee {
                        let propertyName = String(cString: property.name)
                        switch propertyName {
                        case MPVProperty.videoParamsSigPeak:
                            if let sigPeak = UnsafePointer<Double>(OpaquePointer(property.data))?.pointee {
                                DispatchQueue.main.async {
                                    let maxEDRRange = NSScreen.main?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1.0
                                    // display screen support HDR and current playing HDR video
                                    self.hdrAvailable = maxEDRRange > 1.0 && sigPeak > 1.0
                                    self.playDelegate?.propertyChange(mpv: self.mpv, propertyName: propertyName, data: sigPeak)
                                }
                            }
                        case MPVProperty.pausedForCache:
                            let buffering = UnsafePointer<Bool>(OpaquePointer(property.data))?.pointee ?? true
                            DispatchQueue.main.async {
                                self.playDelegate?.propertyChange(mpv: self.mpv, propertyName: propertyName, data: buffering)
                            }
                        case "video-params/w":
                            // 直接从事件数据中获取宽度值
                            if let width = UnsafePointer<Int64>(OpaquePointer(property.data))?.pointee, width > 0 {
                                DispatchQueue.main.async {
                                    self.updateVideoWidth(Int(width))
                                }
                            }
                        case "video-params/h":
                            // 直接从事件数据中获取高度值
                            if let height = UnsafePointer<Int64>(OpaquePointer(property.data))?.pointee, height > 0 {
                                DispatchQueue.main.async {
                                    self.updateVideoHeight(Int(height))
                                }
                            }
                        default: break
                        }
                    }
                    
                case MPV_EVENT_FILE_LOADED:
                    // 在后台线程获取视频尺寸，避免阻塞主线程
                    let width = self.getInt("width")
                    let height = self.getInt("height")
                    if width > 0 && height > 0 {
                        DispatchQueue.main.async {
                            self.updateVideoSize(width: width, height: height)
                        }
                    }
                    
                case MPV_EVENT_SHUTDOWN:
                    print("event: shutdown\n");
                    mpv_terminate_destroy(mpv);
                    mpv = nil;
                    break;
                case MPV_EVENT_LOG_MESSAGE:
                    let msg = UnsafeMutablePointer<mpv_event_log_message>(OpaquePointer(event!.pointee.data))
                    print("[\(String(cString: (msg!.pointee.prefix)!))] \(String(cString: (msg!.pointee.level)!)): \(String(cString: (msg!.pointee.text)!))", terminator: "")
                default:
                    let eventName = mpv_event_name(event!.pointee.event_id )
                    print("event: \(String(cString: (eventName)!))");
                }
                
            }
        }
    }
    
    /// 缓存的视频宽度
    private var cachedVideoWidth: Int = 0
    /// 缓存的视频高度
    private var cachedVideoHeight: Int = 0
    
    /// 更新视频宽度（从属性变化事件直接获取）
    private func updateVideoWidth(_ width: Int) {
        cachedVideoWidth = width
        if cachedVideoHeight > 0 {
            updateVideoSize(width: cachedVideoWidth, height: cachedVideoHeight)
        }
    }
    
    /// 更新视频高度（从属性变化事件直接获取）
    private func updateVideoHeight(_ height: Int) {
        cachedVideoHeight = height
        if cachedVideoWidth > 0 {
            updateVideoSize(width: cachedVideoWidth, height: cachedVideoHeight)
        }
    }
    
    /// 更新视频尺寸并刷新布局（不阻塞主线程）
    private func updateVideoSize(width: Int, height: Int) {
        let newSize = CGSize(width: width, height: height)
        
        // 只有当尺寸真正变化时才更新
        guard videoSize != newSize else { return }
        
        print("🎬 Video size updated: \(width)x\(height)")
        videoSize = newSize
        cachedVideoWidth = width
        cachedVideoHeight = height
        
        // 设置窗口 aspectRatio，锁定窗口只能按视频比例缩放
        view.window?.aspectRatio = newSize
        
        // 更新布局（setVideoViewCenter 会更新 metalLayer.frame，但不设置 drawableSize）
        if playSetupFinished {
            setVideoViewCenter()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        if mpv != nil {
            mpv_set_wakeup_callback(mpv, nil, nil)
            
            // Wait for any pending queue operations to complete
            queue.sync {
                if self.mpv != nil {
                    mpv_terminate_destroy(self.mpv)
                    self.mpv = nil
                }
            }
            
            // Release the retained self from wakeup callback
            Unmanaged.passUnretained(self).release()
        }
    }
    
    private func checkError(_ status: CInt) {
        if status < 0 {
            print("MPV API error: \(String(cString: mpv_error_string(status)))\n")
        }
    }
    
}
