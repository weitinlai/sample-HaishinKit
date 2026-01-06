//
//  ViewController.swift
//  HaishinKitTwitch
//
//  Created on 2024.
//

import UIKit
import AVFoundation
import HaishinKit
import RTMPHaishinKit
import VideoToolbox
import CoreVideo

// MARK: - Audio Mode Enum
enum AudioMode {
    case microphoneOnly    // 只有麥克風
    case wavOnly          // 只有WAV
    case both             // 麥克風 + WAV
}

// 使用 AudioConverter 統一所有音訊格式

class ViewController: UIViewController {
    
    // MARK: - Streaming Objects
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    
    // Twitch Info
    private let twitchStreamKey = "live_1351349836_cXwWcF3bCaM3S0F6vkuarykAz20jfk"
    private let twitchRTMPURL = "rtmp://live.twitch.tv/app" // 注意：URL 不包含 stream key
    
    // 虛擬訊號源控制
    private var isStreaming = false
    private var videoTimer: Timer?
    private var audioTimer: Timer?

    // 音訊模式控制
    private var currentAudioMode: AudioMode = .both
    
    // 圖片資源
    private var images: [UIImage] = []
    private var currentImageIndex = 0
    private var imageRotationTimer: Timer?
    private var currentPixelBuffer: CVPixelBuffer? // 緩存當前要發送的圖片幀
    
    private var videoPTS: CMTime = .zero
    private let videoFrameDuration = CMTime(value: 1, timescale: 30)

    // 音訊資源
    private var audioData: Data = Data()
    private var audioOffset: Int = 0
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioFileFormat: AVAudioFormat? // 保存原始音訊格式
    private var audioSampleRate: Double = 44100
    private var audioChannels: UInt32 = 1
    // 移除 AudioEngineCapture 相關變數，回到直接發送的方法
    
    // 用來精確記錄下一幀音訊應該從什麼時間開始
    private var audioPresentationTimeStamp: CMTime = .zero

    // 直播音訊捕獲服務
    private let audioSourceService = AudioSourceService()
    private var audioCaptureTask: Task<Void, Never>?

    // 在 ViewController 類別中添加
    private var mixer = MediaMixer(multiTrackAudioMixingEnabled: true)
    private var wavAudioSourceService: WAVAudioSourceService!
    private var wavAudioTask: Task<Void, Never>?
    private var videoSendTask: Task<Void, Never>?

    // UI
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var previewView: UIView!
    private var previewLayer: CALayer? // 用來顯示當前發送的圖片

    // 音訊控制UI
    private var audioModeControl: UISegmentedControl!

    // 動態檢測到的音訊格式
    private var detectedSampleRate: Double = 44100

    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        loadImages()
        loadAudioFile() // 預先載入音訊數據
        setupLocalPreview()
        setupAudioSession()
        setupWavAudioService()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 建立預覽視圖
        let preview = UIView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.backgroundColor = .black
        view.addSubview(preview)
        previewView = preview

        // === 音訊模式控制 ===
        let audioControl = UISegmentedControl(items: ["🎙️ 麥克風", "🎵 WAV", "🎙️+🎵 雙聲道"])
        audioControl.translatesAutoresizingMaskIntoConstraints = false
        audioControl.selectedSegmentIndex = 2  // 預設選擇雙聲道
        audioControl.addTarget(self, action: #selector(audioModeChanged(_:)), for: .valueChanged)
        view.addSubview(audioControl)
        audioModeControl = audioControl

        // 建立開始按鈕
        let startBtn = UIButton(type: .system)
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        startBtn.setTitle("開始直播", for: .normal)
        startBtn.backgroundColor = .systemGreen
        startBtn.setTitleColor(.white, for: .normal)
        startBtn.layer.cornerRadius = 8
        startBtn.addTarget(self, action: #selector(startStreaming), for: .touchUpInside)
        view.addSubview(startBtn)
        startButton = startBtn
        
        // 建立停止按鈕
        let stopBtn = UIButton(type: .system)
        stopBtn.translatesAutoresizingMaskIntoConstraints = false
        stopBtn.setTitle("停止直播", for: .normal)
        stopBtn.backgroundColor = .systemRed
        stopBtn.setTitleColor(.white, for: .normal)
        stopBtn.layer.cornerRadius = 8
        stopBtn.isEnabled = false
        stopBtn.alpha = 0.5
        stopBtn.addTarget(self, action: #selector(stopStreaming), for: .touchUpInside)
        view.addSubview(stopBtn)
        stopButton = stopBtn
        
        // 建立狀態標籤
        let statusLbl = UILabel()
        statusLbl.translatesAutoresizingMaskIntoConstraints = false
        statusLbl.text = "準備就緒"
        statusLbl.textAlignment = .center
        statusLbl.numberOfLines = 0
        view.addSubview(statusLbl)
        statusLabel = statusLbl
        
        // 設定 Auto Layout
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 9.0/16.0),

        // 音訊控制器的約束
        audioModeControl.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 20),
        audioModeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        audioModeControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        audioModeControl.heightAnchor.constraint(equalToConstant: 40),

        startButton.topAnchor.constraint(equalTo: audioModeControl.bottomAnchor, constant: 20),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            startButton.heightAnchor.constraint(equalToConstant: 50),

            stopButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 15),
            stopButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            stopButton.heightAnchor.constraint(equalToConstant: 50),

            statusLabel.topAnchor.constraint(equalTo: stopButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - 1. 準備資源
    private func loadImages() {
        // 載入你的 sample 圖片
        for i in 1...3 {
            if let img = UIImage(named: "sample\(i).jpg") {
                images.append(img)
            }
        }
        print("已載入 \(images.count) 張圖片")
        updateCurrentPixelBuffer() // 準備第一張圖
    }
    
    // MARK: - 讀取並標準化音訊 (黃金標準版)
    private func loadAudioFile() {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "wav") else {
            print("❌ 找不到 sample.wav 檔案")
            return
        }

        do {
            // 1. 開啟檔案
            let file = try AVAudioFile(forReading: url)
            let sourceFormat = file.processingFormat // 這是 AVAudioFile 最喜歡的格式 (通常是 Float32)
            print("📄 原始檔案: \(file.fileFormat.sampleRate)Hz, \(file.fileFormat.channelCount)ch")

            // 2. 讀取原始數據 (讀取為 Float32，這是最安全的操作，避開 Error -50)
            let frameCount = UInt32(file.length)
            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
                print("❌ 無法建立來源緩衝區")
                return
            }
            try file.read(into: sourceBuffer)

            // 3. 定義目標格式 (16-bit, 48000Hz, 單聲道) - 簡化格式匹配
            guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                  sampleRate: 48000,
                                                  channels: 1, // 單聲道輸出
                                                  interleaved: true) else { return }
            
            // 4. 建立轉換器
            guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                print("❌ 無法建立格式轉換器")
                return
            }
            
            // 5. 計算目標 Buffer 大小 (根據採樣率比例)
            let sampleRateRatio = targetFormat.sampleRate / sourceFormat.sampleRate
            let targetFrameCapacity = AVAudioFrameCount(Double(frameCount) * sampleRateRatio) + 1024 // 加一點緩衝
            
            guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCapacity) else { return }
            
            // 6. 執行轉換
            var error: NSError? = nil
            let status = converter.convert(to: targetBuffer, error: &error) { _, outStatus in
                // Input Block: 把剛剛讀到的 Float32 給轉換器
                outStatus.pointee = .haveData
                return sourceBuffer
            }
            
            if let error = error {
                print("❌ 轉換失敗: \(error.localizedDescription)")
                return
            }
            
            // 7. 保存標準化後的數據
            if let int16Data = targetBuffer.int16ChannelData {
                // 計算數據大小: 幀數 * 聲道數 * 2 bytes (Int16)
                let dataSize = Int(targetBuffer.frameLength) * Int(targetFormat.channelCount) * 2
                self.audioData = Data(bytes: int16Data[0], count: dataSize)
                
                // 更新全域變數，供 startStreaming 使用
                self.audioSampleRate = targetFormat.sampleRate
                self.audioChannels = targetFormat.channelCount
                self.audioFileFormat = targetFormat
                
            print("✅ 音訊載入並標準化完成")
                       print("   最終格式: \(targetFormat.sampleRate)Hz, \(targetFormat.channelCount)ch (Mono), Int16")
                print("   數據大小: \(self.audioData.count) bytes")
            }
            
        } catch {
            print("❌ 讀取音訊嚴重錯誤: \(error)")
        }
    }

    private func setupLocalPreview() {
        previewLayer = CALayer()
        previewLayer?.frame = previewView.bounds
        previewLayer?.contentsGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer!)
        if let first = images.first {
            previewLayer?.contents = first.cgImage
        }
    }

    private func setupAudioSession() {
        Task {
            await audioSourceService.setUp(.audioEngine)
            print("🎙️ 音訊服務已設置，將使用 AudioConverter 統一格式")
        }
    }

    private func setupWavAudioService() {
        wavAudioSourceService = WAVAudioSourceService(audioData: audioData, sampleRate: audioSampleRate, channels: audioChannels)
    }

    // MARK: - Audio Mode Control
    @objc private func audioModeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            currentAudioMode = .microphoneOnly
            print("🔄 切換到：只有麥克風模式")
        case 1:
            currentAudioMode = .wavOnly
            print("🔄 切換到：只有WAV模式")
        case 2:
            currentAudioMode = .both
            print("🔄 切換到：雙聲道模式")
        default:
            break
        }

        // 如果正在直播，顯示提示
        if isStreaming {
            let modeText = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? ""
            statusLabel.text = "音訊模式已切換為：\(modeText)\n請重新開始直播以應用更改"
        }
    }


    // MARK: - 2. 開始直播邏輯
    @objc func startStreaming(_ sender: Any) {
        guard !isStreaming else { return }
        
        guard !twitchStreamKey.isEmpty && twitchStreamKey != "YOUR_TWITCH_STREAM_KEY_HERE" else {
            showAlert(title: "錯誤", message: "請先在 ViewController.swift 中設定您的 Twitch Stream Key")
            return
        }
        
        if images.isEmpty {
            showAlert(title: "錯誤", message: "請先添加 JPG 圖片檔案（sample1.jpg, sample2.jpg 等）")
            return
        }
        
        // 顯示當前選擇的音訊模式
        let modeText: String
        switch currentAudioMode {
        case .microphoneOnly:
            modeText = "🎙️ 只有麥克風"
        case .wavOnly:
            modeText = "🎵 只有WAV"
        case .both:
            modeText = "🎙️+🎵 雙聲道"
        }

        Task {
            do {
                await MainActor.run {
                    statusLabel.text = "啟動直播...\n音訊模式: \(modeText)"
                    startButton.isEnabled = false
                    startButton.alpha = 0.5
                }
                
                // 1. 設定編碼參數
                // 音訊: 使用系統默認採樣率 (通常 48000Hz) 匹配麥克風輸入
                let audioSettings = AudioCodecSettings(bitRate: 128000, sampleRate: 48000)
                // HaishinKit 會自動檢測輸入數據是立體聲，這裡不需要額外設 channelCount (預設就是支援立體聲)
                // 視頻: 720p 30fps
                let videoSettings = VideoCodecSettings(videoSize: .init(width: 1280, height: 720), bitRate: 2500 * 1000)
                
                try await rtmpStream.setAudioSettings(audioSettings)
                try await rtmpStream.setVideoSettings(videoSettings)
                
                // 設置 MediaMixer 並連接 RTMP 串流
                try await mixer.addOutput(rtmpStream)
                try await mixer.startRunning()

                // 2. 連接（URL 不包含 stream key）
                print("正在連線到: \(twitchRTMPURL)")
                
                // 連線到 RTMP 伺服器
                try await rtmpConnection.connect(twitchRTMPURL)
                
                await MainActor.run {
                    statusLabel.text = "已連線，準備發布..."
                }
                
                // 等待連線完全建立
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 秒
                
                // 3. 發布（stream key 作為 stream name）
                print("正在發布串流: \(twitchStreamKey)")
                try await rtmpStream.publish(twitchStreamKey)
                
                await MainActor.run {
                    statusLabel.text = "直播中"
                    isStreaming = true
                    startButton.isEnabled = false
                    stopButton.isEnabled = true
                    stopButton.alpha = 1.0
                }
                
                // 4. 設置音訊混合（硬體+軟體）
                await setupAudioMixing()

                // 5. 開始發送數據 (啟動虛擬引擎，只處理視頻)
                await startVirtualDataFeeds()
                
            } catch {
                print("串流錯誤: \(error)")
                await MainActor.run {
                    statusLabel.text = "錯誤: \(error.localizedDescription)"
                    startButton.isEnabled = true
                    startButton.alpha = 1.0
                }
            }
        }
    }
    
    @objc func stopStreaming(_ sender: Any) {
        // 停止所有數據發送
        stopVirtualDataFeeds()

        Task {
            do {
                // 停止 MediaMixer
                try await mixer.stopRunning()

                // 關閉 RTMP 連接
                try await rtmpStream.close()
                try await rtmpConnection.close()
                await MainActor.run {
                    statusLabel.text = "已停止"
                    isStreaming = false
                    startButton.isEnabled = true
                    startButton.alpha = 1.0
                    stopButton.isEnabled = false
                    stopButton.alpha = 0.5
                }
            } catch {
                print("停止串流錯誤: \(error)")
                await MainActor.run {
                    statusLabel.text = "已停止"
                    isStreaming = false
                    startButton.isEnabled = true
                    startButton.alpha = 1.0
                    stopButton.isEnabled = false
                    stopButton.alpha = 0.5
                }
            }
        }
    }
    
    // MARK: - 3. 虛擬數據發送引擎 (核心部分)
    /*
    private func primeAudioEncoder() {
        let silentFrames = 1024
        let bytesPerFrame = 4 // Int16 * 2ch
        let silentData = Data(count: silentFrames * bytesPerFrame)

        let pts = CMTime(value: 0, timescale: 44100)

        if let sampleBuffer = createAudioSampleBuffer(data: silentData, presentationTime: pts) {
            Task { await rtmpStream.append(sampleBuffer) }
        }
    }
    */

    // 啟動虛擬數據流 (追趕式策略)
    private func startVirtualDataFeeds() async {
        // 音訊已經在 setupAudioMixing() 中通過 MediaMixer 處理
        // 這裡只處理視頻數據

        // 啟動本機音訊播放（讓用戶可以在本機聽到聲音）
        startLocalAudioPlayback()

        // --- 圖片輪播 ---
        imageRotationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.rotateImage()
            }
        }

        // --- 視頻發送任務 ---
        videoSendTask = Task {
            // 持續發送視頻幀以維持串流活躍
            while !Task.isCancelled {
                do {
                    guard let pixelBuffer = await MainActor.run(body: { self.currentPixelBuffer }) else {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                        continue
                    }

                    let presentationTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 1000)

                    if let sampleBuffer = self.createVideoSampleBuffer(pixelBuffer: pixelBuffer, presentationTime: presentationTime) {
                        await self.mixer.append(sampleBuffer)
                    }

                    // 每秒發送 30 幀
                    try await Task.sleep(nanoseconds: 33_333_333) // ~30fps
                } catch {
                    print("視頻發送錯誤: \(error)")
                    break
                }
            }
        }
    }
    
    // 啟動本機音訊播放（讓用戶可以在本機聽到聲音）
    private func startLocalAudioPlayback() {
        guard !audioData.isEmpty else {
            print("⚠️ 沒有音訊數據，無法播放")
            return
        }
        
        do {
            // 動態檢測並設定輸出路由
            let session = AVAudioSession.sharedInstance()
            
            // 檢查當前輸出路由，判斷是否有藍牙或耳機連接
            let currentRoute = session.currentRoute
            var hasBluetooth = false
            var hasHeadphones = false
            
            for output in currentRoute.outputs {
                switch output.portType {
                case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
                    hasBluetooth = true
                    print("🎧 檢測到藍牙設備: \(output.portName)")
                case .headphones, .headsetMic:
                    hasHeadphones = true
                    print("🎧 檢測到耳機: \(output.portName)")
                default:
                    break
                }
            }
            
            // 根據連接的設備動態設定輸出路由
            if hasBluetooth {
                // 有藍牙時，不使用強制揚聲器，讓系統自動路由到藍牙
                try session.overrideOutputAudioPort(.none)
                print("🔊 輸出路由：藍牙設備")
            } else if hasHeadphones {
                // 有耳機時，使用耳機
                try session.overrideOutputAudioPort(.none)
                print("🔊 輸出路由：耳機")
            } else {
                // 沒有藍牙或耳機時，使用揚聲器
                try session.overrideOutputAudioPort(.speaker)
                print("🔊 輸出路由：內建揚聲器")
            }
            
            // 創建 AVAudioEngine 用於本機播放
            let engine = AVAudioEngine()
            let playerNode = AVAudioPlayerNode()
            
            // 使用引擎的輸出節點格式，確保格式匹配
            let outputNode = engine.mainMixerNode
            _ = outputNode.outputFormat(forBus: 0)
            
            // 設定音訊格式：使用原始 WAV 格式（取樣率和聲道數），但轉換為 Float32（AVAudioEngine 需要）
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                             sampleRate: audioSampleRate, 
                                             channels: audioChannels, 
                                             interleaved: false) else {
                print("❌ 無法創建音訊格式")
                return
            }
            
            engine.attach(playerNode)
            engine.connect(playerNode, to: outputNode, format: format)
            
            try engine.start()
            playerNode.play()
            
            self.audioEngine = engine
            self.audioPlayerNode = playerNode
            
            // 開始播放音訊（循環播放）
            scheduleAudioPlayback()
            
            print("🔊 本機音訊播放已啟動")
        } catch {
            print("❌ 無法啟動本機音訊播放: \(error)")
        }
    }
    
    // 排程音訊播放（循環播放）
    private func scheduleAudioPlayback() {
        guard let playerNode = audioPlayerNode,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                         sampleRate: audioSampleRate, 
                                         channels: audioChannels, 
                                         interleaved: false) else {
            return
        }
        
        // 將 Int16 音訊數據轉換為 Float32
        let bytesPerSample = 2 // Int16 = 2 bytes
        let frameCount = audioData.count / (bytesPerSample * Int(audioChannels)) // 考慮聲道數
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        // 將 Int16 數據轉換為 Float32（支援立體聲）
        if let floatChannelData = buffer.floatChannelData {
            audioData.withUnsafeBytes { ptr in
                guard let int16Ptr = ptr.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
                
                let channelCount = Int(audioChannels)
                if channelCount == 1 {
                    // 單聲道
                    let floatPtr = floatChannelData[0]
                    for i in 0..<frameCount {
                        floatPtr[i] = Float(int16Ptr[i]) / 32768.0
                    }
                } else {
                    // 立體聲或多聲道（交錯格式：L, R, L, R, ...）
                    for ch in 0..<channelCount {
                        let floatPtr = floatChannelData[ch]
                        for i in 0..<frameCount {
                            let sampleIndex = i * channelCount + ch
                            floatPtr[i] = Float(int16Ptr[sampleIndex]) / 32768.0
                        }
                    }
                }
            }
        }
        
        // 排程播放，完成後循環
        playerNode.scheduleBuffer(buffer) { [weak self] in
            // 循環播放
            DispatchQueue.main.async {
                self?.scheduleAudioPlayback()
            }
        }
    }
    
    private func stopVirtualDataFeeds() {
        // 取消所有任務
        videoTimer?.invalidate()
        videoSendTask?.cancel()
        imageRotationTimer?.invalidate()

        // 清理資源
        videoTimer = nil
        videoSendTask = nil
        imageRotationTimer = nil

        // 停止音訊服務
        Task {
            if currentAudioMode == .microphoneOnly || currentAudioMode == .both {
                await audioSourceService.stopRunning()
            }
            if currentAudioMode == .wavOnly || currentAudioMode == .both {
                await wavAudioSourceService.stopRunning()
            }
        }

        // 停止本機音訊播放
        audioPlayerNode?.stop()
        audioEngine?.stop()
        audioPlayerNode = nil
        audioEngine = nil
        print("🔇 本機音訊播放已停止")
    }
    
    // MARK: - 4. 輔助功能：圖片輪播與轉換
    
    private func rotateImage() {
        guard !images.isEmpty else { return }
        currentImageIndex = (currentImageIndex + 1) % images.count
        updateCurrentPixelBuffer()
        
        // 更新本地預覽
        DispatchQueue.main.async {
            self.previewLayer?.contents = self.images[self.currentImageIndex].cgImage
        }
    }
    
    private func updateCurrentPixelBuffer() {
        guard !images.isEmpty else { return }
        let image = images[currentImageIndex]
        // 將 UIImage 轉為 CVPixelBuffer (這是編碼器看得懂的格式)
        self.currentPixelBuffer = buffer(from: image)
    }

    // MARK: - 5. 輔助功能：數據發送實作
    
    // 使用 AudioSourceService 後，不需要手動創建音訊 buffer
    // AudioSourceService 會自動處理音訊捕獲和緩衝區管理

    /*
    private let audioFramesPerPacket = 1024

    private func sendNextAudioChunk() {
        guard !audioData.isEmpty else { return }

        let bytesPerFrame = 4 // Int16 * 2ch
        let chunkSize = audioFramesPerPacket * bytesPerFrame

        var chunk: Data

        if audioOffset + chunkSize > audioData.count {
            let remaining = audioData.count - audioOffset
            chunk = audioData.subdata(in: audioOffset..<audioData.count)
            let needed = chunkSize - remaining
            if needed > 0 {
                chunk.append(audioData.prefix(needed))
            }
            audioOffset = needed
        } else {
            chunk = audioData.subdata(in: audioOffset..<(audioOffset + chunkSize))
            audioOffset += chunkSize
        }

        let pts = audioPresentationTimeStamp

        if let sampleBuffer = createAudioSampleBuffer(data: chunk, presentationTime: pts) {
            Task { await rtmpStream.append(sampleBuffer) }

            let duration = CMTime(value: CMTimeValue(audioFramesPerPacket), timescale: 44100)
            audioPresentationTimeStamp = pts + duration
        }
    }

    private func sendLiveAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) async {
        // 將 AVAudioPCMBuffer 轉換為適合 RTMP 串流的格式
        // 將 AVAudioTime 轉換為 CMTime
        let presentationTime = CMTime(seconds: AVAudioTime.seconds(forHostTime: time.hostTime), preferredTimescale: 44100)

        guard let audioBuffer = createAudioSampleBuffer(from: buffer, presentationTime: presentationTime) else {
            return
        }

        await rtmpStream.append(audioBuffer)
    }
    */

    /*
    func createAudioSampleBuffer(from buffer: AVAudioPCMBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        // 將 Float32 數據轉換為 Int16
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // 準備 Int16 數據緩衝區
        var int16Data = [Int16](repeating: 0, count: frameCount * channelCount)

        if let floatData = buffer.floatChannelData {
            for frame in 0..<frameCount {
                for channel in 0..<channelCount {
                    let floatSample = floatData[channel][frame]
                    // 將 Float32 (-1.0...1.0) 轉換為 Int16 (-32768...32767)
                    let int16Sample = Int16(max(-32768, min(32767, floatSample * 32767)))
                    int16Data[frame * channelCount + channel] = int16Sample
                }
            }
        }

        // 將 Int16 數據轉換為 Data
        let data = int16Data.withUnsafeBytes { Data($0) }

        // 使用現有的方法創建 CMSampleBuffer
        return createAudioSampleBuffer(data: data, presentationTime: presentationTime)
    }
    */


    // MARK: - 6. 底層轉換 (Boilerplate Code)
    
    // UIImage -> CVPixelBuffer
    func buffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    // CVPixelBuffer -> Video CMSampleBuffer
    func createVideoSampleBuffer(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        
        var videoInfo: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
        
        guard let videoFormat = videoInfo else { return nil }
        
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoFormat, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)
        
        return sampleBuffer
    }
    
    /*
    func createAudioSampleBuffer(data: Data, presentationTime: CMTime) -> CMSampleBuffer? {

        let bytesPerFrame = 4 // Int16 * 2ch
        let numFrames = data.count / bytesPerFrame

        var blockBuffer: CMBlockBuffer?
        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == kCMBlockBufferNoErr, let bb = blockBuffer else {
            return nil
        }

        data.withUnsafeBytes {
            CMBlockBufferReplaceDataBytes(
                with: $0.baseAddress!,
                blockBuffer: bb,
                offsetIntoDestination: 0,
                dataLength: data.count
            )
        }

        // ✅ ASBD（不要 ChannelLayout）
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(bytesPerFrame),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(bytesPerFrame),
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var formatDesc: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil, // ❗️一定要 nil
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )

        guard let fmt = formatDesc else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: CMTimeValue(numFrames), timescale: 44100),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: bb,
            formatDescription: fmt,
            sampleCount: numFrames,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }
    */

    // AVAudioPCMBuffer -> Audio CMSampleBuffer
    func createAudioSampleBuffer(from buffer: AVAudioPCMBuffer, time: AVAudioTime) async -> CMSampleBuffer? {
        // 直接使用buffer，不進行標準化
        let normalizedBuffer = buffer

        guard let format = normalizedBuffer.format as? AVAudioFormat else { return nil }

        // 創建音訊格式描述
        var audioFormatDesc: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: format.streamDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &audioFormatDesc
        )

        guard status == noErr, let formatDesc = audioFormatDesc else { return nil }

        // 創建音訊數據塊
        let dataSize = Int(normalizedBuffer.frameLength * normalizedBuffer.format.streamDescription.pointee.mBytesPerFrame)
        guard let blockBuffer = try? CMBlockBuffer(length: dataSize) else { return nil }

        // 複製音訊數據 - 現在我們知道是16-bit格式
        if let channelData = normalizedBuffer.int16ChannelData {
            let ptr = UnsafeRawPointer(channelData)
            CMBlockBufferReplaceDataBytes(
                with: ptr,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: dataSize
            )
        }

        // 創建時間戳 - 使用 48000Hz
        let sampleTime = CMTime(value: CMTimeValue(time.sampleTime), timescale: 48000)
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: CMTimeValue(normalizedBuffer.frameLength), timescale: 48000),
            presentationTimeStamp: sampleTime,
            decodeTimeStamp: .invalid
        )

        // 創建樣本緩衝區
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: CMItemCount(normalizedBuffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }


    private func mixAudioStreams() async {
        // 雙聲道模式：同時啟動麥克風和WAV來源，HaishinKit會處理混合

        // 同時啟動兩個音訊來源
        await audioSourceService.startRunning()
        await wavAudioSourceService.startRunning()

        await withTaskGroup(of: Void.self) { group in
            // 麥克風處理任務
            group.addTask {
                for await (buffer, time) in await self.audioSourceService.buffer {
                    // 直接發送原始buffer，讓HaishinKit處理格式轉換
                    await self.mixer.append(buffer, when: time)
                    print("🎙️ 麥克風音訊 buffer: \(buffer.frameLength) 幀")
                }
            }

            // WAV處理任務
            group.addTask {
                for await (buffer, time) in await self.wavAudioSourceService.buffer {
                    // WAV 已經是正確格式，直接發送
                    await self.mixer.append(buffer, when: time)
                    print("🎵 WAV 音訊 buffer: \(buffer.frameLength) 幀")
                }
            }
        }
    }


    // MARK: - Audio Mixing Setup (硬體+軟體混合)

    private func setupAudioMixing() async {
        do {
            // 1. 硬體輸入：attach 麥克風到 MediaMixer
            if currentAudioMode == .microphoneOnly || currentAudioMode == .both {
                guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                    print("❌ 找不到音訊裝置")
                    return
                }

                try await mixer.attachAudio(audioDevice)
                print("🎙️ 已將麥克風掛載為硬體輸入 (軌道 0)")
            }

            // 2. 軟體輸入：啟動 WAV 播放並發送到 MediaMixer
            if currentAudioMode == .wavOnly || currentAudioMode == .both {
                await wavAudioSourceService.startRunning()

                // 在背景任務中持續發送 WAV buffer 到軌道 1
                Task {
                    for await (buffer, time) in await wavAudioSourceService.buffer {
                        await mixer.append(buffer, when: time, track: 1)
                        print("🎵 WAV buffer 已發送到軟體軌道 1: \(buffer.frameLength) 幀")
                    }
                }
                print("🎵 已啟動 WAV 播放作為軟體輸入 (軌道 1)")
            }

            // 3. 配置音訊混合設置
            var audioMixerSettings = await mixer.audioMixerSettings

            // 設置主軌道
            if currentAudioMode == .microphoneOnly {
                audioMixerSettings.mainTrack = 0  // 麥克風作為主軌道
            } else if currentAudioMode == .wavOnly {
                audioMixerSettings.mainTrack = 1  // WAV 作為主軌道
            } else if currentAudioMode == .both {
            }

            // 設置軌道音量
            if currentAudioMode == .both {
                audioMixerSettings.tracks[0]?.volume = 1.0  // 麥克風音量 100%
                audioMixerSettings.tracks[1]?.volume = 0.7  // WAV 音量 70%
            }

            await mixer.setAudioMixerSettings(audioMixerSettings)
            print("⚙️ 音訊混合設置完成 - 主軌道: \(audioMixerSettings.mainTrack)")

        } catch {
            print("❌ 音訊混合設置失敗: \(error)")
        }
    }

    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}

// WAVAudioSourceService - 用於播放 WAV 檔案的音訊來源服務
actor WAVAudioSourceService {
    var buffer: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)> {
        AsyncStream { continuation in
            bufferContinuation = continuation
        }
    }

    private var audioData: Data
    private var sampleRate: Double
    private var channels: UInt32
    private var audioOffset: Int = 0
    private var bufferContinuation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation?
    private var tasks: [Task<Void, Swift.Error>] = []
    private var isRunning = false

    init(audioData: Data, sampleRate: Double, channels: UInt32) {
        self.audioData = audioData
        self.sampleRate = sampleRate
        self.channels = channels
    }

    func startRunning() async {
        guard !isRunning && !audioData.isEmpty else { return }

        isRunning = true
        audioOffset = 0 // 重置播放位置

        tasks.append(Task {
            let framesPerBuffer = 1024.0
            let interval = UInt64(framesPerBuffer / sampleRate * 1_000_000_000) // 納秒

            while !Task.isCancelled && self.isRunning {
                await self.sendNextChunk()
                // 使用更精確的時間間隔來避免音訊不同步
                try await Task.sleep(nanoseconds: interval)
            }
        })
    }

    func stopRunning() async {
        isRunning = false
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
        audioOffset = 0
    }

    private func sendNextChunk() async {
        let framesPerPacket = 1024
        let bytesPerSample: Int = 2 // Int16
        let bytesPerFrame = bytesPerSample * Int(channels)
        let chunkSize = framesPerPacket * bytesPerFrame

        guard !audioData.isEmpty else { return }

        // 簡單循環：如果超過數據長度，從頭開始
        if audioOffset >= audioData.count {
            audioOffset = 0
            print("🔄 WAV 循環播放：從頭開始")
        }

        // 確保我們有足夠的數據
        let availableData = min(chunkSize, audioData.count - audioOffset)
        var chunk = audioData.subdata(in: audioOffset..<(audioOffset + availableData))

        // 如果數據不夠，補充從頭開始的數據
        if chunk.count < chunkSize {
            let needed = chunkSize - chunk.count
            chunk.append(audioData.prefix(needed))
        }

        audioOffset = (audioOffset + availableData) % audioData.count

        guard chunk.count == chunkSize else { return }

        // 創建 AVAudioPCMBuffer，使用 16-bit 整數格式匹配我們的數據
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                       sampleRate: sampleRate,
                                       channels: channels,
                                       interleaved: true),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                          frameCapacity: AVAudioFrameCount(framesPerPacket)) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(framesPerPacket)

        // 直接複製 Int16 數據到 buffer
        chunk.withUnsafeBytes { ptr in
            guard let sourcePtr = ptr.baseAddress?.assumingMemoryBound(to: Int16.self),
                  let destPtr = buffer.int16ChannelData?[0] else { return }

            // 對於交織格式，直接複製整個塊
            memcpy(destPtr, sourcePtr, chunk.count)
        }

        // 使用樣本時間創建 AVAudioTime，這對於音訊同步很重要
        let sampleTime = AVAudioFramePosition(audioOffset / bytesPerFrame)
        let audioTime = AVAudioTime(sampleTime: sampleTime, atRate: sampleRate)

        bufferContinuation?.yield((buffer, audioTime))
        print("🎵 WAV chunk 發送: offset=\(audioOffset), size=\(chunk.count), pts=\(audioTime.sampleTime ?? 0)")
    }
}
