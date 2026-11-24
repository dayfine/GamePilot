// Lists the video capture devices as OpenCV's AVFoundation backend numbers
// them (cap_avfoundation_mac.mm: a discovery session for built-in and external
// cameras, video media), one line each: index, unique id, name. The lab app
// stores a card by its unique id (gamepilot switch-devices prints it); the
// daemon's --capture takes the index. Lists only: opens no device, so it is
// safe while the lab app uses a card.
//
//   swift tools/list_capture_devices.swift
import AVFoundation

var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
if #available(macOS 14.0, *) {
  types.append(.external)
} else {
  types.append(.externalUnknown)
}
let session = AVCaptureDevice.DiscoverySession(
  deviceTypes: types, mediaType: .video, position: .unspecified)
for (index, device) in session.devices.enumerated() {
  print("\(index)\t\(device.uniqueID)\t\(device.localizedName)")
}
