//
//  CompareVideosView.swift
//  HyroxApp
//
//  Created by mac on 04/01/2026.
//

// swift
// File: `HyroxApp/CompareVideosView.swift`
import SwiftUI
import AVKit
import Vision
import CoreMedia

struct CompareVideosView: View {
    @State private var leftURL: URL?
    @State private var rightURL: URL?
    @State private var showLeftPicker = false
    @State private var showRightPicker = false

    private let analyzer = SkeletonAnalyzer()

    @State private var leftPlayer: AVPlayer?
    @State private var rightPlayer: AVPlayer?
    @State private var leftObservations: [TimedObservation] = []
    @State private var rightObservations: [TimedObservation] = []

    @State private var isAnalyzing = false
    @State private var currentTime: CMTime = .zero
    @State private var timeObserverToken: Any?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Button("Select Left Video") { showLeftPicker = true }
                        .buttonStyle(.borderedProminent)
                    Text(leftURL?.lastPathComponent ?? "No video selected")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                VStack(alignment: .leading) {
                    Button("Select Right Video") { showRightPicker = true }
                        .buttonStyle(.borderedProminent)
                    Text(rightURL?.lastPathComponent ?? "No video selected")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal)

            if isAnalyzing {
                ProgressView("Analyzing...")
                    .padding(.top, 6)
            }

            HStack(spacing: 8) {
                analyzeAndPlayButtons
            }
            .padding(.horizontal)

            // Players side-by-side
            HStack(spacing: 8) {
                playerView(player: leftPlayer, observations: leftObservations)
                playerView(player: rightPlayer, observations: rightObservations)
            }
            .frame(maxHeight: 360) // adjust as needed

            Spacer()
        }
        .padding(.vertical)
        .sheet(isPresented: $showLeftPicker) {
            VideoPicker(selectedURL: $leftURL)
        }
        .sheet(isPresented: $showRightPicker) {
            VideoPicker(selectedURL: $rightURL)
        }
        .onDisappear {
            stopPlayback()
        }
        .navigationTitle("Compare Videos")
    }

    private var analyzeAndPlayButtons: some View {
        HStack(spacing: 12) {
            Button("Analyze & Play Both") {
                guard let l = leftURL, let r = rightURL else { return }
                analyzeBothAndPlay(left: l, right: r)
            }
            .disabled(leftURL == nil || rightURL == nil || isAnalyzing)
            .buttonStyle(.borderedProminent)

            Button("Play Both (no analysis)") {
                guard let l = leftURL, let r = rightURL else { return }
                playBoth(left: l, right: r)
            }
            .disabled(leftURL == nil || rightURL == nil)
            .buttonStyle(.bordered)
        }
    }

    private func playerView(player: AVPlayer?, observations: [TimedObservation]) -> some View {
        ZStack {
            if let p = player {
                VideoPlayer(player: p)
                    .onDisappear { stopPlayback() }
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .overlay(Text("Ready to play"))
            }

            if !observations.isEmpty {
                SkeletonOverlayView(
                    observations: observations.map { (time: $0.time, observation: $0.observation) },
                    currentTime: currentTime
                )
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(8)
        .clipped()
    }

    // MARK: - Analysis & Playback

    private func analyzeBothAndPlay(left: URL, right: URL) {
        isAnalyzing = true
        leftObservations = []
        rightObservations = []

        let group = DispatchGroup()
        var leftResult: [TimedObservation] = []
        var rightResult: [TimedObservation] = []

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            analyzer.analyzeAsset(url: left) { obs in
                leftResult = obs
                group.leave()
            }
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            analyzer.analyzeAsset(url: right) { obs in
                rightResult = obs
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isAnalyzing = false
            self.leftObservations = leftResult
            self.rightObservations = rightResult
            self.playBoth(left: left, right: right)
        }
    }

    private func playBoth(left: URL, right: URL) {
        stopPlayback()

        let lp = AVPlayer(url: left)
        let rp = AVPlayer(url: right)

        // Seek both to start with zero tolerance
        let zero = CMTime.zero
        lp.seek(to: zero, toleranceBefore: .zero, toleranceAfter: .zero)
        rp.seek(to: zero, toleranceBefore: .zero, toleranceAfter: .zero)

        self.leftPlayer = lp
        self.rightPlayer = rp
        self.currentTime = .zero

        // Start both players as close together as possible
        DispatchQueue.main.async {
            lp.play()
            rp.play()
        }

        // Single periodic observer to update currentTime for overlays
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = lp.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time
        }
    }

    private func stopPlayback() {
        if let token = timeObserverToken, let lp = leftPlayer {
            lp.removeTimeObserver(token)
            timeObserverToken = nil
        }
        leftPlayer?.pause()
        rightPlayer?.pause()
        leftPlayer = nil
        rightPlayer = nil
        currentTime = .zero
    }
}
