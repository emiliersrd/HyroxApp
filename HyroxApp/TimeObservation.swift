// swift
// File: `HyroxApp/TimeObservation.swift`
import Foundation
import CoreMedia
import Vision

public struct TimedObservation {
    public let time: CMTime
    public let observation: VNHumanBodyPoseObservation

    public init(time: CMTime, observation: VNHumanBodyPoseObservation) {
        self.time = time
        self.observation = observation
    }
}
