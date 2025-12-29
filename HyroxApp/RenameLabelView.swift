import SwiftUI

struct RenameLabelView: View {
    @StateObject private var viewModel = RenameViewModel()
    @State private var newName: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename label")
                .font(.largeTitle)
                .bold()

            TextField("Enter new label name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button(action: {
                viewModel.save(name: newName)
            }, label: {
                Text("Save")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            })
            .padding(.horizontal)

            if let current = viewModel.currentName {
                Text("Current name: \(current)")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            newName = viewModel.currentName ?? ""
        }
        .navigationTitle("Rename")
    }
}

struct RenameLabelView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RenameLabelView()
        }
    }
}
