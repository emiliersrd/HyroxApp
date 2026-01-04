// swift
import SwiftUI

struct HomeView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "fr" // "en" or "fr"

    private var titleText: String { "HYROX" }
    private var howToTrainText: String { appLanguage == "en" ? "How to train" : "Comment s'entraîner" }
    private var selectVideoText: String { appLanguage == "en" ? "Analyze your movement" : "Analyse ton mouvement" }
    private var compareText: String { appLanguage == "en" ? "Compare" : "Comparer" }
    private var skeletonTrackingText: String { appLanguage == "en" ? "Live skeleton tracking" : "Skeleton tracking en direct" }
    private var languageLabelText: String { appLanguage == "en" ? "Language" : "Langage" }

    var body: some View {
        VStack(spacing:10) {
            HStack {
                Spacer()
                Menu {
                    Button("English") { appLanguage = "en" }
                    Button("Français") { appLanguage = "fr" }
                } label: {
                    Text(languageLabelText)
                        .font(.subheadline)
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.yellow.opacity(0.95))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
                }
            }
            .padding(.horizontal)

            Spacer()

            Text(titleText)
                .font(.system(size: 34, weight: .black, design: .default))
                .foregroundColor(.primary)

            Spacer()

            VStack(spacing: 14) {
                NavigationLink(destination: HowToTrainView()) {
                    Text(howToTrainText)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                }

                NavigationLink(destination: RenameLabelView()) {
                    Text(selectVideoText)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                }

                NavigationLink(destination: CompareVideosView()) {
                    Text(compareText)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                }

                NavigationLink(destination: SkeletonTrackingView()) {
                    Text(skeletonTrackingText)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
        }
    }
}
