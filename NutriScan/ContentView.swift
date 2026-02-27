import SwiftUI
import Combine

class ViewModel: ObservableObject {
    @Published var analysisResult = "Henüz analiz yapılmadı"
    @Published var isLoading = false
    
    let apiKey = "YOUR_API_KEY"
    
    func analyzeImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        
        self.isLoading = true
        self.analysisResult = "Analiz ediliyor..."
        
        
        let base64Image = imageData.base64EncodedString()
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": "Bu fotoğraftaki yiyeceği tanı. Yiyeceğin adını, tahmini kalori miktarını ve kısa besin değerlerini Türkçe olarak yaz."],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                ]
            ]]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let d = data,
                   let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    self.analysisResult = text
                } else {
                    self.analysisResult = "Hata oluştu."
                }
            }
        }.resume()
    }
}

struct ContentView: View {
    @StateObject private var vm = ViewModel()
    @State private var showCamera = false
    @State private var selectedImage: UIImage? = nil

    var body: some View {
        ZStack {
            Color(.systemGreen).opacity(0.1).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text("🥗 NutriScan")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.green)
                    
                    Text("Yiyeceğini tara, kalorisini öğren")
                        .font(.subheadline).foregroundColor(.gray)
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .frame(height: 250).cornerRadius(15).padding(.horizontal)
                    } else {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.2)).frame(height: 250)
                            .overlay(Text("Henüz fotoğraf çekilmedi").foregroundColor(.gray))
                            .padding(.horizontal)
                    }
                    
                    Button(action: { showCamera = true }) {
                        Label("Fotoğraf Çek", systemImage: "camera.fill")
                            .font(.title2).padding()
                            .background(Color.green).foregroundColor(.white).cornerRadius(15)
                    }
                    
                    if selectedImage != nil {
                        Button(action: {
                            if let img = selectedImage { vm.analyzeImage(img) }
                        }) {
                            if vm.isLoading {
                                ProgressView().padding()
                                    .background(Color.blue).cornerRadius(15)
                            } else {
                                Label("Analiz Et", systemImage: "wand.and.stars")
                                    .font(.title2).padding()
                                    .background(Color.blue).foregroundColor(.white).cornerRadius(15)
                            }
                        }
                        .disabled(vm.isLoading)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📊 Analiz Sonucu")
                            .font(.headline).foregroundColor(.green)
                        Text(vm.analysisResult)
                            .font(.body)
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $selectedImage)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}

#Preview { ContentView() }
