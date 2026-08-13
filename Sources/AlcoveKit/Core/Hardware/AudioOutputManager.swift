import Foundation
import CoreAudio
import AppKit
import SwiftUI

public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let isDefault: Bool
    
    public var icon: String {
        let lower = name.lowercased()
        if lower.contains("airpod") {
            return "airpodspro"
        } else if lower.contains("headphone") || lower.contains("wh-") || lower.contains("bose") {
            return "headphones"
        } else if lower.contains("speaker") || lower.contains("macbook") {
            return "speaker.wave.2.fill"
        } else if lower.contains("display") || lower.contains("hdmi") || lower.contains("tv") {
            return "display"
        } else {
            return "airplayaudio"
        }
    }
}

@MainActor
@Observable
public final class AudioOutputManager {
    public static let shared = AudioOutputManager()
    
    public var devices: [AudioDevice] = []
    public var currentDevice: AudioDevice?
    public var volume: Float = 0.75
    public var isMuted: Bool = false
    
    private init() {
        refreshDevices()
        refreshVolume()
        startMonitoring()
    }
    
    public func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else { return }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        guard status == noErr else { return }
        
        let defaultID = getDefaultOutputDeviceID()
        var discovered: [AudioDevice] = []
        
        for deviceID in deviceIDs {
            // Check if device has output streams
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr && streamSize > 0 {
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var nameUnmanaged: Unmanaged<CFString>?
                var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                
                if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameUnmanaged) == noErr,
                   let unmanaged = nameUnmanaged {
                    let devName = unmanaged.takeRetainedValue() as String
                    let isDef = (deviceID == defaultID)
                    
                    // Filter out microphone-only entries
                    if !devName.lowercased().contains("microphone") {
                        let dev = AudioDevice(id: deviceID, name: devName, isDefault: isDef)
                        discovered.append(dev)
                        if isDef {
                            self.currentDevice = dev
                        }
                    }
                }
            }
        }
        
        self.devices = discovered
    }
    
    public func selectOutputDevice(_ device: AudioDevice) {
        var devID = device.id
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &devID
        )
        if status == noErr {
            self.currentDevice = device
            refreshDevices()
            refreshVolume()
        }
    }
    
    public func setVolume(_ newVolume: Float) {
        self.volume = max(0.0, min(newVolume, 1.0))
        let script = "set volume output volume \(Int(self.volume * 100))"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    public func toggleMute() {
        self.isMuted.toggle()
        let script = "set volume output muted \(self.isMuted)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    private func refreshVolume() {
        let script = "output volume of (get volume settings)"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            if error == nil, let val = result.stringValue, let num = Float(val) {
                self.volume = num / 100.0
            }
        }
    }
    
    private func getDefaultOutputDeviceID() -> AudioDeviceID {
        var defaultID: AudioDeviceID = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultID
        )
        return defaultID
    }
    
    private func startMonitoring() {
        Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.refreshDevices()
            }
        }
    }
}
