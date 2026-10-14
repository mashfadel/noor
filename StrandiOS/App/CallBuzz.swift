import CallKit
import Foundation

/// Noor: buzz the strap while the iPhone rings. Watches the system's calls with `CXCallObserver` (no
/// access to who is calling) and, for an incoming call that is still ringing, sends the same one-shot
/// buzz as Live's "Buzz strap", repeated every few seconds until the call is answered, declined or
/// missed. iOS only delivers call events while Noor is running, which it usually is in the background
/// because it stays connected to the strap; if iOS has suspended it, the call goes unbuzzed.
/// Settings → Strap alerts → "Buzz on incoming calls".
@MainActor
final class CallBuzz: NSObject, CXCallObserverDelegate {
    static let shared = CallBuzz()
    static let enabledKey = "noor.callBuzz.enabled"

    private let observer = CXCallObserver()
    private weak var model: AppModel?
    private var ringing: [UUID: Task<Void, Never>] = [:]

    func attach(to model: AppModel) {
        self.model = model
        observer.setDelegate(self, queue: .main)
    }

    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let id = call.uuid
        let isRinging = !call.isOutgoing && !call.hasConnected && !call.hasEnded
        MainActor.assumeIsolated { update(id: id, ringing: isRinging) }
    }

    private func update(id: UUID, ringing isRinging: Bool) {
        guard isRinging else {
            ringing.removeValue(forKey: id)?.cancel()
            return
        }
        guard ringing[id] == nil, UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        ringing[id] = Task { [weak self] in
            // Up to ~30 s of ringing: one buzz now, then every 6 s.
            for _ in 0..<5 {
                guard !Task.isCancelled, let model = self?.model else { return }
                model.buzzStrapOnce()
                try? await Task.sleep(for: .seconds(6))
            }
            self?.ringing[id] = nil
        }
    }
}
