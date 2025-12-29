import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("HYROX")
                .font(.system(size: 34, weight: .black, design: .default))
                .foregroundColor(.primary)

            // Placeholder hero area (replace with actual artwork later)
            Rectangle()
                .fill(Color.black)
                .frame(height: 220)
                .cornerRadius(12)
                .overlay(
                    Text("Coach preview")
                        .foregroundColor(.white)
                        .font(.headline)
                )

            Spacer()

            VStack(spacing: 14) {
                NavigationLink(destination: HowToTrainView()) {
                    Text("How to train")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                }

                NavigationLink(destination: RenameLabelView()) {
                    Text("Rename label")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                }

                NavigationLink(destination: SkeletonTrackingView()) {
                    Text("Skeleton tracking")
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
