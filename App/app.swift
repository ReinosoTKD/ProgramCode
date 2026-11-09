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
