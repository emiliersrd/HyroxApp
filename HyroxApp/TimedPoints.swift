//
//  TimedPoints.swift
//  HyroxApp
//
//  Created by mac on 04/01/2026.
//

// swift
import SwiftUI
import CoreMedia

struct TimedPoints {
    let time: CMTime
    let points: [CGPoint] // normalized (0..1) coordinates, y already flipped by convertToTimedPoints
}
