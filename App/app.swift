//
//  MiniRutas.swift
//  Un clon de Mini Motorways en un único archivo SwiftUI.
//  Requiere iOS 15+ / macOS 12+.
//
//  Cómo se juega:
//  - Arrastra sobre el tablero para dibujar calles.
//  - Cada casa envía coches a la tienda (destino) de su mismo color.
//  - Si una casa acumula 4 coches, empieza una cuenta atrás y, al llenarse,
//    la partida termina. El asfalto es limitado: borra calles para recuperarlo.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Paleta

enum Theme {
    static let bgTop      = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let bgBottom   = Color(red: 0.92, green: 0.88, blue: 0.79)
    static let board      = Color(red: 0.95, green: 0.92, blue: 0.85)
    static let boardEdge  = Color(red: 0.85, green: 0.80, blue: 0.70)
    static let dot        = Color(red: 0.83, green: 0.79, blue: 0.70)
    static let ink        = Color(red: 0.18, green: 0.16, blue: 0.13)
    static let inkSoft    = Color(red: 0.42, green: 0.38, blue: 0.32)
    static let road       = Color.white
    static let roadCasing = Color(red: 0.75, green: 0.71, blue: 0.62)
    static let danger     = Color(red: 0.86, green: 0.23, blue: 0.19)
    static let panel      = Color.white.opacity(0.82)
}

enum BuildingColor: Int, CaseIterable, Hashable {
    case red, blue, yellow, green

    var ui: Color {
        switch self {
        case .red:    return Color(red: 0.90, green: 0.32, blue: 0.24)
        case .blue:   return Color(red: 0.18, green: 0.49, blue: 0.78)
        case .yellow: return Color(red: 0.96, green: 0.66, blue: 0.10)
        case .green:  return Color(red: 0.20, green: 0.62, blue: 0.44)
        }
    }

    var name: String {
        switch self {
        case .red:    return "roja"
        case .blue:   return "azul"
        case .yellow: return "amarilla"
        case .green:  return "verde"
        }
    }
}

// MARK: - Modelo

struct GridPoint: Hashable {
    var x: Int
    var y: Int

    var center: CGPoint { CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5) }
}

struct RoadEdge: Hashable {
    let a: GridPoint
    let b: GridPoint

    init(_ p: GridPoint, _ q: GridPoint) {
        if p.x < q.x || (p.x == q.x && p.y <= q.y) {
            a = p
            b = q
        } else {
            a = q
            b = p
        }
    }
}

enum GamePhase: Equatable {
    case menu, playing, paused, gameOver
}

struct House: Identifiable {
    static let capacity = 4

    let id: Int
    var pos: GridPoint
    var color: BuildingColor
    var spawnTimer: Double
    var queue: Int
    var panic: Double

    init(id: Int,
         pos: GridPoint,
         color: BuildingColor,
         spawnTimer: Double,
         queue: Int = 0,
         panic: Double = 0) {
        self.id = id
        self.pos = pos
        self.color = color
        self.spawnTimer = spawnTimer
        self.queue = queue
        self.panic = panic
    }
}

struct Destination: Identifiable {
    let id: Int
    var pos: GridPoint
    var color: BuildingColor
    var pulse: Double

    init(id: Int, pos: GridPoint, color: BuildingColor, pulse: Double = 0) {
        self.id = id
        self.pos = pos
        self.color = color
        self.pulse = pulse
    }
}

struct Car: Identifiable {
    let id: Int
    let color: BuildingColor
    let homeID: Int
    var path: [CGPoint]
    var segment: Int
    var t: Double
    var speed: Double
    var heading: Double

    init(id: Int, color: BuildingColor, homeID: Int, path: [CGPoint], speed: Double) {
        self.id = id
        self.color = color
        self.homeID = homeID
        self.path = path
        self.speed = speed
        self.segment = 0
        self.t = 0
        self.heading = 0
        if path.count >= 2 {
            self.heading = atan2(Double(path[1].y - path[0].y),
                                 Double(path[1].x - path[0].x))
        }
    }

    var isFinished: Bool { segment >= path.count - 1 }
}

struct FloatingEffect: Identifiable {
    let id: Int
    var pos: CGPoint
    let color: BuildingColor
    let text: String
    var age: Double
    let life: Double

    init(id: Int, pos: CGPoint, color: BuildingColor, text: String, life: Double = 0.9) {
        self.id = id
        self.pos = pos
        self.color = color
        self.text = text
        self.age = 0
        self.life = life
    }
}

struct GameState {
    var cols = 16
    var rows = 12

    var houses: [House] = []
    var destinations: [Destination] = []
    var edges: Set<RoadEdge> = []
    var cars: [Car] = []
    var effects: [FloatingEffect] = []

    var budget = 60
    var maxBudget = 120
    var score = 0
    var bestScore = 0
    var elapsed: Double = 0

    var phase: GamePhase = .menu
    var eraseMode = false

    var spawnHouseTimer: Double = 26
    var roadRefillTimer: Double = 16
    var dispatchTimer: Double = 0
    var budgetPulse: Double = 0
    var gameOverMessage = ""

    static func newGame() -> GameState {
        var s = GameState()

        s.destinations = [
            Destination(id: 1, pos: GridPoint(x: 13, y: 2), color: .red),
            Destination(id: 2, pos: GridPoint(x: 2, y: 2), color: .blue),
            Destination(id: 3, pos: GridPoint(x: 13, y: 9), color: .yellow),
            Destination(id: 4, pos: GridPoint(x: 2, y: 9), color: .green)
        ]

        s.houses = [
            House(id: 101, pos: GridPoint(x: 7, y: 1), color: .red, spawnTimer: 3),
            House(id: 102, pos: GridPoint(x: 1, y: 6), color: .blue, spawnTimer: 5),
            House(id: 103, pos: GridPoint(x: 9, y: 5), color: .yellow, spawnTimer: 7),
            House(id: 104, pos: GridPoint(x: 4, y: 8), color: .green, spawnTimer: 9),
            House(id: 105, pos: GridPoint(x: 12, y: 6), color: .red, spawnTimer: 11)
        ]

        s.phase = .playing
        return s
    }
}

// MARK: - Geometría del tablero

struct BoardGeometry {
    let cols: Int
    let rows: Int
    let cell: CGFloat
    let origin: CGPoint

    init(available: CGSize, cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
        let padding: CGFloat = 6
        let usableW = max(available.width - padding * 2, 10)
        let usableH = max(available.height - padding * 2, 10)
        let c = min(usableW / CGFloat(cols), usableH / CGFloat(rows))
        self.cell = max(c, 1)
        let boardW = self.cell * CGFloat(cols)
        let boardH = self.cell * CGFloat(rows)
        self.origin = CGPoint(x: (available.width - boardW) / 2,
                              y: (available.height - boardH) / 2)
    }

    var rect: CGRect {
        CGRect(x: origin.x, y: origin.y,
               width: cell * CGFloat(cols),
               height: cell * CGFloat(rows))
    }

    func screen(_ grid: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + grid.x * cell,
                y: origin.y + grid.y * cell)
    }

    func screen(_ p: GridPoint) -> CGPoint {
        screen(p.center)
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
                guard seg < state.cars[i].path.count - 1 else { break }

                let a = state.cars[i].path[seg]
                let b = state.cars[i].path[seg + 1]
                let len = max(hypot(Double(b.x - a.x), Double(b.y - a.y)), 0.0001)
                let left = (1 - state.cars[i].t) * len

                if remaining >= left {
                    remaining -= left
                    state.cars[i].segment += 1
                    state.cars[i].t = 0
                } else {
                    state.cars[i].t += remaining / len
                    remaining = 0
                }
            }

            if state.cars[i].path.count >= 2 {
                let seg = min(state.cars[i].segment, state.cars[i].path.count - 2)
                let a = state.cars[i].path[seg]
                let b = state.cars[i].path[seg + 1]
                state.cars[i].heading = atan2(Double(b.y - a.y),
                                             Double(b.x - a.x))
            }

            if state.cars[i].isFinished {
                finished.append(i)
            }
        }

        for i in finished.reversed() {
            let car = state.cars.remove(at: i)
            state.score += 1

            if let d = state.destinations.firstIndex(where: { $0.color == car.color }) {
                state.destinations[d].pulse = 1
                addEffect(at: CGPoint(x: Double(state.destinations[d].pos.x) + 0.5,
                                      y: Double(state.destinations[d].pos.y) + 0.5),
                          text: "+1",
                          color: car.color)
            }
        }
    }

    private func updateEffects(_ dt: Double) {
        for i in state.effects.indices {
            state.effects[i].age += dt
        }
        state.effects.removeAll { $0.age >= $0.life }
    }

    // MARK: Casas nuevas

    private func spawnHouse() {
        guard state.houses.count < 11 else { return }
        guard let color = state.destinations.randomElement()?.color else { return }

        let occupied = Set(state.houses.map { $0.pos } + state.destinations.map { $0.pos })
        var roadCells = Set<GridPoint>()
        for edge in state.edges {
            roadCells.insert(edge.a)
            roadCells.insert(edge.b)
        }

        var candidates: [GridPoint] = []
        for x in 0..<state.cols {
            for y in 0..<state.rows {
                let p = GridPoint(x: x, y: y)
                if occupied.contains(p) || roadCells.contains(p) { continue }

                let tooClose = occupied.contains {
                    abs($0.x - x) + abs($0.y - y) < 2
                }
                if tooClose { continue }

                let hasRoom = gridNeighbors(p).contains { !occupied.contains($0) }
                if hasRoom {
                    candidates.append(p)
                }
            }
        }

        guard let pos = candidates.randomElement() else { return }
        state.houses.append(House(id: nextID(), pos: pos, color: color, spawnTimer: 6))

        addEffect(at: CGPoint(x: Double(pos.x) + 0.5, y: Double(pos.y) + 0.2),
                  text: "Nueva casa",
                  color: color,
                  life: 1.2)
    }

    // MARK: Rutas y caminos

    private func route(from start: GridPoint, color: BuildingColor) -> [CGPoint]? {
        let targets = state.destinations.filter { $0.color == color }
        guard !targets.isEmpty else { return nil }

        let adj = roadAdjacency()
        guard !adj.isEmpty else { return nil }

        var best: [CGPoint]?
        var bestLength = Int.max

        for target in targets {
            let starts = gridNeighbors(start).filter { adj[$0] != nil }
            let goals = Set(gridNeighbors(target.pos).filter { adj[$0] != nil })
            guard !starts.isEmpty, !goals.isEmpty else { continue }

            var dist: [GridPoint: Int] = [:]
            var parent: [GridPoint: GridPoint] = [:]
            var queue: [GridPoint] = []

            for s in starts where dist[s] == nil {
                dist[s] = 0
                queue.append(s)
            }

            var head = 0
            var found: GridPoint?

            while head < queue.count {
                let current = queue[head]
                head += 1

                if goals.contains(current) {
                    found = current
                    break
                }

                for n in adj[current] ?? [] where dist[n] == nil {
                    dist[n] = (dist[current] ?? 0) + 1
                    parent[n] = current
                    queue.append(n)
                }
            }

            guard let goal = found else { continue }
            let length = dist[goal] ?? Int.max
            if length >= bestLength { continue }

            var nodes: [GridPoint] = [goal]
            var cursor = goal
            while let p = parent[cursor] {
                nodes.append(p)
                cursor = p
            }
            nodes.reverse()

            var points: [CGPoint] = [start.center]
            points.append(contentsOf: nodes.map { $0.center })
            points.append(target.pos.center)

            best = points
            bestLength = length
        }

        return best
    }

    private func roadAdjacency() -> [GridPoint: [GridPoint]] {
        if adjacencyVersion != roadsVersion {
            var adj: [GridPoint: [GridPoint]] = [:]
            for edge in state.edges {
                adj[edge.a, default: []].append(edge.b)
                adj[edge.b, default: []].append(edge.a)
            }
            adjacencyCache = adj
            adjacencyVersion = roadsVersion
        }
        return adjacencyCache
    }

    // MARK: Entrada del jugador

    func beginStroke(at p: GridPoint) {
        guard state.phase == .playing else { return }
        isStroking = true

        if state.eraseMode {
            erase(at: p)
            strokeLast = p
        } else {
            strokeLast = building(at: p) ? nil : p
        }
    }

    func continueStroke(to p: GridPoint) {
        guard state.phase == .playing, isStroking else { return }

        if state.eraseMode {
            if let last = strokeLast {
                _ = trace(from: last, to: p) { _, next in
                    self.erase(at: next)
                    return true
                }
            } else {
                erase(at: p)
            }
            strokeLast = p
            return
        }

        guard let last = strokeLast else {
            if !building(at: p) {
                strokeLast = p
            }
            return
        }

        let reached = trace(from: last, to: p) { a, b in
            self.addRoad(from: a, to: b)
        }
        strokeLast = reached
    }

    func endStroke() {
        isStroking = false
        strokeLast = nil
    }

    @discardableResult
    private func trace(from start: GridPoint,
                       to end: GridPoint,
                       action: (GridPoint, GridPoint) -> Bool) -> GridPoint {
        var current = start
        var safety = 0

        while current != end && safety < 80 {
            safety += 1

            let dx = end.x - current.x
            let dy = end.y - current.y
            var next = current

            if abs(dx) >= abs(dy) {
                if dx != 0 {
                    next.x += dx > 0 ? 1 : -1
                } else if dy != 0 {
                    next.y += dy > 0 ? 1 : -1
                }
            } else {
                if dy != 0 {
                    next.y += dy > 0 ? 1 : -1
                } else if dx != 0 {
                    next.x += dx > 0 ? 1 : -1
                }
            }

            if next == current { break }
            if !action(current, next) { break }
            current = next
        }

        return current
    }

    @discardableResult
    private func addRoad(from a: GridPoint, to b: GridPoint) -> Bool {
        guard inBounds(a), inBounds(b) else { return false }
        guard abs(a.x - b.x) + abs(a.y - b.y) == 1 else { return false }
        guard !building(at: a), !building(at: b) else { return false }

        let edge = RoadEdge(a, b)
        if state.edges.contains(edge) { return true }

        guard state.budget > 0 else {
            state.budgetPulse = 1
            return false
        }

        state.edges.insert(edge)
        state.budget -= 1
        roadsVersion += 1
        return true
    }

    private func erase(at p: GridPoint) {
        var removed = 0

        for n in gridNeighbors(p) {
            if state.edges.remove(RoadEdge(p, n)) != nil {
                removed += 1
            }
        }

        if removed > 0 {
            state.budget = min(state.maxBudget, state.budget + removed)
            roadsVersion += 1
        }
    }

    // MARK: Utilidades

    private func building(at p: GridPoint) -> Bool {
        state.houses.contains { $0.pos == p } || state.destinations.contains { $0.pos == p }
    }

    private func inBounds(_ p: GridPoint) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < state.cols && p.y < state.rows
    }

    private func gridNeighbors(_ p: GridPoint) -> [GridPoint] {
        let all = [
            GridPoint(x: p.x + 1, y: p.y),
            GridPoint(x: p.x - 1, y: p.y),
            GridPoint(x: p.x, y: p.y + 1),
            GridPoint(x: p.x, y: p.y - 1)
        ]
        return all.filter(inBounds)
    }

    private func nextID() -> Int {
        idCounter += 1
        return idCounter
    }

    private func addEffect(at pos: CGPoint,
                           text: String,
                           color: BuildingColor,
                           life: Double = 0.9) {
        state.effects.append(FloatingEffect(id: nextID(),
                                            pos: pos,
                                            color: color,
                                            text: text,
                                            life: life))
    }

}

// MARK: - Dibujo del tablero

struct BoardRenderer {
    let geo: BoardGeometry
    let state: GameState

    func draw(_ ctx: inout GraphicsContext) {
        drawBoard(&ctx)
        drawRoads(&ctx)
        drawDriveways(&ctx)
        drawCars(&ctx)
        drawDestinationGlow(&ctx)
        drawDestinations(&ctx)
        drawHouses(&ctx)
        drawEffects(&ctx)
    }

    // MARK: Fondo

    private func drawBoard(_ ctx: inout GraphicsContext) {
        let boardPath = Path(roundedRect: geo.rect,
                             cornerRadius: min(24, geo.cell * 0.55),
                             style: .continuous)

        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.14),
                                    radius: 16, x: 0, y: 7))
            layer.fill(boardPath, with: .color(Theme.board))
        }
        ctx.stroke(boardPath, with: .color(Theme.boardEdge), lineWidth: 1)

        ctx.drawLayer { layer in
            layer.clip(to: boardPath)

            var dots = Path()
            let r: CGFloat = max(0.7, geo.cell * 0.025)
            for x in 0...geo.cols {
                for y in 0...geo.rows {
                    let p = CGPoint(x: geo.origin.x + CGFloat(x) * geo.cell,
                                    y: geo.origin.y + CGFloat(y) * geo.cell)
                    dots.addEllipse(in: CGRect(x: p.x - r, y: p.y - r,
                                               width: r * 2, height: r * 2))
                }
            }
            layer.fill(dots, with: .color(Theme.dot))
        }
    }

    // MARK: Calles

    private func drawRoads(_ ctx: inout GraphicsContext) {
        guard !state.edges.isEmpty else { return }

        var path = Path()
        for edge in state.edges {
            path.move(to: geo.screen(edge.a))
            path.addLine(to: geo.screen(edge.b))
        }

        let casing = max(3, geo.cell * 0.50)
        let surface = max(2, geo.cell * 0.40)

        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.10),
                                    radius: max(2, geo.cell * 0.08),
                                    x: 0, y: max(1, geo.cell * 0.05)))
            layer.stroke(path,
                         with: .color(Theme.roadCasing),
                         style: StrokeStyle(lineWidth: casing,
                                            lineCap: .round,
                                            lineJoin: .round))
        }

        ctx.stroke(path,
                   with: .color(Theme.road),
                   style: StrokeStyle(lineWidth: surface,
                                      lineCap: .round,
                                      lineJoin: .round))
    }

    // MARK: Entradas de los edificios

    private func drawDriveways(_ ctx: inout GraphicsContext) {
        var path = Path()
        var hasAny = false

        func addDriveways(from building: GridPoint) {
            let neighbors = [
                GridPoint(x: building.x + 1, y: building.y),
                GridPoint(x: building.x - 1, y: building.y),
                GridPoint(x: building.x, y: building.y + 1),
                GridPoint(x: building.x, y: building.y - 1)
            ]
            for n in neighbors {
                let edge = RoadEdge(building, n)
                if state.edges.contains(edge) {
                    path.move(to: geo.screen(building))
                    path.addLine(to: geo.screen(n))
                    hasAny = true
                }
            }
        }

        for house in state.houses {
            addDriveways(from: house.pos)
        }
        for dest in state.destinations {
            addDriveways(from: dest.pos)
        }

        guard hasAny else { return }

        ctx.stroke(path,
                   with: .color(Theme.roadCasing),
                   style: StrokeStyle(lineWidth: max(2, geo.cell * 0.30),
                                      lineCap: .round,
                                      lineJoin: .round))
        ctx.stroke(path,
                   with: .color(Theme.road),
                   style: StrokeStyle(lineWidth: max(1.5, geo.cell * 0.22),
                                      lineCap: .round,
                                      lineJoin: .round))
    }

    // MARK: Coches

    private func drawCars(_ ctx: inout GraphicsContext) {
        for car in state.cars {
            let pos = geo.screen(carPosition(car))
            let w = max(6, geo.cell * 0.33)
            let h = max(4, geo.cell * 0.19)

            ctx.drawLayer { layer in
                layer.translateBy(x: pos.x, y: pos.y)
                layer.rotate(by: .radians(car.heading))
                layer.addFilter(.shadow(color: Color.black.opacity(0.18),
                                        radius: 1.4, x: 0, y: 0.8))

                let body = Path(roundedRect: CGRect(x: -w / 2, y: -h / 2,
                                                    width: w, height: h),
                                cornerRadius: h * 0.38)
                layer.fill(body, with: .color(car.color.ui))

                let glass = CGRect(x: w * 0.10, y: -h * 0.26,
                                   width: w * 0.22, height: h * 0.52)
                layer.fill(Path(roundedRect: glass, cornerRadius: h * 0.14),
                           with: .color(Color.white.opacity(0.85)))
            }
        }
    }

    private func carPosition(_ car: Car) -> CGPoint {
        guard car.path.count >= 2 else { return car.path.first ?? .zero }
        let index = min(car.segment, car.path.count - 2)
        let a = car.path[index]
        let b = car.path[index + 1]
        return CGPoint(x: a.x + (b.x - a.x) * CGFloat(car.t),
                       y: a.y + (b.y - a.y) * CGFloat(car.t))
    }

    // MARK: Destinos

    private func drawDestinationGlow(_ ctx: inout GraphicsContext) {
        for dest in state.destinations where dest.pulse > 0.01 {
            let c = geo.screen(dest.pos)
            let base = geo.cell * 0.41
            let grow = (1 - CGFloat(dest.pulse)) * geo.cell * 0.55
            let r = base + grow
            let rect = CGRect(x: c.x - r, y: c.y - r,
                              width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect),
                       with: .color(dest.color.ui.opacity(dest.pulse * 0.55)),
                       lineWidth: max(1.2, geo.cell * 0.05))
        }
    }

    private func drawDestinations(_ ctx: inout GraphicsContext) {
        for dest in state.destinations {
            let c = geo.screen(dest.pos)
            let s = geo.cell * 0.82
            drawBuildingBase(&ctx, center: c, size: s, color: dest.color.ui)

            let outer = s * 0.20
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - outer, y: c.y - outer,
                                            width: outer * 2, height: outer * 2)),
                     with: .color(Color.white.opacity(0.93)))

            let inner = s * 0.09
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - inner, y: c.y - inner,
                                            width: inner * 2, height: inner * 2)),
                     with: .color(dest.color.ui))
        }
    }

    // MARK: Casas

    private func drawHouses(_ ctx: inout GraphicsContext) {
        for house in state.houses {
            let c = geo.screen(house.pos)
            let s = geo.cell * 0.72
            drawBuildingBase(&ctx, center: c, size: s, color: house.color.ui)

            // Ventana
            let w = s * 0.20
            let win = CGRect(x: c.x - s * 0.28, y: c.y - s * 0.28,
                             width: w, height: w)
            ctx.fill(Path(roundedRect: win, cornerRadius: w * 0.25),
                     with: .color(Color.white.opacity(0.58)))

            // Puerta
            let dw = s * 0.20
            let dh = s * 0.24
            let door = CGRect(x: c.x - dw / 2, y: c.y + s * 0.12,
                              width: dw, height: dh)
            ctx.fill(Path(roundedRect: door, cornerRadius: dw * 0.30),
                     with: .color(Color.white.opacity(0.88)))

            // Cola de coches esperando
            if house.queue > 0 {
                let dot = max(1.5, geo.cell * 0.047)
                let gap = dot * 2.7
                let total = CGFloat(house.queue - 1) * gap + dot * 2
                let startX = c.x - total / 2 + dot
                let y = c.y + s * 0.56 + dot * 1.3

                for i in 0..<house.queue {
                    let x = startX + CGFloat(i) * gap
                    let rect = CGRect(x: x - dot, y: y - dot,
                                      width: dot * 2, height: dot * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color.white))
                    ctx.fill(Path(ellipseIn: rect.insetBy(dx: dot * 0.35,
                                                          dy: dot * 0.35)),
                             with: .color(house.color.ui))
                }
            }

            // Cuenta atrás de colapso
            if house.panic > 0.001 {
                let r = s * 0.64
                var arc = Path()
                arc.addArc(center: c, radius: r,
                           startAngle: .degrees(-90),
                           endAngle: .degrees(-90 + 360 * house.panic),
                           clockwise: false)
                ctx.stroke(arc,
                           with: .color(Theme.danger),
                           style: StrokeStyle(lineWidth: max(2, geo.cell * 0.085),
                                              lineCap: .round))
            }
        }
    }

    private func drawBuildingBase(_ ctx: inout GraphicsContext,
                                  center c: CGPoint,
                                  size s: CGFloat,
                                  color: Color) {
        let rect = CGRect(x: c.x - s / 2, y: c.y - s / 2,
                          width: s, height: s)
        let radius = s * 0.26
        let path = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)

        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.16),
                                    radius: max(2, s * 0.12),
                                    x: 0, y: max(1, s * 0.10)))
            layer.fill(path, with: .color(color))
        }

        let inset = max(0.8, s * 0.035)
        let inner = Path(roundedRect: rect.insetBy(dx: inset, dy: inset),
                         cornerRadius: max(1, radius - inset),
                         style: .continuous)
        ctx.stroke(inner,
                   with: .color(Color.white.opacity(0.45)),
                   lineWidth: max(1, s * 0.035))
    }

    // MARK: Efectos

    private func drawEffects(_ ctx: inout GraphicsContext) {
        for effect in state.effects {
            let progress = min(1, effect.age / effect.life)
            let pos = geo.screen(CGPoint(x: effect.pos.x,
                                         y: effect.pos.y - CGFloat(progress) * 0.9))

            ctx.drawLayer { layer in
                layer.opacity = 1 - progress
                let label = Text(effect.text)
                    .font(.system(size: max(9, geo.cell * 0.34),
                                  weight: .heavy,
                                  design: .rounded))
                    .foregroundColor(effect.color.ui)
                layer.draw(label, at: pos, anchor: .center)
            }
        }
    }
}

// MARK: - Interfaz principal

struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            background

            VStack(spacing: 5) {
                HUDView(engine: engine)
                board
                BottomBar(engine: engine)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)

            overlays
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                engine.autoPause()
            }
        }
        .preferredColorScheme(.light)
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)

            Circle()
                .fill(BuildingColor.red.ui.opacity(0.10))
                .frame(width: 460, height: 460)
                .blur(radius: 90)
                .offset(x: -260, y: -230)

            Circle()
                .fill(BuildingColor.blue.ui.opacity(0.10))
                .frame(width: 520, height: 520)
                .blur(radius: 110)
                .offset(x: 300, y: 260)
        }
        .ignoresSafeArea()
    }

    private var board: some View {
        GeometryReader { proxy in
            let geo = BoardGeometry(available: proxy.size,
                                    cols: engine.state.cols,
                                    rows: engine.state.rows)

            Canvas { context, _ in
                let renderer = BoardRenderer(geo: geo, state: engine.state)
                renderer.draw(&context)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let p = geo.gridPoint(at: value.location) else { return }
                        if engine.isStroking {
                            engine.continueStroke(to: p)
                        } else {
                            engine.beginStroke(at: p)
                        }
                    }
                    .onEnded { _ in
                        engine.endStroke()
                    }
            )
        }
    }

    @ViewBuilder
    private var overlays: some View {
        switch engine.state.phase {
        case .menu:
            MenuOverlay(best: engine.state.bestScore) {
                engine.startGame()
            }
        case .paused:
            PauseOverlay(state: engine.state,
                         onResume: { engine.togglePause() },
                         onRestart: { engine.restart() })
        case .gameOver:
            GameOverOverlay(state: engine.state) {
                engine.restart()
            }
        case .playing:
            EmptyView()
        }
    }
}

// MARK: - HUD

struct HUDView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        let s = engine.state

        HStack(spacing: 6) {
            StatChip(icon: "shippingbox.fill",
                     value: "\(s.score)",
                     tint: Theme.ink)

            StatChip(icon: "clock.fill",
                     value: Self.time(s.elapsed),
                     tint: Theme.ink)

            Spacer(minLength: 4)

            BudgetChip(budget: s.budget, pulse: s.budgetPulse)

            ToolButton(icon: "eraser.fill",
                       active: s.eraseMode,
                       action: engine.toggleErase)

            ToolButton(icon: "pause.fill",
                       active: false,
                       action: engine.togglePause)
        }
    }

    static func time(_ t: Double) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct StatChip: View {
    let icon: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.panel))
        .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct BudgetChip: View {
    let budget: Int
    let pulse: Double

    var body: some View {
        let empty = budget <= 0

        HStack(spacing: 5) {
            Image(systemName: "road.lanes")
                .font(.system(size: 10, weight: .bold))
            Text("\(budget)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(empty ? Theme.danger : Theme.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(empty ? Color(red: 1.0, green: 0.90, blue: 0.88) : Theme.panel)
        )
        .overlay(
            Capsule().stroke(empty ? Theme.danger.opacity(0.55)
                                   : Color.white.opacity(0.85),
                            lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .scaleEffect(CGFloat(1 + pulse * 0.10))
    }
}

struct ToolButton: View {
    let icon: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(active ? Color.white : Theme.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(active ? Theme.ink : Theme.panel))
                .overlay(Circle().stroke(Color.white.opacity(active ? 0 : 0.85),
                                         lineWidth: 1))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct BottomBar: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: engine.state.eraseMode ? "eraser.fill" : "hand.draw.fill")
                .font(.system(size: 10, weight: .bold))

            Text(engine.state.eraseMode
                 ? "Arrastra para borrar calles y recuperar asfalto"
                 : "Arrastra calles para unir casas con tiendas del mismo color")
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Spacer(minLength: 6)

            Text("Récord \(engine.state.bestScore)")
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(Theme.inkSoft)
        .padding(.horizontal, 10)
        .frame(height: 22)
    }
}

// MARK: - Superposiciones

struct OverlayScrim<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.24)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        Spacer(minLength: 0)
                        content
                            .padding(20)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct OverlayCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(26)
            .frame(maxWidth: 430)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.bgTop)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 28, x: 0, y: 14)
    }
}

struct CandyButtonStyle: ButtonStyle {
    var color: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(color.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct MenuOverlay: View {
    let best: Int
    let onStart: () -> Void

    var body: some View {
        OverlayScrim {
            OverlayCard {
                VStack(spacing: 15) {
                    HStack(spacing: 8) {
                        ForEach(BuildingColor.allCases, id: \.self) { color in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(color.ui)
                                .frame(width: 20, height: 20)
                        }
                    }

                    VStack(spacing: 3) {
                        Text("MINI RUTAS")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Theme.ink)

                        Text("Un clon de Mini Motorways")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                    }

                    Text("Conecta cada casa con la tienda de su color trazando calles. El asfalto es limitado: administra bien cada tramo.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 9) {
                        ruleRow("1", "Toca y arrastra sobre el mapa para dibujar carreteras.")
                        ruleRow("2", "Las casas envían coches a la tienda de su mismo color.")
                        ruleRow("3", "Si una casa acumula 4 coches, empieza una cuenta atrás.")
                        ruleRow("4", "Usa el borrador para recuperar asfalto y replanificar.")
                    }

                    Button("Jugar") {
                        onStart()
                    }
                    .buttonStyle(CandyButtonStyle(color: Theme.ink))
                    .padding(.top, 2)

                    if best > 0 {
                        Text("Récord: \(best) entregas")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
    }

    private func ruleRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: 19, height: 19)
                .background(Circle().fill(Theme.ink))

            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

struct PauseOverlay: View {
    let state: GameState
    let onResume: () -> Void
    let onRestart: () -> Void

    var body: some View {
        OverlayScrim {
            OverlayCard {
                VStack(spacing: 14) {
                    Text("PAUSA")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.ink)

                    Text("\(state.score) entregas · \(HUDView.time(state.elapsed))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)

                    HStack(spacing: 10) {
                        Button("Continuar") {
                            onResume()
                        }
                        .buttonStyle(CandyButtonStyle(color: Theme.ink))

                        Button("Reiniciar") {
                            onRestart()
                        }
                        .buttonStyle(CandyButtonStyle(color: BuildingColor.red.ui))
                    }
                }
            }
        }
    }
}

struct GameOverOverlay: View {
    let state: GameState
    let onRestart: () -> Void

    var body: some View {
        OverlayScrim {
            OverlayCard {
                VStack(spacing: 12) {
                    Text("¡COLAPSO!")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.danger)

                    Text(state.gameOverMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 22) {
                        scoreBlock("\(state.score)", "entregas")
                        scoreBlock(HUDView.time(state.elapsed), "tiempo")
                        scoreBlock("\(state.bestScore)", "récord")
                    }
                    .padding(.vertical, 6)

                    Button("Nueva partida") {
                        onRestart()
                    }
                    .buttonStyle(CandyButtonStyle(color: Theme.ink))
                }
            }
        }
    }

    private func scoreBlock(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)

            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - Punto de entrada

@main
struct MiniRutasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

