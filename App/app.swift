    }

    func gridPoint(at location: CGPoint) -> GridPoint? {
        let fx = (location.x - origin.x) / cell
        let fy = (location.y - origin.y) / cell
        guard fx >= 0, fy >= 0, fx < CGFloat(cols), fy < CGFloat(rows) else {
            return nil
        }
        return GridPoint(x: Int(fx), y: Int(fy))
    }
}

// MARK: - Motor del juego

final class GameEngine: ObservableObject {
    @Published private(set) var state: GameState

    private var timer: Timer?
    private var lastTick = Date()
    private var idCounter = 1000

    private var adjacencyCache: [GridPoint: [GridPoint]] = [:]
    private var adjacencyVersion = -1
    private var roadsVersion = 0

    private var strokeLast: GridPoint?
    private(set) var isStroking = false

    private static let bestKey = "miniRutas.bestScore"

    init() {
        state = GameState.newGame()
        state.bestScore = UserDefaults.standard.integer(forKey: Self.bestKey)
        state.phase = .menu

        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        lastTick = Date()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: Controles

    func startGame() {
        state = GameState.newGame()
        state.bestScore = UserDefaults.standard.integer(forKey: Self.bestKey)
        state.phase = .playing
        adjacencyVersion = -1
        strokeLast = nil
        isStroking = false
        lastTick = Date()
    }

    func restart() {
        startGame()
    }

    func togglePause() {
        switch state.phase {
        case .playing:
            state.phase = .paused
            strokeLast = nil
            isStroking = false
        case .paused:
            state.phase = .playing
            lastTick = Date()
        default:
            break
        }
    }

    func autoPause() {
        guard state.phase == .playing else { return }
        state.phase = .paused
        strokeLast = nil
        isStroking = false
    }

    func toggleErase() {
        guard state.phase == .playing else { return }
        state.eraseMode.toggle()
        strokeLast = nil
        isStroking = false
    }

    private func tick() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTick), 0), 0.05)
        lastTick = now
        guard state.phase == .playing else { return }
        update(dt)
    }

    // MARK: Bucle principal

    private func update(_ dt: Double) {
        state.elapsed += dt
        state.budgetPulse = max(0, state.budgetPulse - dt * 2.5)

        state.roadRefillTimer -= dt

        if state.roadRefillTimer <= 0 {
            state.roadRefillTimer += 16
            state.budget = min(state.maxBudget, state.budget + 12)
        }

        state.spawnHouseTimer -= dt
        if state.spawnHouseTimer <= 0 {
            state.spawnHouseTimer += 22
            spawnHouse()
        }

        let spawnScale = max(0.55, 1.0 - state.elapsed / 420.0)
        for i in state.houses.indices {
            if state.houses[i].queue < House.capacity {
                state.houses[i].spawnTimer -= dt
                if state.houses[i].spawnTimer <= 0 {
                    state.houses[i].spawnTimer = Double.random(in: 4.5...7.5) * spawnScale
                    state.houses[i].queue += 1
                }
            }

            if state.houses[i].queue >= House.capacity {
                state.houses[i].panic = min(1, state.houses[i].panic + dt / 10.0)
            } else {
                state.houses[i].panic = max(0, state.houses[i].panic - dt / 5.0)
            }

            if state.houses[i].panic >= 1 {
                finishGame(house: state.houses[i])
                return
            }
        }

        state.dispatchTimer -= dt
        if state.dispatchTimer <= 0 {
            state.dispatchTimer = 0.2
            dispatchCars()
        }

        updateCars(dt)
        updateEffects(dt)

        for i in state.destinations.indices {
            state.destinations[i].pulse = max(0, state.destinations[i].pulse - dt * 2.0)
        }
    }

    private func finishGame(house: House) {
        state.phase = .gameOver
        state.gameOverMessage = "La casa \(house.color.name) quedó aislada y su cola de coches se desbordó."
        if state.score > state.bestScore {
            state.bestScore = state.score
            UserDefaults.standard.set(state.bestScore, forKey: Self.bestKey)
        }
        strokeLast = nil
        isStroking = false
    }

    // MARK: Coches

    private func dispatchCars() {
        var active: [Int: Int] = [:]
        for car in state.cars {
            active[car.homeID, default: 0] += 1
        }

        let snapshot = state.houses
        for house in snapshot where house.queue > 0 && (active[house.id] ?? 0) < 2 {
            guard let path = route(from: house.pos, color: house.color) else { continue }

            let car = Car(id: nextID(),
                          color: house.color,
                          homeID: house.id,
                          path: path,
                          speed: 2.6)
            state.cars.append(car)

            if let i = state.houses.firstIndex(where: { $0.id == house.id }) {
                state.houses[i].queue -= 1
                state.houses[i].panic = max(0, state.houses[i].panic - 0.15)
            }
            active[house.id, default: 0] += 1
        }
    }

    private func updateCars(_ dt: Double) {
        guard !state.cars.isEmpty else { return }
        var finished: [Int] = []

        for i in state.cars.indices {
            var remaining = state.cars[i].speed * dt

            while remaining > 0 {
                let seg = state.cars[i].segment
