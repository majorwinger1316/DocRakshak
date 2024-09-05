//
//  DownloadsViewController.swift
//  DocRakshak
//
//  Created by admin33 on 04/09/24.
//

import UIKit

class DownloadsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var maskedFiles: [URL] = []
    private var unmaskedFiles: [URL] = []
    private var savedTextFiles: [URL] = []
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadFiles()
    }
    
    func loadFiles() {
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
                
                // Load masked and unmasked files
                self.maskedFiles = fileURLs.filter { $0.lastPathComponent.contains("_masked") }.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
                self.unmaskedFiles = fileURLs.filter { !$0.lastPathComponent.contains("_masked") && $0.pathExtension != "txt" }.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
                
                // Load saved text files
                self.savedTextFiles = fileURLs.filter { $0.pathExtension == "txt" }
                
                self.tableView?.reloadData()
            } catch {
                print("Error loading files from directory: \(error)")
            }
        }
    }
    
    // MARK: - Table View Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // 3 sections: one for unmasked, one for masked, and one for saved text files
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return unmaskedFiles.count
        case 1: return maskedFiles.count
        case 2: return savedTextFiles.count
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileCell") ?? UITableViewCell(style: .default, reuseIdentifier: "fileCell")
        
        // Determine the appropriate file for the section
        let fileURL: URL
        switch indexPath.section {
        case 0:
            fileURL = unmaskedFiles[indexPath.row]
        case 1:
            fileURL = maskedFiles[indexPath.row]
        case 2:
            fileURL = savedTextFiles[indexPath.row]
        default:
            fatalError("Unexpected section index")
        }
        
        cell.textLabel?.text = fileURL.lastPathComponent
        return cell
    }
    
    // Optional: Customize section headers
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Unmasked Files"
        case 1: return "Masked Files"
        case 2: return "Saved Text Files"
        default: return nil
        }
    }
    
    @IBAction func contentChanger(_ sender: UISegmentedControl) {
        tableView.reloadData()
    }
}
