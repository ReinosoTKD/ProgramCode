//
//  MiniRutas.swift
//  Un clon minimalista de Mini Motorways, en un único archivo SwiftUI.
//  Requiere iOS 15+ / macOS 12+ (por Canvas y GraphicsContext).
//  En iOS está pensado para horizontal.
//
//  IMPORTANTE EN XCODE:
//  Este archivo ya contiene el punto de entrada `@main`.
//  Borra de la plantilla `MiniRutasApp.swift` y `ContentView.swift`
//  (o no añadas este archivo si el proyecto ya tiene otro `@main`).
//
//  Controles:
//  - Arrastra sobre el tablero para trazar calles sobre una red de rutas oculta.
//  - Conecta casas con centros comerciales del mismo color.
//  - Si una casa acumula 4 coches, comienza una cuenta atrás.
//  - El asfalto es limitado; el borrador lo devuelve.
//

import SwiftUI
import Foundation
import Combine

#if os(iOS)
import UIKit
#endif

// MARK: - Colores de edificios

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

    var deep: Color {
        switch self {
        case .red:    return Color(red: 0.62, green: 0.14, blue: 0.11)
        case .blue:   return Color(red: 0.08, green: 0.27, blue: 0.50)
        case .yellow: return Color(red: 0.67, green: 0.40, blue: 0.02)
        case .green:  return Color(red: 0.08, green: 0.38, blue: 0.24)
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

// MARK: - Temas

struct GamePalette: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let isDark: Bool

    let bgTop: Color
    let bgBottom: Color
    let board: Color
    let boardEdge: Color
    let dot: Color
    let ink: Color
    let inkSoft: Color
    let road: Color
    let roadCasing: Color
    let danger: Color
    let panel: Color
    let panelStroke: Color
    let surface: Color
    let stroke: Color
    let button: Color
    let onButton: Color
    let guide: Color

    static let all: [GamePalette] = [.day, .sunset, .night]

    static func named(_ id: String) -> GamePalette {
        all.first { $0.id == id } ?? .day
    }

    static let day = GamePalette(
        id: "day",
        name: "Día",
        tagline: "Papel y luz de mañana",
        isDark: false,
        bgTop: Color(red: 0.98, green: 0.96, blue: 0.91),
        bgBottom: Color(red: 0.92, green: 0.88, blue: 0.79),
        board: Color(red: 0.95, green: 0.92, blue: 0.85),
        boardEdge: Color(red: 0.85, green: 0.80, blue: 0.70),
        dot: Color(red: 0.83, green: 0.79, blue: 0.70),
        ink: Color(red: 0.18, green: 0.16, blue: 0.13),
        inkSoft: Color(red: 0.42, green: 0.38, blue: 0.32),
        road: Color.white,
        roadCasing: Color(red: 0.75, green: 0.71, blue: 0.62),
        danger: Color(red: 0.86, green: 0.23, blue: 0.19),
        panel: Color.white.opacity(0.82),
        panelStroke: Color.white.opacity(0.85),
        surface: Color(red: 0.99, green: 0.97, blue: 0.93),
        stroke: Color(red: 0.85, green: 0.80, blue: 0.70),
        button: Color(red: 0.18, green: 0.16, blue: 0.13),
        onButton: Color.white,
        guide: Color(red: 0.20, green: 0.18, blue: 0.15)
    )

    static let sunset = GamePalette(
        id: "sunset",
        name: "Atardecer",
        tagline: "Melocotón y terracota",
        isDark: false,
        bgTop: Color(red: 0.99, green: 0.91, blue: 0.85),
        bgBottom: Color(red: 0.95, green: 0.76, blue: 0.70),
        board: Color(red: 0.98, green: 0.90, blue: 0.82),
        boardEdge: Color(red: 0.88, green: 0.70, blue: 0.60),
        dot: Color(red: 0.90, green: 0.78, blue: 0.68),
        ink: Color(red: 0.25, green: 0.14, blue: 0.19),
        inkSoft: Color(red: 0.47, green: 0.31, blue: 0.36),
        road: Color(red: 1.0, green: 0.97, blue: 0.92),
        roadCasing: Color(red: 0.80, green: 0.60, blue: 0.50),
        danger: Color(red: 0.78, green: 0.18, blue: 0.16),
        panel: Color.white.opacity(0.78),
        panelStroke: Color.white.opacity(0.80),
        surface: Color(red: 1.0, green: 0.95, blue: 0.89),
        stroke: Color(red: 0.88, green: 0.70, blue: 0.60),
        button: Color(red: 0.42, green: 0.16, blue: 0.25),
        onButton: Color(red: 1.0, green: 0.96, blue: 0.90),
        guide: Color(red: 0.35, green: 0.18, blue: 0.24)
    )

    static let night = GamePalette(
        id: "night",
        name: "Noche",
        tagline: "Asfalto bajo las estrellas",
        isDark: true,
        bgTop: Color(red: 0.10, green: 0.12, blue: 0.19),
        bgBottom: Color(red: 0.05, green: 0.07, blue: 0.12),
        board: Color(red: 0.13, green: 0.17, blue: 0.27),
        boardEdge: Color(red: 0.22, green: 0.28, blue: 0.40),
        dot: Color(red: 0.20, green: 0.25, blue: 0.36),
        ink: Color(red: 0.95, green: 0.93, blue: 0.87),
        inkSoft: Color(red: 0.66, green: 0.71, blue: 0.82),
        road: Color(red: 0.88, green: 0.91, blue: 0.97),
        roadCasing: Color(red: 0.33, green: 0.39, blue: 0.52),
        danger: Color(red: 1.0, green: 0.42, blue: 0.37),
        panel: Color(red: 0.14, green: 0.18, blue: 0.27).opacity(0.90),
        panelStroke: Color.white.opacity(0.12),
        surface: Color(red: 0.11, green: 0.14, blue: 0.22),
        stroke: Color(red: 0.24, green: 0.30, blue: 0.42),
        button: Color(red: 0.93, green: 0.91, blue: 0.85),
        onButton: Color(red: 0.08, green: 0.10, blue: 0.16),
        guide: Color(red: 0.85, green: 0.88, blue: 0.95)
    )
}

// MARK: - Dificultad y ajustes

enum Difficulty: String, CaseIterable, Identifiable {
    case relaxed, normal, intense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: return "Tranquilo"
        case .normal:  return "Normal"
        case .intense: return "Intenso"
        }
    }

    var subtitle: String {
        switch self {
        case .relaxed: return "Más margen y menos tráfico."
        case .normal:  return "Ritmo equilibrado."
        case .intense: return "Más casas y menos asfalto."
        }
    }

    var spawnRange: ClosedRange<Double> {
        switch self {
        case .relaxed: return 6.0...9.5
        case .normal:  return 4.5...7.5
        case .intense: return 3.5...5.5
        }
    }

    var spawnScaleFloor: Double {
        switch self {
        case .relaxed: return 0.70
        case .normal:  return 0.55
        case .intense: return 0.45
        }
    }

    var houseInterval: Double {
        switch self {
        case .relaxed: return 28
        case .normal:  return 22
        case .intense: return 16
        }
    }

    var grace: Double {
        switch self {
        case .relaxed: return 18
        case .normal:  return 14
        case .intense: return 11
        }
    }

    var roadInterval: Double {
        switch self {
        case .relaxed: return 14
        case .normal:  return 16
        case .intense: return 18
        }
    }

    var roadAmount: Int {
        switch self {
        case .relaxed: return 16
        case .normal:  return 12
        case .intense: return 10
        }
    }

    var initialBudget: Int {
        switch self {
        case .relaxed: return 80
        case .normal:  return 70
        case .intense: return 60
        }
    }
}

struct GameSettings {
    var themeID: String
    var showGuides: Bool
    var difficulty: Difficulty

    init(themeID: String = GamePalette.day.id,
         showGuides: Bool = false,
         difficulty: Difficulty = .normal) {
        self.themeID = themeID
        self.showGuides = showGuides
        self.difficulty = difficulty
    }
}

// MARK: - Modelo de juego

struct GridPoint: Hashable {
    var x: Int
    var y: Int

    var center: CGPoint { CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5) }
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
    var driveway: GridPoint
    var spawnTimer: Double
    var queue: Int
    var panic: Double

    init(id: Int,
         pos: GridPoint,
         color: BuildingColor,
         driveway: GridPoint,
         spawnTimer: Double,
         queue: Int = 0,
         panic: Double = 0) {
        self.id = id
        self.pos = pos
        self.color = color
        self.driveway = driveway
        self.spawnTimer = spawnTimer
        self.queue = queue
        self.panic = panic
    }
}

struct Mall: Identifiable {
    let id: Int
    var pos: GridPoint
    var color: BuildingColor
    var driveway: GridPoint
    var pulse: Double

    init(id: Int, pos: GridPoint, color: BuildingColor, driveway: GridPoint, pulse: Double = 0) {
        self.id = id
        self.pos = pos
        self.color = color
        self.driveway = driveway
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
    var cols = 22
    var rows = 12

    var guideEdges: Set<RoadEdge> = []
    var guideNodes: Set<GridPoint> = []

    var houses: [House] = []
    var malls: [Mall] = []
    var edges: Set<RoadEdge> = []
    var cars: [Car] = []
    var effects: [FloatingEffect] = []

    var budget = 70
    var maxBudget = 140
    var score = 0
    var bestScore = 0
    var elapsed: Double = 0

    var phase: GamePhase = .menu
    var eraseMode = false
    var difficulty: Difficulty = .normal

    var spawnHouseTimer: Double = 22
    var roadRefillTimer: Double = 16
    var dispatchTimer: Double = 0
    var budgetPulse: Double = 0
    var gameOverMessage = ""
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

// MARK: - Generación del mapa

extension GameState {
    static func newGame(difficulty: Difficulty) -> GameState {
        var s = GameState()
        s.difficulty = difficulty

        let guide = makeGuideNetwork()
        s.guideEdges = guide
        s.guideNodes = nodes(of: guide)

        let mallData: [(Int, GridPoint, BuildingColor)] = [
            (1, GridPoint(x: 8, y: 3), .red),
            (2, GridPoint(x: 17, y: 2), .blue),
            (3, GridPoint(x: 5, y: 9), .yellow),
            (4, GridPoint(x: 13, y: 8), .green)
        ]
        s.malls = mallData.map { entry in
            Mall(id: entry.0,
                 pos: entry.1,
                 color: entry.2,
                 driveway: chooseDriveway(pos: entry.1, nodes: s.guideNodes))
        }

        let houseData: [(Int, GridPoint, BuildingColor, Double)] = [
            (101, GridPoint(x: 4, y: 0), .red, 12),
            (102, GridPoint(x: 12, y: 0), .blue, 14),
            (103, GridPoint(x: 19, y: 0), .yellow, 16),
            (104, GridPoint(x: 3, y: 5), .green, 18),
            (105, GridPoint(x: 20, y: 5), .red, 20),
            (106, GridPoint(x: 8, y: 11), .blue, 22)
        ]
        s.houses = houseData.map { entry in
            House(id: entry.0,
                  pos: entry.1,
                  color: entry.2,
                  driveway: chooseDriveway(pos: entry.1, nodes: s.guideNodes),
                  spawnTimer: entry.3)
        }

        s.budget = difficulty.initialBudget
        s.maxBudget = max(120, difficulty.initialBudget + 70)
        s.spawnHouseTimer = difficulty.houseInterval
        s.roadRefillTimer = difficulty.roadInterval
        s.phase = .playing
        return s
    }

    /// Red ortogonal oculta que limita y guía todas las carreteras.
    static func makeGuideNetwork() -> Set<RoadEdge> {
        var edges = Set<RoadEdge>()
        let columns = [2, 6, 10, 14, 18]
        let rows = [1, 4, 7, 10]

        for x in columns {
            for y in 1..<10 {
                edges.insert(RoadEdge(GridPoint(x: x, y: y),
                                      GridPoint(x: x, y: y + 1)))
            }
        }

        for y in rows {
            for x in 1..<20 {
                edges.insert(RoadEdge(GridPoint(x: x, y: y),
                                      GridPoint(x: x + 1, y: y)))
            }
        }

        return edges
    }

    static func nodes(of edges: Set<RoadEdge>) -> Set<GridPoint> {
        var result = Set<GridPoint>()
        for edge in edges {
            result.insert(edge.a)
            result.insert(edge.b)
        }
        return result
    }

    static func gridNeighbors(_ p: GridPoint) -> [GridPoint] {
        [
            GridPoint(x: p.x + 1, y: p.y),
            GridPoint(x: p.x - 1, y: p.y),
            GridPoint(x: p.x, y: p.y + 1),
            GridPoint(x: p.x, y: p.y - 1)
        ]
    }

    /// Elige una calle pequeña de entrada en un lado válido y aleatorio.
    static func chooseDriveway(pos: GridPoint, nodes: Set<GridPoint>) -> GridPoint {
        let valid = gridNeighbors(pos).filter { nodes.contains($0) }
        return valid.randomElement() ?? GridPoint(x: pos.x, y: pos.y + 1)
    }
}

// MARK: - Motor del juego

final class GameEngine: ObservableObject {
    @Published private(set) var state: GameState
    @Published var settings: GameSettings {
        didSet { persistSettings() }
    }

    private var ticker: AnyCancellable?
    private var lastTick = Date()
    private var idCounter = 1000

    private var adjacencyCache: [GridPoint: [GridPoint]] = [:]
    private var adjacencyVersion = -1
    private var roadsVersion = 0

    private var guideAdjacency: [GridPoint: [GridPoint]] = [:]
    private var guideReady = false

    private var strokeLast: GridPoint?
    private(set) var isStroking = false

    private enum Keys {
        static let best = "miniRutas.bestScore"
        static let theme = "miniRutas.theme"
        static let guides = "miniRutas.guides"
        static let difficulty = "miniRutas.difficulty"
    }

    init() {
        let defaults = UserDefaults.standard
        let theme = defaults.string(forKey: Keys.theme) ?? GamePalette.day.id
        let difficulty = Difficulty(rawValue: defaults.string(forKey: Keys.difficulty) ?? "")
            ?? .normal

        settings = GameSettings(themeID: theme,
                                showGuides: defaults.bool(forKey: Keys.guides),
                                difficulty: difficulty)

        state = GameState.newGame(difficulty: difficulty)
        state.bestScore = defaults.integer(forKey: Keys.best)
        state.phase = .menu

        ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        lastTick = Date()
    }

    deinit {
        ticker?.cancel()
    }

    private func persistSettings() {
        let defaults = UserDefaults.standard
        defaults.set(settings.themeID, forKey: Keys.theme)
        defaults.set(settings.showGuides, forKey: Keys.guides)
        defaults.set(settings.difficulty.rawValue, forKey: Keys.difficulty)
    }

    // MARK: Controles

    func startGame() {
        state = GameState.newGame(difficulty: settings.difficulty)
        state.bestScore = UserDefaults.standard.integer(forKey: Keys.best)
        state.phase = .playing
        adjacencyVersion = -1
        guideReady = false
        strokeLast = nil
        isStroking = false
        lastTick = Date()
    }

    func restart() {
        startGame()
    }

    func returnToMenu() {
        state.phase = .menu
        strokeLast = nil
        isStroking = false
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

    func toggleGuides() {
        settings.showGuides.toggle()
    }

    func resetBest() {
        state.bestScore = 0
        UserDefaults.standard.removeObject(forKey: Keys.best)
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
        let difficulty = state.difficulty
        state.elapsed += dt
        state.budgetPulse = max(0, state.budgetPulse - dt * 2.5)

        state.roadRefillTimer -= dt
        if state.roadRefillTimer <= 0 {
            state.roadRefillTimer += difficulty.roadInterval
            state.budget = min(state.maxBudget, state.budget + difficulty.roadAmount)
        }

        state.spawnHouseTimer -= dt
        if state.spawnHouseTimer <= 0 {
            state.spawnHouseTimer += difficulty.houseInterval
            spawnHouse()
        }

        let spawnScale = max(difficulty.spawnScaleFloor, 1.0 - state.elapsed / 420.0)
        for i in state.houses.indices {
            if state.houses[i].queue < House.capacity {
                state.houses[i].spawnTimer -= dt
                if state.houses[i].spawnTimer <= 0 {
                    let range = difficulty.spawnRange
                    state.houses[i].spawnTimer = Double.random(in: range) * spawnScale
                    state.houses[i].queue += 1
                }
            }

            if state.houses[i].queue >= House.capacity {
                state.houses[i].panic = min(1, state.houses[i].panic + dt / difficulty.grace)
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

        for i in state.malls.indices {
            state.malls[i].pulse = max(0, state.malls[i].pulse - dt * 2.0)
        }
    }

    private func finishGame(house: House) {
        state.phase = .gameOver
        state.gameOverMessage = "La casa \(house.color.name) quedó aislada y su cola de coches se desbordó."
        if state.score > state.bestScore {
            state.bestScore = state.score
            UserDefaults.standard.set(state.bestScore, forKey: Keys.best)
        }
        strokeLast = nil
        isStroking = false
    }

    // MARK: Coches y casas

    private func spawnHouse() {
        guard state.houses.count < 11 else { return }
        guard let color = state.malls.randomElement()?.color else { return }

        let occupied = Set(state.houses.map { $0.pos } + state.malls.map { $0.pos })
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
                if state.guideNodes.contains(p) { continue }

                let tooClose = occupied.contains(where: { other in
                    abs(other.x - x) + abs(other.y - y) < 2
                })
                if tooClose { continue }

                let doorways = GameState.gridNeighbors(p).filter {
                    state.guideNodes.contains($0) && !occupied.contains($0)
                }
                if !doorways.isEmpty {
                    candidates.append(p)
                }
            }
        }

        guard let pos = candidates.randomElement() else { return }
        let doorway = GameState.chooseDriveway(pos: pos, nodes: state.guideNodes)
        state.houses.append(House(id: nextID(),
                                  pos: pos,
                                  color: color,
                                  driveway: doorway,
                                  spawnTimer: 6))

        addEffect(at: CGPoint(x: CGFloat(pos.x) + 0.5, y: CGFloat(pos.y) + 0.1),
                  text: "Nueva casa",
                  color: color,
                  life: 1.2)
    }

    private func dispatchCars() {
        var active: [Int: Int] = [:]
        for car in state.cars {
            active[car.homeID, default: 0] += 1
        }

        let snapshot = state.houses
        for house in snapshot where house.queue > 0 && (active[house.id] ?? 0) < 3 {
            guard let path = route(for: house) else { continue }

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

            if let m = state.malls.firstIndex(where: { $0.color == car.color }) {
                state.malls[m].pulse = 1
                addEffect(at: state.malls[m].pos.center,
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

    // MARK: Rutas de coches

    private func route(for house: House) -> [CGPoint]? {
        let adj = roadAdjacency()
        guard adj[house.driveway] != nil else { return nil }

        let targets = state.malls.filter { $0.color == house.color }
        guard !targets.isEmpty else { return nil }

        var best: [GridPoint]?
        var bestMall: Mall?
        var bestLength = Int.max

        for mall in targets {
            guard let path = shortestPath(from: house.driveway,
                                          to: mall.driveway,
                                          adjacency: adj) else { continue }
            if path.count >= bestLength { continue }
            best = path
            bestMall = mall
            bestLength = path.count
        }

        guard let nodes = best, let mall = bestMall, !nodes.isEmpty else { return nil }

        var points: [CGPoint] = [house.pos.center]
        points.append(contentsOf: nodes.map { $0.center })
        points.append(mall.pos.center)
        return dedupe(points)
    }

    private func shortestPath(from start: GridPoint,
                              to goal: GridPoint,
                              adjacency: [GridPoint: [GridPoint]]) -> [GridPoint]? {
        guard adjacency[start] != nil else { return nil }
        if start == goal { return [start] }

        var visited: Set<GridPoint> = [start]
        var parent: [GridPoint: GridPoint] = [:]
        var queue: [GridPoint] = [start]
        var head = 0
        var found = false

        while head < queue.count {
            let current = queue[head]
            head += 1

            if current == goal {
                found = true
                break
            }

            for next in adjacency[current] ?? [] where !visited.contains(next) {
                visited.insert(next)
                parent[next] = current
                queue.append(next)
            }
        }

        guard found else { return nil }

        var path: [GridPoint] = [goal]
        var cursor = goal
        while let previous = parent[cursor] {
            path.append(previous)
            cursor = previous
        }
        path.reverse()
        return path
    }

    private func dedupe(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for point in points {
            if let last = result.last,
               abs(last.x - point.x) < 0.0001,
               abs(last.y - point.y) < 0.0001 {
                continue
            }
            result.append(point)
        }
        return result
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

    // MARK: Red oculta y entrada del jugador

    private func guideNetwork() -> [GridPoint: [GridPoint]] {
        if !guideReady {
            var adj: [GridPoint: [GridPoint]] = [:]
            for edge in state.guideEdges {
                adj[edge.a, default: []].append(edge.b)
                adj[edge.b, default: []].append(edge.a)
            }
            guideAdjacency = adj
            guideReady = true
        }
        return guideAdjacency
    }

    private func snappedGuideNode(for point: GridPoint) -> GridPoint? {
        // Soltar sobre un edificio (o justo a su lado) conecta con su calle de entrada.
        var buildingSnap: GridPoint?
        var buildingDistance = Int.max

        for house in state.houses {
            let distance = abs(house.pos.x - point.x) + abs(house.pos.y - point.y)
            if distance <= 1 && distance < buildingDistance {
                buildingDistance = distance
                buildingSnap = house.driveway
            }
        }
        for mall in state.malls {
            let distance = abs(mall.pos.x - point.x) + abs(mall.pos.y - point.y)
            if distance <= 1 && distance < buildingDistance {
                buildingDistance = distance
                buildingSnap = mall.driveway
            }
        }
        if let buildingSnap = buildingSnap { return buildingSnap }

        var best: GridPoint?
        var bestDistance = Int.max
        for node in state.guideNodes {
            let distance = abs(node.x - point.x) + abs(node.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                best = node
            }
        }
        // Solo se engancha a la red si el gesto pasa cerca de una ruta.
        guard bestDistance <= 1 else { return nil }
        return best
    }

    private func guideShortestPath(from start: GridPoint,
                                   to goal: GridPoint) -> [GridPoint]? {
        if start == goal { return [start] }
        let adjacency = guideNetwork()
        guard adjacency[start] != nil, adjacency[goal] != nil else { return nil }

        var visited: Set<GridPoint> = [start]
        var parent: [GridPoint: GridPoint] = [:]
        var queue: [GridPoint] = [start]
        var head = 0
        var found = false

        while head < queue.count {
            let current = queue[head]
            head += 1
            if current == goal {
                found = true
                break
            }
            for next in adjacency[current] ?? [] where !visited.contains(next) {
                visited.insert(next)
                parent[next] = current
                queue.append(next)
            }
        }

        guard found else { return nil }

        var path: [GridPoint] = [goal]
        var cursor = goal
        while let previous = parent[cursor] {
            path.append(previous)
            cursor = previous
        }
        path.reverse()
        return path
    }

    func beginStroke(at point: GridPoint) {
        guard state.phase == .playing else { return }
        isStroking = true

        if state.eraseMode {
            eraseAtPointer(point)
            strokeLast = point
        } else {
            strokeLast = snappedGuideNode(for: point)
        }
    }

    func continueStroke(to point: GridPoint) {
        guard state.phase == .playing, isStroking else { return }

        if state.eraseMode {
            eraseAtPointer(point)
            strokeLast = point
            return
        }

        guard let target = snappedGuideNode(for: point) else { return }
        guard let start = strokeLast else {
            strokeLast = target
            return
        }
        guard target != start else { return }

        guard let path = guideShortestPath(from: start, to: target) else {
            strokeLast = target
            return
        }

        var reached = start
        for node in path.dropFirst() {
            if addRoad(from: reached, to: node) {
                reached = node
            } else {
                break
            }
        }
        strokeLast = reached
    }

    func endStroke() {
        isStroking = false
        strokeLast = nil
    }

    @discardableResult
    private func addRoad(from a: GridPoint, to b: GridPoint) -> Bool {
        guard inBounds(a), inBounds(b) else { return false }
        guard abs(a.x - b.x) + abs(a.y - b.y) == 1 else { return false }
        guard !building(at: a), !building(at: b) else { return false }

        let edge = RoadEdge(a, b)
        guard state.guideEdges.contains(edge) else { return false }
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

    private func eraseAtPointer(_ point: GridPoint) {
        erase(at: point)
        if let snapped = snappedGuideNode(for: point), snapped != point {
            erase(at: snapped)
        }
    }

    private func erase(at point: GridPoint) {
        var removed = 0
        for neighbor in gridNeighbors(point) {
            if state.edges.remove(RoadEdge(point, neighbor)) != nil {
                removed += 1
            }
        }
        if removed > 0 {
            state.budget = min(state.maxBudget, state.budget + removed)
            roadsVersion += 1
        }
    }

    // MARK: Utilidades

    private func building(at point: GridPoint) -> Bool {
        state.houses.contains(where: { $0.pos == point })
            || state.malls.contains(where: { $0.pos == point })
    }

    private func inBounds(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x < state.cols && point.y < state.rows
    }

    private func gridNeighbors(_ point: GridPoint) -> [GridPoint] {
        GameState.gridNeighbors(point).filter { inBounds($0) }
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
    let palette: GamePalette
    let showGuides: Bool

    func draw(_ ctx: inout GraphicsContext) {
        drawBoard(&ctx)
        drawGuides(&ctx)
        drawRoads(&ctx)
        drawDriveways(&ctx)
        drawCars(&ctx)
        drawMallPulses(&ctx)
        drawMalls(&ctx)
        drawHouses(&ctx)
        drawEffects(&ctx)
    }

    // MARK: Fondo

    private func drawBoard(_ ctx: inout GraphicsContext) {
        let boardPath = Path(roundedRect: geo.rect,
                             cornerRadius: min(26, geo.cell * 0.60),
                             style: .continuous)

        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.16),
                                    radius: 18, x: 0, y: 8))
            layer.fill(boardPath, with: .color(palette.board))
        }
        ctx.stroke(boardPath,
                   with: .color(palette.boardEdge),
                   lineWidth: 1)

        ctx.drawLayer { layer in
            layer.clip(to: boardPath)

            var dots = Path()
            let r: CGFloat = max(0.7, geo.cell * 0.022)
            for x in 0...geo.cols {
                for y in 0...geo.rows {
                    let p = CGPoint(x: geo.origin.x + CGFloat(x) * geo.cell,
                                    y: geo.origin.y + CGFloat(y) * geo.cell)
                    dots.addEllipse(in: CGRect(x: p.x - r, y: p.y - r,
                                               width: r * 2, height: r * 2))
                }
            }
            layer.fill(dots, with: .color(palette.dot))

            var inner = Path()
            inner.addRect(geo.rect.insetBy(dx: 1, dy: 1))
            layer.stroke(inner,
                         with: .color(palette.boardEdge.opacity(0.45)),
                         lineWidth: 1)
        }
    }

    // MARK: Red de rutas oculta

    private func drawGuides(_ ctx: inout GraphicsContext) {
        guard showGuides, !state.guideEdges.isEmpty else { return }

        var path = Path()
        for edge in state.guideEdges {
            path.move(to: geo.screen(edge.a))
            path.addLine(to: geo.screen(edge.b))
        }

        ctx.stroke(path,
                   with: .color(palette.guide.opacity(0.20)),
                   style: StrokeStyle(lineWidth: max(1, geo.cell * 0.045),
                                      lineCap: .round,
                                      lineJoin: .round,
                                      dash: [max(2, geo.cell * 0.09),
                                             max(3, geo.cell * 0.15)]))

        var dots = Path()
        let r = max(1, geo.cell * 0.035)
        for node in state.guideNodes {
            let p = geo.screen(node)
            dots.addEllipse(in: CGRect(x: p.x - r, y: p.y - r,
                                       width: r * 2, height: r * 2))
        }
        ctx.fill(dots, with: .color(palette.guide.opacity(0.30)))
    }

    // MARK: Calles construidas

    private func drawRoads(_ ctx: inout GraphicsContext) {
        guard !state.edges.isEmpty else { return }

        var path = Path()
        for edge in state.edges {
            path.move(to: geo.screen(edge.a))
            path.addLine(to: geo.screen(edge.b))
        }

        let casing = max(3, geo.cell * 0.48)
        let surface = max(2, geo.cell * 0.38)

        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.10),
                                    radius: max(2, geo.cell * 0.08),
                                    x: 0, y: max(1, geo.cell * 0.05)))
            layer.stroke(path,
                         with: .color(palette.roadCasing),
                         style: StrokeStyle(lineWidth: casing,
                                            lineCap: .round,
                                            lineJoin: .round))
        }

        ctx.stroke(path,
                   with: .color(palette.road),
                   style: StrokeStyle(lineWidth: surface,
                                      lineCap: .round,
                                      lineJoin: .round))
    }

    // MARK: Pequeñas calles de entrada

    private func drawDriveways(_ ctx: inout GraphicsContext) {
        var path = Path()

        for house in state.houses {
            path.move(to: geo.screen(house.pos))
            path.addLine(to: geo.screen(house.driveway))
        }
        for mall in state.malls {
            path.move(to: geo.screen(mall.pos))
            path.addLine(to: geo.screen(mall.driveway))
        }
        guard !state.houses.isEmpty || !state.malls.isEmpty else { return }

        ctx.stroke(path,
                   with: .color(palette.roadCasing),
                   style: StrokeStyle(lineWidth: max(2, geo.cell * 0.26),
                                      lineCap: .round,
                                      lineJoin: .round))
        ctx.stroke(path,
                   with: .color(palette.road),
                   style: StrokeStyle(lineWidth: max(1.5, geo.cell * 0.18),
                                      lineCap: .round,
                                      lineJoin: .round))
    }

    // MARK: Coches

    private func drawCars(_ ctx: inout GraphicsContext) {
        for car in state.cars {
            let pos = geo.screen(carPosition(car))
            let w = max(6, geo.cell * 0.32)
            let h = max(4, geo.cell * 0.18)

            ctx.drawLayer { layer in
                layer.translateBy(x: pos.x, y: pos.y)
                layer.rotate(by: .radians(car.heading))
                layer.addFilter(.shadow(color: Color.black.opacity(0.20),
                                        radius: 1.5, x: 0, y: 0.9))

                let body = Path(roundedRect: CGRect(x: -w / 2, y: -h / 2,
                                                    width: w, height: h),
                                cornerRadius: h * 0.38)
                layer.fill(body, with: .color(car.color.ui))

                let glass = CGRect(x: w * 0.08, y: -h * 0.28,
                                   width: w * 0.24, height: h * 0.56)
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

    // MARK: Centros comerciales

    private func drawMallPulses(_ ctx: inout GraphicsContext) {
        for mall in state.malls where mall.pulse > 0.01 {
            let c = geo.screen(mall.pos)
            let base = geo.cell * 0.46
            let radius = base + geo.cell * 0.55 * CGFloat(1 - mall.pulse)
            let ring = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius,
                                              width: radius * 2, height: radius * 2))
            ctx.stroke(ring,
                       with: .color(mall.color.ui.opacity(0.55 * mall.pulse)),
                       lineWidth: max(1.5, geo.cell * 0.06))
        }
    }

    private func drawMalls(_ ctx: inout GraphicsContext) {
        for mall in state.malls {
            let c = geo.screen(mall.pos)
            let dir = directionVector(from: mall.pos, to: mall.driveway)
            let w = geo.cell * 0.94
            let h = geo.cell * 0.70
            let offset = geo.cell * 0.06

            let rect = CGRect(x: c.x - w / 2 - dir.dx * offset,
                              y: c.y - h / 2 - dir.dy * offset,
                              width: w, height: h)
            let corner = min(h * 0.22, geo.cell * 0.14)

            // Sombra
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: Color.black.opacity(0.20),
                                        radius: max(2, geo.cell * 0.10),
                                        x: 0, y: max(1.5, geo.cell * 0.07)))
                layer.fill(Path(roundedRect: rect, cornerRadius: corner),
                           with: .color(mall.color.ui))
            }

            // Cuerpo con gradiente
            let body = Path(roundedRect: rect, cornerRadius: corner)
            ctx.fill(body,
                     with: .linearGradient(
                        Gradient(colors: [mall.color.ui,
                                          mall.color.deep]),
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

            // Tejado plano / cornisa
            let roofHeight = h * 0.26
            let roofRect = CGRect(x: rect.minX, y: rect.minY,
                                  width: rect.width, height: roofHeight)
            ctx.fill(Path(roundedRect: roofRect,
                          cornerRadius: corner,
                          style: .continuous),
                     with: .color(mall.color.deep))

            // Escaparate: tira de luces
            let windowInset = w * 0.08
            let windowY = rect.minY + h * 0.56
            let windowRect = CGRect(x: rect.minX + windowInset,
                                    y: windowY,
                                    width: rect.width - windowInset * 2,
                                    height: h * 0.24)
            ctx.fill(Path(roundedRect: windowRect,
                          cornerRadius: h * 0.06),
                     with: .color(palette.road.opacity(0.92)))

            var mullions = Path()
            let count = 4
            for i in 1..<count {
                let x = windowRect.minX + windowRect.width * CGFloat(i) / CGFloat(count)
                mullions.move(to: CGPoint(x: x, y: windowRect.minY + h * 0.02))
                mullions.addLine(to: CGPoint(x: x, y: windowRect.maxY - h * 0.02))
            }
            ctx.stroke(mullions,
                       with: .color(mall.color.deep.opacity(0.55)),
                       lineWidth: max(0.8, geo.cell * 0.02))

            // Toldo inferior
            let awningRect = CGRect(x: rect.minX + w * 0.02,
                                    y: rect.maxY - h * 0.10,
                                    width: rect.width - w * 0.04,
                                    height: h * 0.09)
            ctx.fill(Path(roundedRect: awningRect,
                          cornerRadius: h * 0.04),
                     with: .color(mall.color.ui.opacity(0.85)))

            // Puerta de acceso hacia su calle
            let doorW = max(2.5, geo.cell * 0.14)
            let doorH = max(2.5, geo.cell * 0.12)
            let doorRect = accessRect(in: rect, dir: dir,
                                      width: doorW, height: doorH)
            ctx.fill(Path(roundedRect: doorRect, cornerRadius: doorW * 0.25),
                     with: .color(palette.ink.opacity(0.35)))
        }
    }

    // MARK: Casas

    private func drawHouses(_ ctx: inout GraphicsContext) {
        for house in state.houses {
            drawHouse(&ctx, house: house)
        }
    }

    private func drawHouse(_ ctx: inout GraphicsContext, house: House) {
        let c = geo.screen(house.pos)
        let dir = directionVector(from: house.pos, to: house.driveway)
        let w = geo.cell * 0.58
        let h = geo.cell * 0.46
        let offset = geo.cell * 0.05

        let bodyRect = CGRect(x: c.x - w / 2 - dir.dx * offset,
                              y: c.y - h / 2 - dir.dy * offset,
                              width: w, height: h)
        let corner = min(h * 0.18, geo.cell * 0.10)

        // Sombra
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.22),
                                    radius: max(1.5, geo.cell * 0.07),
                                    x: 0, y: max(1, geo.cell * 0.05)))
            layer.fill(Path(roundedRect: bodyRect, cornerRadius: corner),
                       with: .color(house.color.ui))
        }

        // Paredes
        ctx.fill(Path(roundedRect: bodyRect, cornerRadius: corner),
                 with: .linearGradient(
                    Gradient(colors: [house.color.ui,
                                      house.color.ui.opacity(0.82)]),
                    startPoint: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
                    endPoint: CGPoint(x: bodyRect.midX, y: bodyRect.maxY)))

        // Tejado triangular
        let roofHeight = h * 0.66
        let overhang = w * 0.10
        var roof = Path()
        roof.move(to: CGPoint(x: bodyRect.minX - overhang,
                              y: bodyRect.minY + h * 0.30))
        roof.addLine(to: CGPoint(x: bodyRect.midX,
                                 y: bodyRect.minY - roofHeight))
        roof.addLine(to: CGPoint(x: bodyRect.maxX + overhang,
                                 y: bodyRect.minY + h * 0.30))
        roof.closeSubpath()

        ctx.fill(roof, with: .color(house.color.deep))
        ctx.stroke(roof,
                   with: .color(Color.black.opacity(0.14)),
                   lineWidth: max(0.8, geo.cell * 0.015))

        // Ventana
        let winSize = max(1.6, geo.cell * 0.11)
        var winRect = CGRect(x: bodyRect.midX - winSize / 2,
                             y: bodyRect.minY + h * 0.44,
                             width: winSize, height: winSize)
        if dir.dy > 0.5 {
            winRect.origin.y = bodyRect.minY + h * 0.36
        }
        ctx.fill(Path(roundedRect: winRect, cornerRadius: winSize * 0.20),
                 with: .color(palette.surface.opacity(0.92)))
        ctx.stroke(Path(roundedRect: winRect, cornerRadius: winSize * 0.20),
                   with: .color(palette.ink.opacity(0.18)),
                   lineWidth: max(0.6, geo.cell * 0.012))

        // Puerta orientada hacia su calle de entrada
        let doorW = max(1.8, geo.cell * 0.13)
        let doorH = max(2, geo.cell * 0.15)
        let doorRect = accessRect(in: bodyRect, dir: dir,
                                  width: doorW, height: doorH)
        ctx.fill(Path(roundedRect: doorRect, cornerRadius: doorW * 0.28),
                 with: .color(palette.ink.opacity(0.42)))

        // Cola de coches esperando junto a la casa
        let waiting = min(house.queue, House.capacity)
        if waiting > 0 {
            let dot = max(1.4, geo.cell * 0.075)
            let spacing = dot * 2.4
            let total = spacing * CGFloat(waiting - 1)
            let above = house.pos.y > 0
            let y = above
                ? bodyRect.minY - roofHeight - dot * 1.6
                : bodyRect.maxY + dot * 1.6

            for i in 0..<waiting {
                let x = c.x - total / 2 + CGFloat(i) * spacing
                let dotRect = CGRect(x: x - dot / 2, y: y - dot / 2,
                                     width: dot, height: dot)
                ctx.fill(Path(ellipseIn: dotRect),
                         with: .color(house.color.deep))
            }
        }

        // Alarma cuando se acumulan coches
        if house.panic > 0.02 {
            let radius = geo.cell * 0.42
            let ring = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius,
                                              width: radius * 2, height: radius * 2))
            let pulse = 0.35 + 0.45 * abs(sin(state.elapsed * 5))
            ctx.stroke(ring,
                       with: .color(palette.danger.opacity(house.panic * pulse)),
                       lineWidth: max(1, geo.cell * 0.05))
        }
    }

    // MARK: Efectos flotantes

    private func drawEffects(_ ctx: inout GraphicsContext) {
        for effect in state.effects {
            let progress = min(1, effect.age / effect.life)
            let p = geo.screen(effect.pos)
            let rise = CGFloat(progress) * geo.cell * 0.75
            let faded = 1 - progress
            var text = ctx.resolve(
                Text(effect.text)
                    .font(.system(size: max(7, geo.cell * 0.27),
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundColor(effect.color.deep)
            )
            text.shading = .color(effect.color.deep.opacity(faded))
            ctx.draw(text,
                     at: CGPoint(x: p.x, y: p.y - rise),
                     anchor: .center)
        }
    }

    // MARK: Utilidades

    private func directionVector(from a: GridPoint, to b: GridPoint) -> CGPoint {
        let dx = CGFloat(b.x - a.x)
        let dy = CGFloat(b.y - a.y)
        let length = max(abs(dx) + abs(dy), 1)
        return CGPoint(x: dx / length, y: dy / length)
    }

    /// Coloca la puerta en el lado del edificio que mira a su calle de entrada.
    private func accessRect(in rect: CGRect,
                            dir: CGPoint,
                            width: CGFloat,
                            height: CGFloat) -> CGRect {
        if abs(dir.x) >= abs(dir.y) {
            let x = dir.x > 0 ? rect.maxX - width * 0.75 : rect.minX - width * 0.25
            return CGRect(x: x,
                          y: rect.midY - height / 2,
                          width: width,
                          height: height)
        } else {
            let y = dir.y > 0 ? rect.maxY - height * 0.75 : rect.minY - height * 0.25
            return CGRect(x: rect.midX - width / 2,
                          y: y,
                          width: width,
                          height: height)
        }
    }
}

// MARK: - Raíz

struct RootView: View {
    @StateObject private var engine = GameEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let isPortrait = proxy.size.height > proxy.size.width

            ZStack {
                if isPortrait {
                    RotateDeviceView(palette: GamePalette.named(engine.settings.themeID))
                } else {
                    switch engine.state.phase {
                    case .menu:
                        StartMenuView(engine: engine)
                    default:
                        GameScreen(engine: engine)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: engine.state.phase)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                engine.autoPause()
            }
        }
    }
}

// MARK: - Pantalla de juego

struct GameScreen: View {
    @ObservedObject var engine: GameEngine

    private var palette: GamePalette {
        GamePalette.named(engine.settings.themeID)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.bgTop, palette.bgBottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HUDView(engine: engine, palette: palette)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                BoardView(engine: engine, palette: palette)
                    .padding(.horizontal, 12)

                BottomBarView(engine: engine, palette: palette)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }

            if engine.state.phase == .paused {
                PauseOverlay(engine: engine, palette: palette)
            }

            if engine.state.phase == .gameOver {
                GameOverOverlay(engine: engine, palette: palette)
            }
        }
        .preferredColorScheme(palette.isDark ? .dark : .light)
    }
}

// MARK: - Tablero interactivo

struct BoardView: View {
    @ObservedObject var engine: GameEngine
    let palette: GamePalette

    @State private var pointer: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let geo = BoardGeometry(available: proxy.size,
                                    cols: engine.state.cols,
                                    rows: engine.state.rows)

            ZStack {
                Canvas { context, _ in
                    var ctx = context
                    let renderer = BoardRenderer(geo: geo,
                                                 state: engine.state,
                                                 palette: palette,
                                                 showGuides: engine.settings.showGuides)
                    renderer.draw(&ctx)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let point = geo.gridPoint(at: value.location) else {
                                pointer = nil
                                return
                            }
                            pointer = value.location
                            if engine.isStroking {
                                engine.continueStroke(to: point)
                            } else {
                                engine.beginStroke(at: point)
                            }
                        }
                        .onEnded { _ in
                            pointer = nil
                            engine.endStroke()
                        }
                )

                if let pointer = pointer,
                   let point = geo.gridPoint(at: pointer),
                   let snapped = snappedNode(for: point) {
                    let p = geo.screen(snapped)
                    Circle()
                        .stroke(palette.ink.opacity(0.35), lineWidth: 1.5)
                        .frame(width: max(8, geo.cell * 0.34),
                               height: max(8, geo.cell * 0.34))
                        .position(p)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func snappedNode(for point: GridPoint) -> GridPoint? {
        var buildingSnap: GridPoint?
        var buildingDistance = Int.max

        for house in engine.state.houses {
            let distance = abs(house.pos.x - point.x) + abs(house.pos.y - point.y)
            if distance <= 1 && distance < buildingDistance {
                buildingDistance = distance
                buildingSnap = house.driveway
            }
        }
        for mall in engine.state.malls {
            let distance = abs(mall.pos.x - point.x) + abs(mall.pos.y - point.y)
            if distance <= 1 && distance < buildingDistance {
                buildingDistance = distance
                buildingSnap = mall.driveway
            }
        }
        if let buildingSnap = buildingSnap { return buildingSnap }

        var best: GridPoint?
        var bestDistance = Int.max
        for node in engine.state.guideNodes {
            let distance = abs(node.x - point.x) + abs(node.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                best = node
            }
        }
        if let best = best, bestDistance <= 1 {
            return best
        }
        return nil
    }
}

// MARK: - HUD superior

struct HUDView: View {
    @ObservedObject var engine: GameEngine
    let palette: GamePalette

    private var state: GameState { engine.state }

    private var timeText: String {
        let total = Int(state.elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var asphaltFraction: Double {
        guard state.maxBudget > 0 else { return 0 }
        return min(1, max(0, Double(state.budget) / Double(state.maxBudget)))
    }

    var body: some View {
        HStack(spacing: 12) {
            // Puntuación
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(palette.ink)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Viajes")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.inkSoft)
                    Text("\(state.score)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(palette.ink)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(panelBackground)

            // Asfalto
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.inkSoft)
                    Text("Asfalto")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.inkSoft)
                    Text("\(state.budget)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(palette.ink)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.stroke.opacity(0.55))
                        Capsule()
                            .fill(state.budgetPulse > 0.01
                                  ? palette.danger
                                  : palette.ink.opacity(0.75))
                            .frame(width: max(4, proxy.size.width * CGFloat(asphaltFraction)))
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: 220)
            .background(panelBackground)

            // Tiempo
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(palette.inkSoft)
                Text(timeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(palette.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(panelBackground)

            Spacer(minLength: 4)

            // Récord
            VStack(alignment: .trailing, spacing: 0) {
                Text("Récord")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(palette.inkSoft)
                Text("\(state.bestScore)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(palette.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(panelBackground)

            Button {
                engine.togglePause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(palette.onButton)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(palette.button)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.panelStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Barra inferior

struct BottomBarView: View {
    @ObservedObject var engine: GameEngine
    let palette: GamePalette

    var body: some View {
        HStack(spacing: 10) {
            Text("Arrastra sobre el tablero para trazar calles y unir cada casa con un centro comercial de su color.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            toolbarButton(
                title: engine.settings.showGuides ? "Ocultar guías" : "Ver guías",
                icon: engine.settings.showGuides ? "eye.slash" : "eye",
                active: engine.settings.showGuides
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    engine.toggleGuides()
                }
            }

            toolbarButton(
                title: engine.state.eraseMode ? "Borrando" : "Borrar",
                icon: "eraser",
                active: engine.state.eraseMode
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    engine.toggleErase()
                }
            }

            toolbarButton(title: "Reiniciar", icon: "arrow.counterclockwise", active: false) {
                engine.restart()
            }

            toolbarButton(title: "Menú", icon: "house", active: false) {
                engine.returnToMenu()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.panelStroke, lineWidth: 1)
                )
        )
    }

    private func toolbarButton(title: String,
                               icon: String,
                               active: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(active ? palette.onButton : palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(active ? palette.button : palette.surface)
            )
            .overlay(
                Capsule()
                    .stroke(active ? Color.clear : palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pantalla de inicio

struct StartMenuView: View {
    @ObservedObject var engine: GameEngine

    @State private var showResetConfirm = false

    private var palette: GamePalette {
        GamePalette.named(engine.settings.themeID)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.bgTop, palette.bgBottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Adornos de fondo
            Circle()
                .fill(palette.button.opacity(0.05))
                .frame(width: 420, height: 420)
                .offset(x: -260, y: 160)
            Circle()
                .fill(palette.button.opacity(0.04))
                .frame(width: 300, height: 300)
                .offset(x: 320, y: -140)

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(spacing: 26) {
                        hero
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 26)

                        settingsPanel
                            .frame(width: min(380, max(300, proxy.size.width * 0.44)))
                            .padding(.trailing, 26)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(palette.isDark ? .dark : .light)
        .alert("¿Borrar el récord?", isPresented: $showResetConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) {
                engine.resetBest()
            }
        } message: {
            Text("La mejor puntuación guardada se pondrá a cero.")
        }
    }

    // MARK: Columna izquierda

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(palette.onButton)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(palette.button))
                Text("MINI RUTAS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(4)
                    .foregroundColor(palette.inkSoft)
            }

            Text("Pequeñas calles,\ngrandes ciudades.")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundColor(palette.ink)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Traza carreteras sobre una red invisible y conecta cada casa con su centro comercial. Sin atascos, sin prisas… al principio.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 330, alignment: .leading)

            // Mini ilustración
            Canvas { context, size in
                var ctx = context
                drawPreview(&ctx, size: size)
            }
            .frame(width: 260, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.surface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.stroke, lineWidth: 1)
                    )
            )

            HStack(spacing: 14) {
                Label("\(engine.state.bestScore)", systemImage: "trophy.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(palette.ink)

                Label("Casas → centros", systemImage: "arrow.right")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(palette.inkSoft)
            }
        }
    }

    private func drawPreview(_ ctx: inout GraphicsContext, size: CGSize) {
        let baseY = size.height - 16
        var road = Path()
        road.move(to: CGPoint(x: 22, y: baseY - 18))
        road.addLine(to: CGPoint(x: size.width - 30, y: baseY - 18))
        ctx.stroke(road,
                   with: .color(palette.roadCasing),
                   style: StrokeStyle(lineWidth: 12, lineCap: .round))
        ctx.stroke(road,
                   with: .color(palette.road),
                   style: StrokeStyle(lineWidth: 8, lineCap: .round))

        let houses: [(CGFloat, BuildingColor)] = [
            (52, .red), (102, .blue), (152, .yellow)
        ]
        for (x, color) in houses {
            let rect = CGRect(x: x - 16, y: baseY - 54, width: 32, height: 24)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 4),
                     with: .color(color.ui))
            var roof = Path()
            roof.move(to: CGPoint(x: rect.minX - 3, y: rect.minY + 4))
            roof.addLine(to: CGPoint(x: rect.midX, y: rect.minY - 16))
            roof.addLine(to: CGPoint(x: rect.maxX + 3, y: rect.minY + 4))
            roof.closeSubpath()
            ctx.fill(roof, with: .color(color.deep))
            var stub = Path()
            stub.move(to: CGPoint(x: x, y: rect.maxY))
            stub.addLine(to: CGPoint(x: x, y: baseY - 18))
            ctx.stroke(stub,
                       with: .color(palette.road),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }

        let mallRect = CGRect(x: size.width - 92, y: baseY - 56,
                              width: 62, height: 38)
        ctx.fill(Path(roundedRect: mallRect, cornerRadius: 6),
                 with: .color(BuildingColor.green.ui))
        ctx.fill(Path(roundedRect: CGRect(x: mallRect.minX,
                                          y: mallRect.minY,
                                          width: mallRect.width,
                                          height: mallRect.height * 0.3),
                      cornerRadius: 5),
                 with: .color(BuildingColor.green.deep))
        var stub = Path()
        stub.move(to: CGPoint(x: mallRect.midX, y: mallRect.maxY))
        stub.addLine(to: CGPoint(x: mallRect.midX, y: baseY - 18))
        ctx.stroke(stub,
                   with: .color(palette.road),
                   style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }

    // MARK: Columna derecha

    private var settingsPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Tema")

                HStack(spacing: 10) {
                    ForEach(GamePalette.all) { theme in
                        themeCard(theme)
                    }
                }

                sectionTitle("Dificultad")

                HStack(spacing: 8) {
                    ForEach(Difficulty.allCases) { difficulty in
                        Button {
                            engine.settings.difficulty = difficulty
                        } label: {
                            Text(difficulty.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(engine.settings.difficulty == difficulty
                                                 ? palette.onButton
                                                 : palette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(engine.settings.difficulty == difficulty
                                              ? palette.button
                                              : palette.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(engine.settings.difficulty == difficulty
                                                ? Color.clear
                                                : palette.stroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(engine.settings.difficulty.subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(palette.inkSoft)
                    .padding(.top, -4)

                Toggle(isOn: Binding(
                    get: { engine.settings.showGuides },
                    set: { _ in engine.toggleGuides() }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ver red de rutas")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(palette.ink)
                        Text("Muestra la cuadrícula oculta por la que puedes trazar.")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(palette.inkSoft)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: palette.button))

                Button {
                    engine.startGame()
                } label: {
                    HStack(spacing: 8) {
                        Text("Empezar a jugar")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(palette.onButton)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.button)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                HStack {
                    Text("Récord: \(engine.state.bestScore)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.inkSoft)

                    Spacer()

                    Button("Borrar récord") {
                        showResetConfirm = true
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(palette.inkSoft)
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.panelStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 8)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .kerning(1.5)
            .foregroundColor(palette.inkSoft)
    }

    private func themeCard(_ theme: GamePalette) -> some View {
        let selected = engine.settings.themeID == theme.id
        return Button {
            engine.settings.themeID = theme.id
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [theme.bgTop, theme.bgBottom],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(theme.board)
                            .padding(5)
                    )
                    .overlay(
                        VStack(spacing: 3) {
                            Capsule()
                                .fill(theme.road)
                                .frame(width: 30, height: 3)
                            HStack(spacing: 3) {
                                Circle().fill(BuildingColor.red.ui).frame(width: 7, height: 7)
                                Circle().fill(BuildingColor.blue.ui).frame(width: 7, height: 7)
                                Circle().fill(BuildingColor.yellow.ui).frame(width: 7, height: 7)
                            }
                        }
                    )
                    .frame(height: 46)

                Text(theme.name)
                    .font(.system(size: 11, weight: selected ? .bold : .medium,
                                  design: .rounded))
                    .foregroundColor(palette.ink)
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? palette.button : palette.stroke,
                            lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pausa

struct PauseOverlay: View {
    @ObservedObject var engine: GameEngine
    let palette: GamePalette

    var body: some View {
        overlayCard {
            VStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundColor(palette.button)

                Text("Pausa")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(palette.ink)

                Text("La ciudad te espera.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(palette.inkSoft)

                VStack(spacing: 8) {
                    primaryButton("Continuar") { engine.togglePause() }
                    secondaryButton("Reiniciar") { engine.restart() }
                    secondaryButton("Volver al menú") { engine.returnToMenu() }
                }
                .padding(.top, 4)
            }
            .frame(width: 240)
        }
    }

    private func primaryButton(_ title: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(palette.onButton)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(palette.button))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(palette.isDark ? 0.55 : 0.28)
                .ignoresSafeArea()
                .onTapGesture {}

            content()
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(palette.panelStroke, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.22),
                                radius: 24, x: 0, y: 12)
                )
        }
        .transition(.opacity)
    }
}

// MARK: - Fin de partida

struct GameOverOverlay: View {
    @ObservedObject var engine: GameEngine
    let palette: GamePalette

    var body: some View {
        ZStack {
            Color.black.opacity(palette.isDark ? 0.60 : 0.32)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(palette.danger)

                Text("Fin de la partida")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(palette.ink)

                Text(engine.state.gameOverMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 22) {
                    statBlock(title: "Viajes", value: "\(engine.state.score)")
                    statBlock(title: "Récord", value: "\(engine.state.bestScore)")
                }
                .padding(.vertical, 6)

                VStack(spacing: 8) {
                    Button {
                        engine.restart()
                    } label: {
                        Text("Jugar otra vez")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(palette.onButton)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(palette.button))
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.returnToMenu()
                    } label: {
                        Text("Volver al menú")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(palette.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(palette.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 270)
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(palette.panelStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.24),
                            radius: 26, x: 0, y: 12)
            )
        }
        .transition(.opacity)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .kerning(1.2)
                .foregroundColor(palette.inkSoft)
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(palette.ink)
        }
    }
}

// MARK: - Pantalla para girar el dispositivo

struct RotateDeviceView: View {
    let palette: GamePalette

    @State private var tilt = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.bgTop, palette.bgBottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "iphone.landscape")
                    .font(.system(size: 46, weight: .regular))
                    .foregroundColor(palette.ink)
                    .rotationEffect(.degrees(tilt ? -90 : 0))
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                               value: tilt)

                Text("Gira el dispositivo")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(palette.ink)

                Text("Mini Rutas se juega en horizontal.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(palette.inkSoft)
            }
        }
        .preferredColorScheme(palette.isDark ? .dark : .light)
        .onAppear { tilt = true }
    }
}

// MARK: - Entrada de la app

@main
struct MiniRutasApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(iOS)
        RootView()
            .statusBarHidden(true)
        #else
        RootView()
        #endif
    }
}

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
    -> UIInterfaceOrientationMask {
        .landscape
    }
}
#endif

