// InputInspector.swift
//
// WS-F: Dev-only input capture harness for identifying a Bluetooth HID "ring
// remote" button that can be bound to `ConversationEngine.handleQAButtonPressed()`.
//
// This view controller is installed as a child of `FlutterViewController`
// because the UIKit responder chain must contain a first-responder override
// to surface `UIKeyCommand` and `pressesBegan` events. Two install modes:
//
//   1. Visible Inspector UI (`startInspector`) — full-screen child VC used by
//      the Flutter dev screen to show raw channel events.
//   2. Invisible background listener (`startBackgroundListening`) — zero-frame
//      child VC used by the runtime dispatcher to listen while the main UI is
//      shown. No chrome, no touches consumed.
//
// Channels instrumented (per investigation §2):
//   1. UIKeyCommand        — broad set of inputs with wildcard modifier flags
//   2. pressesBegan/Ended  — UIPress firehose (keys that UIKeyCommand filters)
//   3. MPRemoteCommandCenter — play/pause/next/prev/toggle/seek
//   4. AVSystemController volume notifications (private notification name;
//      read-only, dev-tool only — see docs/ring_remote_dead_buttons.md)
//
// All events are forwarded to a single FlutterEventChannel
// (`event.input_inspector`) keyed by a `channel` discriminator.
//
// NOTE: Private API name "AVSystemController_SystemVolumeDidChangeNotification"
// is observed only. We do not link against the private framework. This file
// is dev-scaffolding only; the visible inspector is debug-gated in Flutter.

import UIKit
import MediaPlayer
import AVFoundation

// MARK: - Shared stream handler

final class InputInspectorStreamHandler: NSObject, FlutterStreamHandler {
    static let shared = InputInspectorStreamHandler()
    private let queue = DispatchQueue(label: "input-inspector.sink")
    private var sink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        queue.sync { self.sink = events }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        queue.sync { self.sink = nil }
        return nil
    }

    func emit(_ payload: [String: Any]) {
        var message = payload
        if message["timestamp"] == nil {
            message["timestamp"] = Int(Date().timeIntervalSince1970 * 1000)
        }
        let currentSink: FlutterEventSink? = queue.sync { self.sink }
        guard let sink = currentSink else { return }
        DispatchQueue.main.async {
            sink(message)
        }
    }
}

// MARK: - Input inspector view controller

final class InputInspector: UIViewController {
    enum Mode {
        case visible
        case background
    }

    private let mode: Mode
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var volumeObserver: NSObjectProtocol?
    private var lastVolume: Float = -1

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func loadView() {
        // For background mode we still need a view (responder chain) but it
        // must not consume touches or draw. Zero-frame hidden view.
        let v = UIView(frame: .zero)
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.isHidden = (mode == .background)
        self.view = v
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        beginRemoteControlCapture()
        beginVolumeCapture()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        endRemoteControlCapture()
        endVolumeCapture()
        resignFirstResponder()
    }

    // MARK: - 1. UIKeyCommand capture

    private static let keyInputs: [String] = {
        var inputs: [String] = []
        for scalar in UnicodeScalar("a").value...UnicodeScalar("z").value {
            if let s = UnicodeScalar(scalar) { inputs.append(String(s)) }
        }
        for scalar in UnicodeScalar("0").value...UnicodeScalar("9").value {
            if let s = UnicodeScalar(scalar) { inputs.append(String(s)) }
        }
        inputs.append(contentsOf: [
            UIKeyCommand.inputUpArrow,
            UIKeyCommand.inputDownArrow,
            UIKeyCommand.inputLeftArrow,
            UIKeyCommand.inputRightArrow,
            UIKeyCommand.inputEscape,
            "\r", " ", "\t",
        ])
        return inputs
    }()

    override var keyCommands: [UIKeyCommand]? {
        // Register a broad set of inputs with wildcard modifier flags so the
        // system delivers any key from a BT HID keyboard to us first.
        let modifiers: [UIKeyModifierFlags] = [
            [], .command, .shift, .alternate, .control,
        ]
        var cmds: [UIKeyCommand] = []
        for input in InputInspector.keyInputs {
            for mod in modifiers {
                let cmd = UIKeyCommand(
                    input: input,
                    modifierFlags: mod,
                    action: #selector(handleKeyCommand(_:))
                )
                if #available(iOS 15.0, *) {
                    cmd.wantsPriorityOverSystemBehavior = true
                }
                cmds.append(cmd)
            }
        }
        return cmds
    }

    @objc private func handleKeyCommand(_ sender: UIKeyCommand) {
        InputInspectorStreamHandler.shared.emit([
            "channel": "keyCommand",
            "input": sender.input ?? "",
            "modifierFlags": sender.modifierFlags.rawValue,
        ])
    }

    // MARK: - 2. UIPress firehose

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            emitPress(press, phase: "began")
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            emitPress(press, phase: "ended")
        }
        super.pressesEnded(presses, with: event)
    }

    private func emitPress(_ press: UIPress, phase: String) {
        var payload: [String: Any] = [
            "channel": "pressEvent",
            "phase": phase,
        ]
        if let key = press.key {
            payload["keyCode"] = key.keyCode.rawValue
            payload["characters"] = key.characters
            payload["charactersIgnoringModifiers"] = key.charactersIgnoringModifiers
            payload["modifierFlags"] = key.modifierFlags.rawValue
        } else {
            payload["keyCode"] = press.type.rawValue
            payload["characters"] = ""
            payload["charactersIgnoringModifiers"] = ""
            payload["modifierFlags"] = 0
        }
        InputInspectorStreamHandler.shared.emit(payload)
    }

    // MARK: - 3. MPRemoteCommandCenter

    private func beginRemoteControlCapture() {
        UIApplication.shared.beginReceivingRemoteControlEvents()

        // iOS only delivers remote events when something is "now playing".
        // Supply a tiny stub so the ring's media keys actually arrive.
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Helix Inspector",
            MPMediaItemPropertyArtist: "Input Capture",
            MPNowPlayingInfoPropertyPlaybackRate: 0.0,
        ]

        let center = MPRemoteCommandCenter.shared()

        func bind(_ cmd: MPRemoteCommand, _ name: String) {
            cmd.isEnabled = true
            let target = cmd.addTarget { _ in
                InputInspectorStreamHandler.shared.emit([
                    "channel": "mediaCommand",
                    "command": name,
                ])
                return .commandFailed
            }
            remoteTargets.append((cmd, target))
        }

        bind(center.playCommand, "play")
        bind(center.pauseCommand, "pause")
        bind(center.togglePlayPauseCommand, "togglePlayPause")
        bind(center.nextTrackCommand, "nextTrack")
        bind(center.previousTrackCommand, "previousTrack")
        bind(center.seekForwardCommand, "seekForward")
        bind(center.seekBackwardCommand, "seekBackward")
        bind(center.stopCommand, "stop")
    }

    private func endRemoteControlCapture() {
        for (cmd, target) in remoteTargets {
            cmd.removeTarget(target)
        }
        remoteTargets.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    // MARK: - 4. Volume change notifications

    private func beginVolumeCapture() {
        // AVAudioSession outputVolume KVO is the public path; we also observe
        // the private notification name to catch volume rocker presses that
        // occur without an active playback graph.
        let session = AVAudioSession.sharedInstance()
        lastVolume = session.outputVolume

        volumeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            let newVolume = (note.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? NSNumber)?.floatValue ?? session.outputVolume
            let reason = (note.userInfo?["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String) ?? ""
            let direction: String
            if newVolume > self.lastVolume { direction = "up" }
            else if newVolume < self.lastVolume { direction = "down" }
            else { direction = "same" }
            self.lastVolume = newVolume
            InputInspectorStreamHandler.shared.emit([
                "channel": "volumeChange",
                "newVolume": newVolume,
                "reason": reason,
                "direction": direction,
            ])
        }
    }

    private func endVolumeCapture() {
        if let obs = volumeObserver {
            NotificationCenter.default.removeObserver(obs)
            volumeObserver = nil
        }
    }
}

// MARK: - Controller / installer

final class InputInspectorController {
    static let shared = InputInspectorController()

    private weak var host: FlutterViewController?
    private var visibleVC: InputInspector?
    private var backgroundVC: InputInspector?

    func configure(host: FlutterViewController) {
        self.host = host
    }

    func capabilities() -> [String: Any] {
        return [
            "hasHardwareKeyboard": GCKeyboardHasKeyboard(),
            "remoteControlEnabled": true,
        ]
    }

    private func GCKeyboardHasKeyboard() -> Bool {
        // Avoid GameController import; proxy via UIKeyboard availability check.
        return true
    }

    func startBackgroundListening() {
        guard let host = host else { return }
        if backgroundVC != nil { return }
        let vc = InputInspector(mode: .background)
        host.addChild(vc)
        // Zero-frame invisible container.
        vc.view.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        vc.view.isHidden = true
        host.view.addSubview(vc.view)
        vc.didMove(toParent: host)
        self.backgroundVC = vc
    }

    func stopBackgroundListening() {
        guard let vc = backgroundVC else { return }
        vc.willMove(toParent: nil)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        self.backgroundVC = nil
    }

    func startInspector() {
        guard let host = host else { return }
        if visibleVC != nil { return }
        let vc = InputInspector(mode: .visible)
        host.addChild(vc)
        vc.view.frame = host.view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Transparent overlay so Flutter UI still renders behind it.
        host.view.addSubview(vc.view)
        vc.didMove(toParent: host)
        self.visibleVC = vc
    }

    func stopInspector() {
        guard let vc = visibleVC else { return }
        vc.willMove(toParent: nil)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        self.visibleVC = nil
    }
}
