//
//  DirectoryController.swift
//  Forecourt Documents
//
//  Created by Edwards, Mike on 09/08/2021.
//

import Foundation
import CoreData

class DirectoryController {
    
    //# MARK: - Data
    let coreData: CoreData
    
    //# MARK: - Variables
    var directoryPath: [Int] = []
    
    var rootDirectory: DirectoryMO?
    var currentDirectory: DirectoryMO?
    
    //# MARK: - Controllers:
    let networkController: NetworkController
    
    //# MARK: - Initialisers
    init(coreData: CoreData, networkController: NetworkController) {
        self.coreData = coreData
        self.networkController = networkController
        
        rootDirectory = loadRootDirectory()
        currentDirectory = rootDirectory
    }
    
    internal func downloadDirectories(completion: @escaping (NetworkController.NetworkResponse) -> Void) {

        self.networkController.get(urlPath: "/api/root-directory") { response in
            DispatchQueue.main.async {
                switch response {
                case .success(let data):
                    print("Success")
                    
                    do {
                        let decodedData = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [String: AnyObject]
                        
                        let directoryData = decodedData["data"] as! [[String: AnyObject]]
                        
                        self.rootDirectory = DirectoryMO.createRootDirectory(fromJSon: directoryData, withContext: self.coreData.persistentContainer.viewContext)
                        self.currentDirectory = self.rootDirectory
   
                        self.coreData.save(context: self.coreData.persistentContainer.viewContext)

                        completion(.success(nil))
                    }
                        
                    catch {
                        print("catch error: \(error)")
                    }
                    
                case .error(let httpError):
                   completion(.error(httpError))
                }
            }
        }
    }
    
    internal func removeAllDirectories() {
        for directory in fetchAllDirectories() {
            print("Removed directory")
            coreData.persistentContainer.viewContext.delete(directory)
        }
        
        directoryPath = []
    }
    
    private func fetchAllDirectories() -> [DirectoryMO] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "DirectoryMO")

        do {
            return try coreData.persistentContainer.viewContext.fetch(request) as? [DirectoryMO] ?? []
        }

        catch {
            fatalError("Error fetching all directories")
        }
    }
    
    
    
    private func loadRootDirectory() -> DirectoryMO? {
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "DirectoryMO")

        // The id for the root directory is 0
        let predicateId = NSPredicate(format: "id = %d", 0)

        request.predicate = predicateId

        do {
            return try coreData.persistentContainer.viewContext.fetch(request).first as? DirectoryMO
        }

        catch {
            fatalError("Error fetching user")
        }
    }
    
    
    internal func setCurrentDirectory() {
        
        // Array of tapped indexes from visible items (can only be directory)
        // [0, 0, 1]
        print("DirectoryPath Before: \(directoryPath)")
        
        directoryPath.removeLast(1)
        
        print("DirectoryPath After: \(directoryPath)")
        
        var position = rootDirectory!
        
        for index in directoryPath {
            
            position = getSubDirectory(ofDirectory: position, withIndex: index)
            
        }
        
        currentDirectory = position
    }
    
    internal func getSubDirectory(ofDirectory directory: DirectoryMO, withIndex index: Int) -> DirectoryMO {
        return directory.visibleItems[index] as! DirectoryMO
    }
}