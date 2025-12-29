import SwiftUI

struct HowToTrainView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How to train")
                    .font(.largeTitle)
                    .bold()

                // Placeholder list of exercises
                ForEach(0..<8) { i in
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 96, height: 72)
                            .cornerRadius(8)
                            .overlay(Text("Vid"))

                        VStack(alignment: .leading) {
                            Text("Exercise \(i + 1)")
                                .font(.headline)
                            Text("Short description about the exercise and coaching tips.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("How to train")
    }
}

struct HowToTrainView_Previews: PreviewProvider {
    static var previews: some View {
        HowToTrainView()
    }
}
