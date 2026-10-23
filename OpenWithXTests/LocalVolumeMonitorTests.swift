import AppKit
import Testing
@testable import OpenWithX

@MainActor
struct LocalVolumeMonitorTests {
    @Test func restartingMonitorUsesFreshSnapshotAndStopsOldRegistrations() {
        let center = NotificationCenter()
        let externalDisk = URL(fileURLWithPath: "/Volumes/Old SSD")
        let mounts = MountTable([.init(url: externalDisk, isLocal: true)])
        var oldRegistration: Set<URL> = []
        var monitor: LocalVolumeMonitor? = LocalVolumeMonitor(
            notificationCenter: center, mountedVolumes: { mounts.volumes }, register: { oldRegistration = $0 }
        )
        #expect(monitor != nil)
        #expect(oldRegistration == Set([externalDisk]))
        monitor = nil

        mounts.volumes = []
        center.post(name: NSWorkspace.didUnmountNotification, object: nil)
        #expect(oldRegistration == Set([externalDisk]))

        var currentRegistration: Set<URL> = [externalDisk]
        let restarted = LocalVolumeMonitor(
            notificationCenter: center, mountedVolumes: { mounts.volumes }, register: { currentRegistration = $0 }
        )
        withExtendedLifetime(restarted) {
            #expect(currentRegistration.isEmpty)
        }
    }

    @Test func mountChangesReplaceCoverageWithoutKeepingDisconnectedVolumes() {
        let center = NotificationCenter()
        let internalDisk = URL(fileURLWithPath: "/")
        let externalDisk = URL(fileURLWithPath: "/Volumes/本地 SSD")
        let renamedDisk = URL(fileURLWithPath: "/Volumes/Renamed SSD")
        let mounts = MountTable([.init(url: internalDisk, isLocal: true)])
        var registered: Set<URL> = []
        let monitor = LocalVolumeMonitor(notificationCenter: center, mountedVolumes: { mounts.volumes }) {
            registered = $0
        }
        withExtendedLifetime(monitor) {
            mounts.volumes.append(.init(url: externalDisk, isLocal: true))
            center.post(name: NSWorkspace.didMountNotification, object: nil)
            #expect(registered == Set([internalDisk, externalDisk]))

            mounts.volumes = [.init(url: internalDisk, isLocal: true)]
            center.post(name: NSWorkspace.didUnmountNotification, object: nil)
            #expect(registered == Set([internalDisk]))

            mounts.volumes.append(.init(url: externalDisk, isLocal: true))
            center.post(name: NSWorkspace.didMountNotification, object: nil)
            #expect(registered == Set([internalDisk, externalDisk]))

            mounts.volumes = [.init(url: internalDisk, isLocal: true), .init(url: renamedDisk, isLocal: true)]
            center.post(name: NSWorkspace.didRenameVolumeNotification, object: nil)
            #expect(registered == Set([internalDisk, renamedDisk]))
        }
    }

    @Test func coldStartRestoresOnlyCurrentlyMountedLocalVolumes() {
        let internalDisk = URL(fileURLWithPath: "/")
        let externalDisk = URL(fileURLWithPath: "/Volumes/本地 SSD")
        var registered: Set<URL> = []
        let monitor = LocalVolumeMonitor(
            notificationCenter: NotificationCenter(),
            mountedVolumes: { [
                .init(url: internalDisk, isLocal: true),
                .init(url: externalDisk, isLocal: true),
                .init(url: URL(fileURLWithPath: "/Volumes/Network"), isLocal: false),
                .init(url: URL(fileURLWithPath: "/Volumes/Unknown"), isLocal: nil)
            ] },
            register: { registered = $0 }
        )
        withExtendedLifetime(monitor) {
            #expect(registered == Set([internalDisk, externalDisk]))
        }
    }
}

@MainActor
private final class MountTable {
    var volumes: [LocalVolumeCoverage.Volume]

    init(_ volumes: [LocalVolumeCoverage.Volume]) {
        self.volumes = volumes
    }
}
