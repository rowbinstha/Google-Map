import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hs_sp_app/model/address.dart';
// import 'package:hs_sp_app/widgets/simple-app-bar.dart';
// import 'package:http/http.dart' as http;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart'
    as polylineAlgorithm;
// import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  final Address? destinationAddress;
  MapScreen({this.destinationAddress});
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Set<Marker> _markers = {};
  late Polyline _polyline;
  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
  BitmapDescriptor _destinationMarkerIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);

  @override
  void initState() {
    super.initState();
    _polyline = Polyline(
      polylineId: PolylineId('route'),
      color: Colors.blue,
      width: 4,
      points: [],
    );
    _destinationController.text = widget.destinationAddress?.fullAddress ?? '';
    _addDestinationMarker();
  }

  void _addDestinationMarker() {
    if (widget.destinationAddress != null &&
        widget.destinationAddress!.lat != null &&
        widget.destinationAddress!.lng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: LatLng(
            widget.destinationAddress!.lat!,
            widget.destinationAddress!.lng!,
          ),
          icon: _destinationMarkerIcon,
          infoWindow: InfoWindow(title: 'Destination Address'),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks.first;
          String address =
              "${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea}";
          _originController.text = "$address";
          _markers.removeWhere(
              (marker) => marker.markerId.value == 'current_position');
          _markers.add(
            Marker(
              markerId: MarkerId('current_position'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: InfoWindow(title: 'Current Position'),
            ),
          );
          setState(() {});
        }
      } catch (e) {
        print(e);
        // Handle any errors that occur during location retrieval or geocoding
      }
    } else if (status.isDenied) {
      // Handle denied permissions
      print('Location permission denied');
    }
  }

  Future<void> _getDirections() async {
    final String origin = _originController.text;
    final String destination = _destinationController.text;
    if (origin.isEmpty || destination.isEmpty) {
      // Show input error dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Input Error'),
            content: Text('Please enter both origin and destination.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    if (widget.destinationAddress == null ||
        widget.destinationAddress!.lat == null ||
        widget.destinationAddress!.lng == null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Destination Coordinates Missing'),
            content: Text('Destination coordinates are not available.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    final String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final String apiUrl =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey";

    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data["routes"];

      if (routes.isEmpty) {
        // Show no route found dialog
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('No Route Found'),
              content: Text('No route found between the specified locations.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      List<LatLng> polylineCoordinates = [];
      final legs = routes[0]["legs"][0];
      final steps = legs["steps"];
      for (var step in steps) {
        final polylinePoints = step["polyline"]["points"];
        final decodedPolyline =
            polylineAlgorithm.decodePolyline(polylinePoints);

        for (var point in decodedPolyline) {
          double lat = point[0].toDouble();
          double lng = point[1].toDouble();
          polylineCoordinates.add(LatLng(lat, lng));
        }
      }

      setState(() {
        _polyline = Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blue,
          width: 4,
          points: polylineCoordinates,
        );

        _markers.add(
          Marker(
            markerId: MarkerId('start'),
            position: LatLng(
                legs["start_location"]["lat"], legs["start_location"]["lng"]),
          ),
        );
        _markers.add(
          Marker(
            markerId: MarkerId('end'),
            position: LatLng(
                legs["end_location"]["lat"], legs["end_location"]["lng"]),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(
        title: 'Google Maps',
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _originController,
                    decoration: InputDecoration(
                      labelText: 'Enter Origin',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 7.0, vertical: 5.0),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 5,
                ),
                ElevatedButton(
                  onPressed: _getCurrentLocation,
                  child: Text(
                    'Get Current Location',
                    textAlign: TextAlign.center,
                  ),
                  style: ElevatedButton.styleFrom(
                    textStyle: TextStyle(
                      fontSize: 13,
                    ),
                    backgroundColor: Colors.teal,
                    fixedSize: Size(90, 46),
                    padding: EdgeInsets.all(4.0),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      labelText: 'Enter Destination',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 7.0, vertical: 5.0),
                    ),
                  ),
                ),
                SizedBox(
                  width: 5,
                ),
                ElevatedButton(
                  onPressed: _getDirections,
                  child: Text(
                    'Get \nDirections',
                    textAlign: TextAlign.center,
                  ),
                  style: ElevatedButton.styleFrom(
                    textStyle: TextStyle(
                      fontSize: 13,
                    ),
                    backgroundColor: Colors.teal,
                    fixedSize: Size(90, 46),
                    padding: EdgeInsets.all(4.0),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(27.6833306, 84.416665),
                zoom: 12.0,
              ),
              markers: _markers,
              polylines: {_polyline},
              onMapCreated: (controller) {},
            ),
          ),
        ],
      ),
    );
  }
}
