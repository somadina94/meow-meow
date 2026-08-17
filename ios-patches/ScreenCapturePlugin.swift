import Foundation
import Capacitor
import UIKit

/**
 * ScreenCapturePlugin
 *
 * Bridges iOS screenshot + screen-recording events to JavaScript so the
 * web layer can react (blur the UI, toast the user, write an audit log).
 *
 * iOS does NOT allow blocking screenshots (Apple App Store policy).
 * This plugin only DETECTS — the JS hook `useIOSCaptureGuard` handles the
 * UX response (blur overlay while recording, toast on screenshot).
 *
 * INSTALLATION (one-time, after `npx cap add ios`):
 *   1. Copy this file to: ios/App/App/ScreenCapturePlugin.swift
 *   2. Copy ScreenCapturePlugin.m to:     ios/App/App/ScreenCapturePlugin.m
 *   3. Open ios/App/App.xcworkspace in Xcode → drag both files into the
 *      App target so they compile.
 *   4. `npx cap sync ios` and run.
 *
 * No Info.plist changes required — both notifications are public APIs.
 */
@objc(ScreenCapturePlugin)
public class ScreenCapturePlugin: CAPPlugin {

    public override func load() {
        // Screenshot — fires immediately AFTER the user takes one.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        // Screen recording state changes (iOS 11+).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onCaptureChanged),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )

        // Emit current state so JS knows if a recording is already in progress
        // when the app launches.
        DispatchQueue.main.async {
            self.emitRecordingState()
        }
    }

    @objc private func onScreenshot() {
        notifyListeners("screenshotTaken", data: [:])
    }

    @objc private func onCaptureChanged() {
        emitRecordingState()
    }

    private func emitRecordingState() {
        let isRecording = UIScreen.main.isCaptured
        notifyListeners("recordingChanged", data: ["isRecording": isRecording])
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
