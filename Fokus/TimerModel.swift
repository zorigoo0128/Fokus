import SwiftUI
import Combine
import AppKit

@MainActor
final class TimerModel: ObservableObject {
    @Published var totalDuration: TimeInterval = 25 * 60 // Default 25 minutes
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var isRunning: Bool = false
    @Published var isRepeatEnabled: Bool = false
    @Published var hasFinished: Bool = false

    private var timerCancellable: AnyCancellable?
    private var targetEndDate: Date?

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let fraction = timeRemaining / totalDuration
        return min(max(fraction, 0.0), 1.0)
    }

    var formattedTime: String {
        let totalSeconds = Int(ceil(timeRemaining))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var timerStateText: String {
        if hasFinished {
            return "COMPLETED"
        } else if isRunning {
            return "FOCUS"
        } else if timeRemaining < totalDuration {
            return "PAUSED"
        } else {
            return "READY"
        }
    }

    func togglePlayPause() {
        if isRunning {
            pause()
        } else {
            if hasFinished || timeRemaining <= 0 {
                reset()
            }
            start()
        }
    }

    func start() {
        guard !isRunning else { return }
        if timeRemaining <= 0 {
            timeRemaining = totalDuration
        }
        hasFinished = false
        targetEndDate = Date().addingTimeInterval(timeRemaining)
        isRunning = true

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.05, tolerance: 0.01, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pause() {
        guard isRunning else { return }
        if let target = targetEndDate {
            timeRemaining = max(0, target.timeIntervalSinceNow)
        }
        isRunning = false
        targetEndDate = nil
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func reset() {
        pause()
        hasFinished = false
        timeRemaining = totalDuration
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
    }

    func setDuration(minutes: Int) {
        let newDuration = TimeInterval(minutes * 60)
        totalDuration = newDuration
        if !isRunning {
            hasFinished = false
            timeRemaining = newDuration
        }
    }

    func addMinutes(_ minutes: Int) {
        let delta = TimeInterval(minutes * 60)
        let newDuration = max(60, totalDuration + delta)
        totalDuration = newDuration
        if isRunning {
            if let target = targetEndDate {
                targetEndDate = target.addingTimeInterval(delta)
            }
            timeRemaining = max(0, timeRemaining + delta)
        } else {
            timeRemaining = newDuration
        }
    }

    private func tick() {
        guard isRunning, let target = targetEndDate else { return }
        let remaining = target.timeIntervalSinceNow

        if remaining <= 0 {
            timeRemaining = 0
            hasFinished = true
            playAlertSound()

            if isRepeatEnabled {
                // Restart immediately for repeat loop
                timeRemaining = totalDuration
                targetEndDate = Date().addingTimeInterval(totalDuration)
                hasFinished = false
            } else {
                pause()
            }
        } else {
            timeRemaining = remaining
        }
    }

    private func playAlertSound() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else if let sound = NSSound(named: "Ping") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
