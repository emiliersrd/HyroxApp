import SwiftUI

struct HowToTrainView: View {
    // Sample data for MVP - later this can be loaded from a JSON file or API
    let exercises: [Exercise] = [
        Exercise(title: "Burpee", shortDescription: "Full body explosive movement", longDescription: "Start standing, drop to a plank, perform a push-up, return to standing and jump up. Focus on controlled descent and soft landing.", videoURLString: "https://youtu.be/UTO-GzRXF-Q?si=sunQ4vSAf7dcrK-s"),
        Exercise(title: "Farmer's Carry", shortDescription: "Grip and core strength", longDescription: "Hold heavy weights at your sides and walk for distance. Keep torso upright and shoulders back.", videoURLString: "https://youtu.be/KI_TkxBSFOI?si=vfCD2kMD_ynSwjOU"),
        Exercise(title: "Sled Push", shortDescription: "Leg power", longDescription: "Drive through the legs, maintain a forward lean and short ground contact time.", videoURLString: "https://youtu.be/pVVBD5Gh-J4?si=fLjtqj2wtQmdeUCY"),
        Exercise(title: "Wall Balls", shortDescription: "Explosive squat to throw", longDescription: "Catch the ball low and drive through your hips to throw up to the target. Maintain depth in the squat.", videoURLString: "https://youtu.be/bm7QLEOx26c?si=y1TtdjtwEOVu2Yny"),
        
        // Newly added exercises requested by the user
        Exercise(title: "Sled Pull", shortDescription: "Pulling power and posterior chain", longDescription: "Anchor a sled and pull it towards you using long, powerful strides. Keep shoulders engaged, hips back and maintain a steady cadence. Useful to develop hamstrings and glute strength.", videoURLString: "https://youtu.be/K2FhsenkS3U?si=AjDHN1bxWXhkzyJM"),
        Exercise(title: "Lunges", shortDescription: "Single-leg strength and balance", longDescription: "Step forward (or backward) into a deep lunge, keeping the front knee tracking over the toes. Drive through the front heel to return. Alternate legs and control the tempo to build stability and strength.", videoURLString: "https://youtu.be/YlFsbfK5Doc?si=A8qzY4FvL2fX-WhM"),
        Exercise(title: "Rowing", shortDescription: "Full-body power and endurance", longDescription: "Row with powerful leg drive, a strong hip hinge and coordinated arm pull. Focus on a long, smooth stroke: legs -> hips -> arms on the drive; arms -> hips -> legs on the recovery. Maintain consistent stroke rate and a strong finish to build both power and endurance for Hyrox events.", videoURLString: "https://youtu.be/KI_TkxBSFOI?si=vfCD2kMD_ynSwjOU")
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                ForEach(exercises) { ex in
                    NavigationLink(destination: ExerciseDetailView(exercise: ex)) {
                        ExerciseRow(exercise: ex)
                            .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Divider()
                        .padding(.leading, 116) // align divider after thumbnail
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("How to train")
    }
}

struct HowToTrainView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HowToTrainView()
        }
    }
}
