import Flutter
import UIKit
import AVFoundation
import CommonCrypto
import CoreMotion

@main
@objc class AppDelegate: FlutterAppDelegate, AVSpeechSynthesizerDelegate, FlutterStreamHandler {

  private let channelName       = "com.aetherscan.pro/audio"
  private let sensorChannelName = "com.aetherscan.pro/sensors"
  private let licenseKey        = "aetherscan_pro_license"
  private let synth             = AVSpeechSynthesizer()
  private var audioPlayer       : AVAudioPlayer?
  private var staticPlayer      : AVAudioPlayer?
  private var isStaticPlaying   = false
  private var channelRegistered = false
  private var masterVolume      : Float = 0.85

  // Sensori
  private let motionManager     = CMMotionManager()
  private var sensorEventSink   : FlutterEventSink?
  private var lastProximityNear = false
  private var emfBaseline       : Double = -1
  private var emfSpikeActive    = false

  // Rilevamento tocco / sfioramento (anti-falsi positivi impugnatura)
  private var lastGravityX: Double = 0.0
  private var lastGravityY: Double = 0.0
  private var lastGravityZ: Double = -1.0
  private var lastTouchTriggerTime: TimeInterval = 0

  private func scaledMasterGain() -> Float {
    if self.masterVolume < 0.05 { return 0.0 }
    let v = Double(self.masterVolume)
    return Float(max(0.0, min(1.0, v * v)))
  }

  private func log(_ msg: String) { NSLog("[AETHER] %@", msg) }

  // ──────────────────────────────────────────────────────────────────
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    synth.delegate = self
    UIApplication.shared.isIdleTimerDisabled = true
    setupAudioSession()

    registerChannel()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onAppBecameActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    return result
  }

  @objc private func onAppBecameActive() {
    UIApplication.shared.isIdleTimerDisabled = true
    registerChannel()
  }

  public func registerChannelIfNeeded() { registerChannel() }

  private func registerChannel() {
    guard !channelRegistered else { return }
    var flutterVC: FlutterViewController?

    if let vc = window?.rootViewController as? FlutterViewController {
      flutterVC = vc
    } else {
      for scene in UIApplication.shared.connectedScenes {
        if let ws = scene as? UIWindowScene {
          for w in ws.windows {
            if let vc = w.rootViewController as? FlutterViewController {
              flutterVC = vc
              break
            }
          }
        }
        if flutterVC != nil { break }
      }
    }

    if let vc = flutterVC {
      setupChannels(with: vc)
    } else {
      log("window non ancora pronta - attendo sceneDidBecomeActive / retry")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.registerChannel()
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  private let sensorQueue: OperationQueue = {
    let q = OperationQueue()
    q.name = "com.aetherscan.pro.sensors"
    q.qualityOfService = .userInteractive
    q.maxConcurrentOperationCount = 2
    return q
  }()

  public func setupChannels(with vc: FlutterViewController) {
    guard !channelRegistered else { return }
    channelRegistered = true
    log("setupChannels: MethodChannel + EventChannel registrati con successo!")

    // ── MethodChannel ──
    let ch = FlutterMethodChannel(name: channelName, binaryMessenger: vc.binaryMessenger)
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {

      case "getDeviceHwid":
        result(self.computeHwid())

      case "getSavedLicense":
        // App 100% gratuita e offline standalone
        result("FREE_OFFLINE_STANDALONE")

      case "saveLicense":
        result(true)

      case "setVolume":
        let vol = (call.arguments as? [String: Any])?["volume"] as? Double ?? 0.85
        self.masterVolume = Float(max(0.0, min(1.0, vol)))
        self.staticAudioEngine?.mainMixerNode.outputVolume = self.scaledMasterGain()
        result(true)

      case "speak":
        let args = call.arguments as? [String: Any]
        let text   = args?["text"] as? String ?? ""
        let vol    = (args?["volume"] as? Double).map { Float($0) } ?? 1.0
        let gender = args?["gender"] as? String ?? "female"
        let effectiveVol = max(0.0, min(1.0, vol * self.masterVolume))
        self.log("speak -> \"\(text)\" gender=\(gender) vol=\(effectiveVol)")
        self.speak(text: text, vol: effectiveVol, gender: gender)
        result(true)

      case "playBeep":
        let args = call.arguments as? [String: Any]
        let hz = args?["freq"] as? Int ?? 880
        let ms = args?["durationMs"] as? Int ?? 100
        self.playTone(hz: hz, ms: ms)
        result(true)

      case "playChime":
        self.playChime()
        result(true)

      case "playProximityAlert":
        self.playProximityAlert()
        result(true)

      case "playEmfAlert":
        self.playEmfAlert()
        result(true)

      case "setWakeLock":
        let on = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? true
        DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = on }
        result(true)

      case "openUrl":
        guard let s = (call.arguments as? [String: Any])?["url"] as? String,
              let u = URL(string: s) else { result(false); return }
        DispatchQueue.main.async { UIApplication.shared.open(u) }
        result(true)

      case "audioDiagnostic":
        result(self.buildDiagnostic())

      case "startStatic":
        if let vol = (call.arguments as? [String: Any])?["volume"] as? Double {
          self.masterVolume = Float(max(0.0, min(1.0, vol)))
        }
        self.startRadioStatic()
        result(true)

      case "stopStatic":
        self.stopRadioStatic()
        result(true)

      case "updateStaticParams":
        let args     = call.arguments as? [String: Any]
        let dEmf     = args?["emfDelta"] as? Double ?? 0.0
        let accel    = args?["accel"]    as? Double ?? 0.0
        let zScore   = args?["zScore"]   as? Double ?? 0.0
        let pitchHz  = args?["pitchHz"]  as? Double ?? 800.0
        if let vol = args?["volume"] as? Double {
          self.masterVolume = Float(max(0.0, min(1.0, vol)))
          self.staticAudioEngine?.mainMixerNode.outputVolume = self.scaledMasterGain()
        }
        self.updateChaosParams(deltaEmf: dEmf, accel: accel, zScore: zScore, pitchHz: pitchHz)
        result(true)

      case "playModulatedStatic":
        // Alias legacy — reindirizza a updateChaosParams
        let args2    = call.arguments as? [String: Any]
        let coupling = args2?["coupling"] as? Double ?? 0.0
        let pitch2   = args2?["pitchHz"]  as? Double ?? 800.0
        self.updateChaosParams(deltaEmf: 0.0, accel: coupling, zScore: 0.0, pitchHz: pitch2)
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── MethodChannel (wakelock) ──
    let wakeCh = FlutterMethodChannel(name: "aetherscan/wakelock", binaryMessenger: vc.binaryMessenger)
    wakeCh.setMethodCallHandler { call, result in
      if call.method == "setWakeLock" {
        let on = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? true
        DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = on }
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // ── EventChannel (sensori) ──
    let sensorCh = FlutterEventChannel(name: sensorChannelName, binaryMessenger: vc.binaryMessenger)
    sensorCh.setStreamHandler(self)
  }

  // ──────────────────────────────────────────────────────────────────
  // FlutterStreamHandler
  // ──────────────────────────────────────────────────────────────────
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sensorEventSink = events
    startProximitySensor()
    startMagnetometer()
    startAccelerometer()
    log("Sensori avviati: prossimita + EMF + tocco (accelerometro)")
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopSensors()
    sensorEventSink = nil
    log("Sensori fermati")
    return nil
  }

  // ──────────────────────────────────────────────────────────────────
  // Sensore di Prossimita (Anteriore)
  // ──────────────────────────────────────────────────────────────────
  private func startProximitySensor() {
    UIDevice.current.isProximityMonitoringEnabled = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(proximityChanged),
      name: UIDevice.proximityStateDidChangeNotification,
      object: nil
    )
  }

  @objc private func proximityChanged() {
    let near = UIDevice.current.proximityState
    guard near != lastProximityNear else { return }
    lastProximityNear = near
    log("Prossimita: \(near ? "VICINO" : "LONTANO")")
    DispatchQueue.main.async {
      self.sensorEventSink?(["type": "proximity", "near": near])
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Sensore Accelerometro (Rilevamento Tocco / Contatto Posteriore e Frontale)
  // ──────────────────────────────────────────────────────────────────
  private func startAccelerometer() {
    guard motionManager.isAccelerometerAvailable else {
      log("Accelerometro non disponibile")
      return
    }
    motionManager.accelerometerUpdateInterval = 0.05 // 20 Hz
    motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
      guard let self = self, let data = data else { return }
      let alpha = 0.85
      self.lastGravityX = alpha * self.lastGravityX + (1.0 - alpha) * data.acceleration.x
      self.lastGravityY = alpha * self.lastGravityY + (1.0 - alpha) * data.acceleration.y
      self.lastGravityZ = alpha * self.lastGravityZ + (1.0 - alpha) * data.acceleration.z

      // data.acceleration è in g (1g = 9.80665 m/s²). Convertiamo in m/s² per uniformità fisica e metrologica
      let linearX = (data.acceleration.x - self.lastGravityX) * 9.80665
      let linearY = (data.acceleration.y - self.lastGravityY) * 9.80665
      let linearZ = (data.acceleration.z - self.lastGravityZ) * 9.80665
      let impulse = sqrt(linearX * linearX + linearY * linearY + linearZ * linearZ)

      // Invia flusso continuo di dinamica urto / vibrazione a Flutter
      self.sensorEventSink?([
        "type": "accel",
        "dynamic_magnitude": impulse,
        "x": linearX,
        "y": linearY,
        "z": linearZ
      ])

      // Soglia urto secco: 3.2 m/s²
      let now = Date().timeIntervalSince1970
      if impulse > 3.2 && (now - self.lastTouchTriggerTime > 2.0) {
        self.lastTouchTriggerTime = now
        self.log("TOUCH RILEVATO impulse=\(impulse)")
        self.sensorEventSink?(["type": "touch", "intensity": impulse])
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Magnetometro EMF
  // ──────────────────────────────────────────────────────────────────
  private func startMagnetometer() {
    if motionManager.isMagnetometerAvailable {
      motionManager.magnetometerUpdateInterval = 0.05 // 20 Hz
      motionManager.startMagnetometerUpdates(to: sensorQueue) { [weak self] data, _ in
        guard let self = self, let data = data else { return }
        let x = data.magneticField.x
        let y = data.magneticField.y
        let z = data.magneticField.z
        let magnitude = sqrt(x*x + y*y + z*z)

        if self.emfBaseline < 0 {
          self.emfBaseline = magnitude
        }
        let delta = abs(magnitude - self.emfBaseline)
        let isSpike = delta > 25.0
        self.emfBaseline = self.emfBaseline * 0.98 + magnitude * 0.02

        DispatchQueue.main.async {
          self.sensorEventSink?(["type": "emf", "value": magnitude, "delta": delta, "spike": isSpike])
        }
      }
      log("Magnetometro CoreMotion avviato su background queue a 20 Hz")
    } else if motionManager.isDeviceMotionAvailable {
      motionManager.deviceMotionUpdateInterval = 0.05
      motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: sensorQueue) { [weak self] motion, _ in
        guard let self = self, let motion = motion else { return }
        let field = motion.magneticField.field
        let magnitude = sqrt(field.x*field.x + field.y*field.y + field.z*field.z)
        if magnitude > 0 {
          if self.emfBaseline < 0 {
            self.emfBaseline = magnitude
          }
          let delta = abs(magnitude - self.emfBaseline)
          let isSpike = delta > 25.0
          DispatchQueue.main.async {
            self.sensorEventSink?(["type": "emf", "value": magnitude, "delta": delta, "spike": isSpike])
          }
        }
      }
      log("Fallback su DeviceMotion magnetico avviato")
    } else {
      log("ATTENZIONE: Nessun sensore magnetico disponibile")
    }
  }

  private func stopSensors() {
    UIDevice.current.isProximityMonitoringEnabled = false
    NotificationCenter.default.removeObserver(self, name: UIDevice.proximityStateDidChangeNotification, object: nil)
    motionManager.stopMagnetometerUpdates()
    motionManager.stopDeviceMotionUpdates()
    motionManager.stopAccelerometerUpdates()
  }

  // ──────────────────────────────────────────────────────────────────
  // Audio Session
  // ──────────────────────────────────────────────────────────────────
  private func setupAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
      try session.setActive(true)
      log("AudioSession .playback attiva con defaultToSpeaker e mixWithOthers")
    } catch {
      log("AudioSession errore: \(error.localizedDescription)")
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Radio Static Sweep Engine — Motore Caotico DSP (Logistic Map + Biquad IIR)
  // ZERO Double.random() — sintesi completamente deterministica basata sui sensori
  // ──────────────────────────────────────────────────────────────────
  private var staticAudioEngine : AVAudioEngine?
  private var staticSourceNode  : AVAudioSourceNode?

  // Parametri chaos aggiornati dai sensori (double: atomic su armv8)
  private var chaosDeltaEmf: Double = 0.0
  private var chaosAccel: Double    = 0.0
  private var chaosZScore: Double   = 0.0
  private var chaosPitchHz: Double  = 800.0

  private func startRadioStatic() {
    guard !isStaticPlaying else { return }
    isStaticPlaying = true
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let sampleRate = 22050.0
      guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

      // Stato oscillatore e filtro — catturati nel closure del render callback
      var logX: Double = 0.5
      var phase: Double = 0.0
      var tremoloPhase: Double = 0.0
      let dt = 1.0 / sampleRate
      var bqX1 = 0.0, bqX2 = 0.0, bqY1 = 0.0, bqY2 = 0.0
      var bqB0 = 1.0, bqB2 = -1.0, bqA1 = 0.0, bqA2 = 0.0

      func updateBiquad(_ cutHz: Double, _ q: Double) {
        let omega = 2.0 * Double.pi * cutHz / sampleRate
        let sinW = sin(omega), cosW = cos(omega)
        let alpha = sinW / (2.0 * q)
        let a0inv = 1.0 / (1.0 + alpha)
        bqB0 =  alpha * a0inv;  bqB2 = -alpha * a0inv
        bqA1 = -2.0 * cosW * a0inv;  bqA2 = (1.0 - alpha) * a0inv
      }

      let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
        guard let self = self else { return noErr }
        let ablPtr = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let dEmf  = self.chaosDeltaEmf, accel = self.chaosAccel
        let zScore = self.chaosZScore
        let baseCarrierHz = max(200.0, min(2000.0, self.chaosPitchHz))
        let rParam    = max(3.57, min(4.0, 3.72 + abs(dEmf) * 0.08))
        let coupling  = max(0.0, min(1.0, abs(zScore) / 4.0 + accel / 3.0))
        let emfShift  = dEmf * 120.0
        let cutoffHz  = max(200.0, min(3000.0, 800.0 + abs(zScore) * 280.0))
        let qFactor   = max(0.5, min(8.0, 1.0 + accel * 2.5))
        updateBiquad(cutoffHz, qFactor)
        let trRate    = max(0.5, min(6.0, 0.5 + abs(accel) * 2.5))
        let trDepth   = max(0.15, min(0.6, 0.15 + coupling * 0.45))
        for buffer in ablPtr {
          let buf = buffer.mData!.assumingMemoryBound(to: Float.self)
          for i in 0..<Int(frameCount) {
            logX = rParam * logX * (1.0 - logX)
            if logX.isNaN || logX.isInfinite { logX = 0.5 }
            let chaosRaw = logX * 2.0 - 1.0
            phase += (baseCarrierHz + emfShift) * dt
            if phase > 1e6 { phase -= 1e6 }
            let carrier = sin(2.0 * Double.pi * phase)
            tremoloPhase += trRate * dt
            if tremoloPhase > 1e6 { tremoloPhase -= 1e6 }
            let tremolo = 1.0 - trDepth * (0.5 + 0.5 * sin(2.0 * Double.pi * tremoloPhase))
            let mixed = (chaosRaw * (1.0 - coupling * 0.6) + carrier * coupling * 0.4) * tremolo
            let filtered = bqB0 * mixed + bqB2 * bqX2 - bqA1 * bqY1 - bqA2 * bqY2
            bqX2 = bqX1; bqX1 = mixed; bqY2 = bqY1; bqY1 = filtered
            buf[i] = Float(max(-1.0, min(1.0, filtered * 0.75)))
          }
        }
        return noErr
      }

      DispatchQueue.main.async {
        guard self.isStaticPlaying else { return }
        do {
          try? AVAudioSession.sharedInstance().setActive(true)
          let engine = AVAudioEngine()
          engine.attach(sourceNode)
          engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
          engine.mainMixerNode.outputVolume = self.scaledMasterGain()
          try engine.start()
          self.staticAudioEngine = engine
          self.staticSourceNode  = sourceNode
          self.log("startRadioStatic chaos -> engine avviato OK")
        } catch {
          self.log("startRadioStatic errore: \(error.localizedDescription)")
        }
      }
    }
  }

  private func stopRadioStatic() {
    isStaticPlaying = false
    DispatchQueue.main.async { [weak self] in
      self?.staticAudioEngine?.stop()
      self?.staticAudioEngine = nil
      self?.staticSourceNode  = nil
      self?.staticPlayer?.stop()
      self?.staticPlayer = nil
      self?.log("stopRadioStatic -> fermato")
    }
  }

  private func updateChaosParams(deltaEmf: Double, accel: Double, zScore: Double, pitchHz: Double) {
    chaosDeltaEmf = deltaEmf
    chaosAccel    = accel
    chaosZScore   = zScore
    chaosPitchHz  = pitchHz
  }

  // ──────────────────────────────────────────────────────────────────
  // TTS
  // ──────────────────────────────────────────────────────────────────
  private func speak(text: String, vol: Float, gender: String = "female") {
    try? AVAudioSession.sharedInstance().setActive(true)
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

    let utt = AVSpeechUtterance(string: text)
    let voices = AVSpeechSynthesisVoice.speechVoices()

    let wantedGender: AVSpeechSynthesisVoiceGender = gender == "male" ? .male : .female
    if let v = voices.first(where: { $0.language == "it-IT" && $0.gender == wantedGender }) {
      utt.voice = v; log("TTS voce: \(v.name) [\(gender)]")
    } else if let v = voices.first(where: { $0.language == "it-IT" }) {
      utt.voice = v; log("TTS voce fallback it-IT: \(v.name)")
    } else if let v = voices.first(where: { $0.language.hasPrefix("en") && $0.gender == wantedGender }) {
      utt.voice = v; log("TTS fallback en [\(gender)]: \(v.name)")
    } else if let v = voices.first(where: { $0.language.hasPrefix("en") }) {
      utt.voice = v; log("TTS fallback en: \(v.name)")
    } else {
      log("TTS: nessuna voce specifica, uso sistema")
    }
    utt.rate            = AVSpeechUtteranceDefaultSpeechRate * 0.85
    utt.pitchMultiplier = gender == "male" ? 0.80 : 1.10
    utt.volume          = max(0.1, min(1.0, vol))
    synth.speak(utt)
    log("TTS speak() eseguito, isSpeaking=\(synth.isSpeaking)")
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart _: AVSpeechUtterance)  { log("TTS STARTED") }
  func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) { log("TTS FINISHED") }
  func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) { log("TTS CANCELLED") }

  // ──────────────────────────────────────────────────────────────────
  // Diagnostica
  // ──────────────────────────────────────────────────────────────────
  private func buildDiagnostic() -> String {
    let session = AVAudioSession.sharedInstance()
    let route   = session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
    let voci    = AVSpeechSynthesisVoice.speechVoices()
                    .filter { $0.language.hasPrefix("it") }
                    .map { $0.name }.joined(separator: ", ")
    let saved   = UserDefaults.standard.string(forKey: licenseKey) ?? ""
    let report  = """
=== DIAGNOSTICA AETHERSCAN ===
Channel registrato: \(channelRegistered)
Audio categoria: \(session.category.rawValue)
Audio output: \(route.isEmpty ? "NESSUNO" : route)
Volume sistema: \(session.outputVolume)
Voci IT installate: \(voci.isEmpty ? "NESSUNA" : voci)
TTS in corso: \(synth.isSpeaking)
Licenza salvata: \(saved.isEmpty ? "NO" : "SI (\(saved.count) chars)")
Magnetometro (EMF): \(motionManager.isMagnetometerActive ? "ATTIVO" : "INATTIVO")
Sensore Tocco (Accel): \(motionManager.isAccelerometerActive ? "ATTIVO" : "INATTIVO")
EMF baseline: \(String(format: "%.1f", emfBaseline)) uT
"""
    log(report)
    return report
  }

  // ──────────────────────────────────────────────────────────────────
  // HWID
  // ──────────────────────────────────────────────────────────────────
  private func computeHwid() -> String {
    let raw = "IOS:\(UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN")"
    guard let data = raw.data(using: .utf8) else { return String(repeating: "0", count: 32) }
    var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    _ = data.withUnsafeBytes { CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  // ──────────────────────────────────────────────────────────────────
  // Beep / Chime / Alert suoni
  // ──────────────────────────────────────────────────────────────────
  private func playTone(hz: Int, ms: Int) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let sr  = 22050.0
      let n   = Int(sr * Double(ms) / 1000.0)
      var buf = [Int16]()
      buf.reserveCapacity(n)
      for i in 0..<n {
        let angle = 2.0 * Double.pi * Double(i) * Double(hz) / sr
        let env   = 1.0 - Double(i) / Double(n)
        buf.append(Int16(sin(angle) * Double(Int16.max) * 0.45 * env))
      }
      let pcm = buf.withUnsafeBufferPointer { Data(buffer: $0) }
      let wavData = self.buildWav(pcm: pcm, sampleRate: Int(sr))
      DispatchQueue.main.async {
        do {
          try? AVAudioSession.sharedInstance().setActive(true)
          self.audioPlayer = try AVAudioPlayer(data: wavData)
          self.audioPlayer?.volume = self.scaledMasterGain()
          self.audioPlayer?.prepareToPlay()
          let ok = self.audioPlayer?.play() ?? false
          self.log("playTone \(hz)Hz -> play()=\(ok)")
        } catch {
          self.log("playTone errore: \(error.localizedDescription)")
        }
      }
    }
  }

  private func playChime() {
    for (i, freq) in [650, 950, 1300].enumerated() {
      DispatchQueue.global(qos: .userInitiated)
        .asyncAfter(deadline: .now() + Double(i) * 0.085) {
          self.playTone(hz: freq, ms: 90)
        }
    }
  }

  func playProximityAlert() {
    for (i, freq) in [1200, 900, 1200, 900].enumerated() {
      DispatchQueue.global(qos: .userInitiated)
        .asyncAfter(deadline: .now() + Double(i) * 0.12) {
          self.playTone(hz: freq, ms: 80)
        }
    }
  }

  func playEmfAlert() {
    for (i, freq) in [200, 220, 200].enumerated() {
      DispatchQueue.global(qos: .userInitiated)
        .asyncAfter(deadline: .now() + Double(i) * 0.18) {
          self.playTone(hz: freq, ms: 150)
        }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // WAV builder
  // ──────────────────────────────────────────────────────────────────
  private func buildWav(pcm: Data, sampleRate: Int) -> Data {
    let channels    = 1
    let bitsPerSamp = 16
    let byteRate    = sampleRate * channels * bitsPerSamp / 8
    let blockAlign  = channels * bitsPerSamp / 8
    let dataSize    = pcm.count
    let chunkSize   = 36 + dataSize

    var wav = Data()
    wav.append(contentsOf: [UInt8]("RIFF".utf8))
    wav.append(contentsOf: le32(chunkSize))
    wav.append(contentsOf: [UInt8]("WAVE".utf8))
    wav.append(contentsOf: [UInt8]("fmt ".utf8))
    wav.append(contentsOf: le32(16))
    wav.append(contentsOf: le16(1))
    wav.append(contentsOf: le16(channels))
    wav.append(contentsOf: le32(sampleRate))
    wav.append(contentsOf: le32(byteRate))
    wav.append(contentsOf: le16(blockAlign))
    wav.append(contentsOf: le16(bitsPerSamp))
    wav.append(contentsOf: [UInt8]("data".utf8))
    wav.append(contentsOf: le32(dataSize))
    wav.append(pcm)
    return wav
  }

  private func le32(_ v: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt32(v).littleEndian) { Array($0) }
  }
  private func le16(_ v: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt16(v).littleEndian) { Array($0) }
  }
}

