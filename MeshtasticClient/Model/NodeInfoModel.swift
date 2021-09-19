//
//  NodeInfo.swift
//  MeshtasticClient
//
//  Created by Garth Vander Houwen on 9/13/21.
//

import Foundation
import SwiftUI
import CoreLocation

struct NodeInfoModel: Hashable, Codable, Identifiable {
    
    let id = UUID()
    var num: UInt32
    
    var user: User
    struct User: Hashable, Codable, Identifiable {
        var id: String
        var longName: String
        var shortName: String
        var macaddr: String
        var hwModel: String
    }
    
    var position: Position
    struct Position: Hashable, Codable {
        var latitudeI: Int32?
        var latitude: Double? {
            if let unwrappedLat = latitudeI {
                let d = Double(unwrappedLat)
                
                return d / 10000000
            }
            else {
               return nil
            }
        }
        var longitudeI: Int32?
        var longitude: Double? {
            if let unwrappedLong = longitudeI {
                let d = Double(unwrappedLong)
                
                return d / 10000000
            }
            else {
               return nil
            }
        }
        var coordinate: CLLocationCoordinate2D? {
            if longitude != nil {
                let coord = CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
                
                return coord
            }
            else {
               return nil
            }
        }
        var altitude: Int32?
        var batteryLevel: Int32?
        var time: Int32?
    }
    
    var lastHeard: Double
    var snr: Double?
}