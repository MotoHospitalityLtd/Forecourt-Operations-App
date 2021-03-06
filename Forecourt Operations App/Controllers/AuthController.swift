//
//  AuthController.swift
//  Forecourt Documents
//
//  Created by Edwards, Mike on 16/07/2021.
//

import Foundation
import CoreData

class AuthController {
    
    //# MARK: - Data
    let coreData: CoreData
    
    //# MARK: - Controllers:
    let networkController: NetworkController
    
    //# MARK: - Initialisers
    init(coreData: CoreData, networkController: NetworkController) {
        self.coreData = coreData
        self.networkController = networkController
    }
    
    internal func authenticateUser(userCredential: UserCredential, completion: @escaping (LoginResponse) -> Void) {
        authenticateRemotely(userCredential: userCredential) { response in
            switch response {
            
            case .newLogin:
                completion(.newLogin)
                print("Successful remote authentication - New User")

            case .error(let httpError):
                print("Error remote authentication")
                completion(LoginResponse.error(httpError))
            }
        }
    }
    
    func createUser(userCredential: UserCredential) -> UserMO {
        let newUser = UserMO(context: coreData.persistentContainer.viewContext)
        
        newUser.employeeNumber = userCredential.encryptedEmployeeNumber
        newUser.dateOfBirth = userCredential.encryptedDateOfBirth

        coreData.save(context: coreData.persistentContainer.viewContext)
        
        return newUser
    }
    
    private func authenticateRemotely(userCredential: UserCredential, completion: @escaping (LoginResponse) -> Void) {
        
        // Encode the user credential
        let data = try? JSONEncoder().encode(userCredential)
        
        print("USER CREDENTIAL")
        print(userCredential)
        
        self.networkController.post(urlPath: "/api/auth", data: data) { response in
            DispatchQueue.main.async {
                switch response {
                case .success(let data):
                    print("Success")
                    
                    do {
                        let decodedData = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [String: AnyObject]
                        let authToken = decodedData["token"] as! String
                    
                        print("Logged in via network, new user")
                        self.removeUsers()
                        
                        let newUser = self.createUser(userCredential: userCredential)
                        newUser.authToken = authToken
                        
                        self.coreData.save(context: self.coreData.persistentContainer.viewContext)
                        
                        self.networkController.authenticatedUser = newUser
                        
                        completion(.newLogin)
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
    
    internal func removeUsers() {
        let users = fetchUsers()
        
        for user in users {
            coreData.persistentContainer.viewContext.delete(user)
        }
        
        networkController.authenticatedUser = nil
        
        coreData.save(context: coreData.persistentContainer.viewContext)
    }
    
    private func fetchUser(withUserCredential credential: UserCredential) -> UserMO? {
        // Fetch a user that matches the given encrypted employee number and encrypted date of birth.
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "UserMO")
        
        let predicateEmployeeNumber = NSPredicate(format: "employeeNumber = %@", credential.encryptedEmployeeNumber)
        let predicateDateOfBirth = NSPredicate(format: "dateOfBirth = %@", credential.encryptedDateOfBirth)
        let predicate = NSCompoundPredicate.init(type: .and, subpredicates: [predicateEmployeeNumber, predicateDateOfBirth])
        
        request.predicate = predicate
        
        do {
            return try coreData.persistentContainer.viewContext.fetch(request).first as? UserMO
        }
            
        catch {
            fatalError("Error fetching user")
        }
    }

    private func fetchUsers() -> [UserMO] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "UserMO")
        
        do {
            return try coreData.persistentContainer.viewContext.fetch(request) as! [UserMO]
        }
            
        catch {
            fatalError("Error fetching users")
        }
    }
    
    enum LoginResponse {
        case newLogin
        case error(NetworkController.HttpError)
    }
    
}
