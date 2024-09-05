//
//  ViewController.swift
//  DocRakshak
//
//  Created by admin33 on 30/08/24.
//

import UIKit
import VisionKit
import Vision
import AVFoundation
import MobileCoreServices
import PDFKit

func requestCameraAccess(completion: @escaping (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        completion(true)
        
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        
    case .denied, .restricted:
        completion(false)
        
    @unknown default:
        completion(false)
    }
}

func testModel(with text: String) -> MyTextClassifier69Output? {
    do {
        let model = try MyTextClassifier69(configuration: MLModelConfiguration())
        let input = MyTextClassifier69Input(text: text)
        let prediction = try model.prediction(input: input)
        return prediction
    } catch {
        print("Error in model prediction: \(error)")
        return nil
    }
}

class HomeViewController: UIViewController {

    private var savedFiles: [URL] = []
    
    @IBOutlet weak var LabelShit: UILabel!
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTableView()
        loadSavedFiles()
    }
    
    @IBAction func cameraButton(_ sender: Any) {
        requestCameraAccess { granted in
            if granted {
                self.configureDocumentView()
            } else {
                self.showPermissionDeniedAlert()
            }
        }
    }
    
    @IBAction func addDocumentButton(_ sender: UIBarButtonItem) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }
    
    private func setupTableView() {
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func loadSavedFiles() {
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
                savedFiles = fileURLs.filter { $0.pathExtension == "txt" }
                tableView.reloadData()
            } catch {
                print("Error loading files from directory: \(error)")
            }
        }
    }

    @IBAction func documentScanner(_ sender: UIButton) {
        requestCameraAccess { granted in
            if granted {
                self.configureDocumentView()
            } else {
                self.showPermissionDeniedAlert()
            }
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(title: "Camera Permission Denied", message: "Please enable camera access in Settings to use the document scanner.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    private func configureDocumentView() {
        let scanningDocumentVC = VNDocumentCameraViewController()
        scanningDocumentVC.delegate = self
        self.present(scanningDocumentVC, animated: true, completion: nil)
    }
}

extension HomeViewController: VNDocumentCameraViewControllerDelegate, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }

        if selectedFileURL.startAccessingSecurityScopedResource() {
            defer { selectedFileURL.stopAccessingSecurityScopedResource() }

            do {
                let fileData = try Data(contentsOf: selectedFileURL)

                if selectedFileURL.pathExtension.lowercased() == "pdf" {
                    if let pdfDocument = PDFDocument(url: selectedFileURL) {
                        var images = [UIImage]()

                        // Iterate over each page in the PDF
                        for pageIndex in 0..<pdfDocument.pageCount {
                            if let pdfPage = pdfDocument.page(at: pageIndex) {
                                let pageRect = pdfPage.bounds(for: .mediaBox)
                                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                                let img = renderer.image { ctx in
                                    UIColor.white.set()
                                    ctx.fill(pageRect)
                                    ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                                    pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
                                }
                                images.append(img)
                            }
                        }

                        recognizeText(from: images) { recognizedText in
                            self.promptForFileName { fileName in
                                let maskedText = self.maskPII(in: recognizedText)

                                // Save the unmasked version
                                if let unmaskedFileURL = self.saveTextToFile(recognizedText, preferredFileName: fileName, isMasked: false) {
                                    print("Unmasked text successfully saved to file: \(unmaskedFileURL)")
                                }

                                // Save the masked version
                                if let maskedFileURL = self.saveTextToFile(maskedText, preferredFileName: fileName, isMasked: true) {
                                    print("Masked text successfully saved to file: \(maskedFileURL)")
                                }

                                self.loadSavedFiles()  // Reload files in DownloadsViewController
                            }
                        }
                    }
                } else {
                    if let image = UIImage(data: fileData) {
                        recognizeText(from: [image]) { recognizedText in
                            self.promptForFileName { fileName in
                                let maskedText = self.maskPII(in: recognizedText)

                                // Save the unmasked version
                                if let unmaskedFileURL = self.saveTextToFile(recognizedText, preferredFileName: fileName, isMasked: false) {
                                    print("Unmasked text successfully saved to file: \(unmaskedFileURL)")
                                }

                                // Save the masked version
                                if let maskedFileURL = self.saveTextToFile(maskedText, preferredFileName: fileName, isMasked: true) {
                                    print("Masked text successfully saved to file: \(maskedFileURL)")
                                }

                                self.loadSavedFiles()  // Reload files in DownloadsViewController
                            }
                        }
                    } else {
                        print("Unable to process the selected file as an image.")
                    }
                }
            } catch {
                print("Error handling selected file: \(error)")
            }
        } else {
            print("Permission to access the file was denied.")
        }
    }

    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var scannedImages = [UIImage]()
        
        for pageNumber in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageNumber)
            scannedImages.append(image)
        }
        
        controller.dismiss(animated: true, completion: {
            self.promptForFileName { fileName in
                self.recognizeText(from: scannedImages) { recognizedText in
                    let maskedText = self.maskPII(in: recognizedText)

                    // Save the unmasked version
                    if let unmaskedFileURL = self.saveTextToFile(recognizedText, preferredFileName: fileName, isMasked: false) {
                        print("Unmasked file saved at: \(unmaskedFileURL)")
                    }

                    // Save the masked version
                    if let maskedFileURL = self.saveTextToFile(maskedText, preferredFileName: fileName, isMasked: true) {
                        print("Masked file saved at: \(maskedFileURL)")
                    }

                    // Load files in DownloadsViewController
                    self.loadSavedFiles() // Adjust this to refresh DownloadsViewController if needed
                }
            }
        })

    }
    
    private func promptForFileName(completion: @escaping (String) -> Void) {
        let alertController = UIAlertController(title: "Save File", message: "Enter a name for the file", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "File name"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let fileName = alertController.textFields?.first?.text, !fileName.isEmpty {
                completion(fileName)
            } else {
                completion("Document_\(Date().timeIntervalSince1970)")
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    func recognizeText(from images: [UIImage], completion: @escaping (String) -> Void) {
        var recognizedText = ""

        let dispatchGroup = DispatchGroup()
        
        for image in images {
            guard let cgImage = image.cgImage else { continue }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { (request, error) in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                
                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        recognizedText += topCandidate.string + "\n"
                    }
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([request])
                } catch {
                    print("Error in performing text recognition: \(error)")
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(recognizedText)
        }
    }
    
    func saveTextToFile(_ text: String, preferredFileName: String, isMasked: Bool) -> URL? {
        let fileName = isMasked ? "\(preferredFileName)_masked" : preferredFileName
        let fileExtension = "txt"

        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            var fileURL = documentDirectory.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
            var fileNumber = 1
            while FileManager.default.fileExists(atPath: fileURL.path) {
                let newFileName = isMasked ? "\(preferredFileName)_masked (\(fileNumber))" : "\(preferredFileName) (\(fileNumber))"
                fileURL = documentDirectory.appendingPathComponent(newFileName).appendingPathExtension(fileExtension)
                fileNumber += 1
            }

            do {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                return fileURL
            } catch {
                print("Error saving text to file: \(error)")
                return nil
            }
        }
        return nil
    }


    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return savedFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileCell") ?? UITableViewCell(style: .default, reuseIdentifier: "fileCell")
        let fileURL = savedFiles[indexPath.row]
        cell.textLabel?.text = fileURL.lastPathComponent
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let alert = UIAlertController(title: "Delete File", message: "Are you sure you want to delete this file?", preferredStyle: .alert)

            let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
                let fileToDelete = self.savedFiles[indexPath.row]
                do {
                    try FileManager.default.removeItem(at: fileToDelete)
                    self.savedFiles.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                } catch {
                    print("Failed to delete file: \(error)")
                }
            }
            
            // Cancel action
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            // Add actions to the alert
            alert.addAction(deleteAction)
            alert.addAction(cancelAction)
            
            // Present the alert
            if let viewController = tableView.window?.rootViewController {
                viewController.present(alert, animated: true, completion: nil)
            }
        }
    }

    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFileURL = savedFiles[indexPath.row]
        displayFileContent(at: selectedFileURL)
    }

    func displayFileContent(at fileURL: URL) {
        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            var predictionText: String = ""
            var maskedContent: String = ""
            
            if fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                predictionText = "PII: Not Detected"
                maskedContent = "No readable text detected in the file."
            } else {
                if let prediction = testModel(with: fileContent) {
                    if prediction.label == "1" {
                        predictionText = "PII: Detected"
                        maskedContent = maskPII(in: fileContent)
                    } else if prediction.label == "0" {
                        predictionText = "PII: Not Detected"
                        maskedContent = fileContent
                    }
                } else {
                    predictionText = "Prediction failed."
                    maskedContent = fileContent
                }
            }
            
            let alertMessage = """
            File Content: \(maskedContent)
            
            \(predictionText)
            """
            
            let alert = UIAlertController(title: "File Content and Prediction", message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
        } catch {
            print("Error reading file: \(error)")
        }
    }

    
    func maskPII(in text: String) -> String {
        var maskedText = text

        let aadhaarRegex = "\\b\\d{12}\\b"
        maskedText = maskedText.replacingOccurrences(of: aadhaarRegex, with: "****", options: .regularExpression)
        
        let nameRegex = "\\b([A-Z][a-z]*\\s[A-Z][a-z]*)\\b"
        maskedText = maskedText.replacingOccurrences(of: nameRegex, with: "****", options: .regularExpression)
        
        let addressRegex = "(\\d{1,4}\\s+\\w+\\s+\\w+)"
        maskedText = maskedText.replacingOccurrences(of: addressRegex, with: "****", options: .regularExpression)
        
        return maskedText
    }

}
