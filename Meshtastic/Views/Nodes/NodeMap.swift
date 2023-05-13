//
//  NodeMap.swift
//  MeshtasticApple
//
//  Created by Garth Vander Houwen on 8/7/21.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData

struct NodeMap: View {

	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager
	
	@ObservedObject var tileManager = OfflineTileManager.shared

	@State var selectedMapLayer: MapLayer = UserDefaults.mapLayer
	@State var enableMapRecentering: Bool = UserDefaults.enableMapRecentering
	@State var enableMapRouteLines: Bool = UserDefaults.enableMapRouteLines
	@State var enableMapNodeHistoryPins: Bool = UserDefaults.enableMapNodeHistoryPins
	@State var enableOfflineMaps: Bool = UserDefaults.enableOfflineMaps
	@State var selectedTileServer: MapTileServerLinks = UserDefaults.mapTileServer
	@State var enableOfflineMapsMBTiles: Bool = UserDefaults.enableOfflineMapsMBTiles
	@State var mapTilesAboveLabels: Bool = UserDefaults.mapTilesAboveLabels

	@FetchRequest(sortDescriptors: [NSSortDescriptor(key: "time", ascending: true)],
				  predicate: NSPredicate(format: "time >= %@ && nodePosition != nil", Calendar.current.startOfDay(for: Date()) as NSDate), animation: .none)
	private var positions: FetchedResults<PositionEntity>

	@FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: false)],
				  predicate: NSPredicate(
					format: "expire == nil || expire >= %@", Date() as NSDate
				  ), animation: .none)
	private var waypoints: FetchedResults<WaypointEntity>
	@State var waypointCoordinate: WaypointCoordinate?

	@State var selectedTracking: UserTrackingModes = .none
	
	@State var isPresentingInfoSheet: Bool = false
	
	@State private var customMapOverlay: MapViewSwiftUI.CustomMapOverlay? = MapViewSwiftUI.CustomMapOverlay(
			mapName: "offlinemap",
			tileType: "png",
			canReplaceMapContent: true
		)

	var body: some View {

		NavigationStack {
			ZStack {

				MapViewSwiftUI(
						onLongPress: { coord in
						waypointCoordinate = WaypointCoordinate(id: .init(), coordinate: coord, waypointId: 0)
					}, onWaypointEdit: { wpId in
						if wpId > 0 {
							waypointCoordinate = WaypointCoordinate(id: .init(), coordinate: nil, waypointId: Int64(wpId))
						}
					},
				   selectedMapLayer: selectedMapLayer,
				   positions: Array(positions),
				   waypoints: Array(waypoints),
				   userTrackingMode: selectedTracking.MKUserTrackingModeValue(),
				   showNodeHistory: enableMapNodeHistoryPins,
				   showRouteLines: enableMapRouteLines,
				   customMapOverlay: self.customMapOverlay
				)
				VStack(alignment: .trailing) {
					
					HStack(alignment: .top) {
						Spacer()
						MapButtons(tracking: $selectedTracking, isPresentingInfoSheet: $isPresentingInfoSheet)
							.padding(.trailing, 8)
							.padding(.top, 16)
					}
					
					Spacer()
					
				}
			}
			.ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
			.frame(maxHeight: .infinity)
			.sheet(item: $waypointCoordinate, content: { wpc in
							WaypointFormView(coordinate: wpc)
								.presentationDetents([.medium, .large])
								.presentationDragIndicator(.automatic)
			})
			.sheet(isPresented: $isPresentingInfoSheet) {
				VStack {
					Form {
						Section(header: Text("Map Options")) {
							Picker(selection: $selectedMapLayer, label: Text("")) {
								ForEach(MapLayer.allCases, id: \.self) { layer in
									if layer == MapLayer.offline && UserDefaults.enableOfflineMaps {
										Text(layer.localized)
									} else if layer != MapLayer.offline {
										Text(layer.localized)
									}
								}
							}
							.pickerStyle(SegmentedPickerStyle())
							.onChange(of: (selectedMapLayer)) { newMapLayer in
								UserDefaults.mapLayer = newMapLayer
							}
							.padding(.top, 5)
							.padding(.bottom, 5)
							
							Toggle(isOn: $enableMapRecentering) {
								
								Label("map.recentering", systemImage: "camera.metering.center.weighted")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onTapGesture {
								self.enableMapRecentering.toggle()
								UserDefaults.enableMapRecentering = self.enableMapRecentering
							}
							
							Toggle(isOn: $enableMapNodeHistoryPins) {
								
								Label("Show Node History", systemImage: "building.columns.fill")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onTapGesture {
								self.enableMapNodeHistoryPins.toggle()
								UserDefaults.enableMapNodeHistoryPins = self.enableMapNodeHistoryPins
							}
							
							Toggle(isOn: $enableMapRouteLines) {
								
								Label("Show Route Lines", systemImage: "road.lanes")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onTapGesture {
								self.enableMapRouteLines.toggle()
								UserDefaults.enableMapRouteLines = self.enableMapRouteLines
							}
						}
						Section(header: Text("Offline Maps")) {
							Toggle(isOn: $enableOfflineMaps) {
								Text("Enable Offline Maps")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onChange(of: (enableOfflineMaps)) { newEnableOfflineMaps in
								UserDefaults.enableOfflineMaps = newEnableOfflineMaps
								if !newEnableOfflineMaps {
									if self.selectedMapLayer == .offline {
										self.selectedMapLayer = .standard
									}
								}
							}
							if UserDefaults.enableOfflineMaps {
								VStack (alignment: .leading) {
									
									if !enableOfflineMapsMBTiles {
										
										Picker(selection: $selectedTileServer,
											   label: Text("Tile Server")) {
											ForEach(MapTileServerLinks.allCases, id: \.self) { tsl in
												Text(tsl.description)
											}
										}
										.pickerStyle(DefaultPickerStyle())
										.onChange(of: (selectedTileServer)) { newSelectedTileServer in
											UserDefaults.mapTileServer = newSelectedTileServer
										}
										Text("Attribution:")
											.fontWeight(.semibold)
											.font(.footnote)
										Text(LocalizedStringKey(selectedTileServer.attribution))
											.font(.footnote)
											.foregroundColor(.gray)
											.padding(0)
										Divider()
										Toggle(isOn: $mapTilesAboveLabels) {
											Text("Tiles above Labels")
										}
										.toggleStyle(SwitchToggleStyle(tint: .accentColor))
										.onTapGesture {
											self.mapTilesAboveLabels.toggle()
											UserDefaults.mapTilesAboveLabels = self.mapTilesAboveLabels
										}
										
									}
									Divider()
									Toggle(isOn: $enableOfflineMapsMBTiles) {
										Text("Enable MB Tiles")
									}
									.toggleStyle(SwitchToggleStyle(tint: .accentColor))
									.onTapGesture {
										self.enableOfflineMapsMBTiles.toggle()
										UserDefaults.enableOfflineMapsMBTiles = self.enableOfflineMapsMBTiles
									}
									Text("The latest MBTiles file shared with meshtastic will be loaded into the map.")
										.font(.footnote)
										.foregroundColor(.gray)
								}
							}
						}
					}
					#if targetEnvironment(macCatalyst)
					Button {
						isPresentingInfoSheet = false
					} label: {
						Label("close", systemImage: "xmark")
					}
					.buttonStyle(.bordered)
					.buttonBorderShape(.capsule)
					.controlSize(.large)
					.padding(.bottom)
					#endif
				}
				.presentationDetents([UserDefaults.enableOfflineMaps ? .large : .medium])
				.presentationDragIndicator(.visible)
			}
		}
		.navigationBarItems(leading:
								MeshtasticLogo(), trailing:
								ZStack {
			ConnectedDevice(
				bluetoothOn: bleManager.isSwitchedOn,
				deviceConnected: bleManager.connectedPeripheral != nil,
				name: (bleManager.connectedPeripheral != nil) ? bleManager.connectedPeripheral.shortName :
					"????")
		})
		.onAppear(perform: {
			UIApplication.shared.isIdleTimerDisabled = true
			self.bleManager.context = context
		})
		.onDisappear(perform: {
			UIApplication.shared.isIdleTimerDisabled = false
		})
	}
}
