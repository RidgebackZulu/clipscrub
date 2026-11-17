/// User intent is independent of temporary suspension during sleep.
struct MonitoringState {
    var userPaused = false
    var sleeping = false

    var isPaused: Bool { userPaused || sleeping }
}
