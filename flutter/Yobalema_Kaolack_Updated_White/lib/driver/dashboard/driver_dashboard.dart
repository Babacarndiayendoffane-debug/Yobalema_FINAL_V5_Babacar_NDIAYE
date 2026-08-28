import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../api.dart';

class DriverDashboard extends StatefulWidget { final YobalemaApi api; final Map<String,dynamic> user; const DriverDashboard({super.key,required this.api,required this.user}); @override State<DriverDashboard> createState()=>_DriverDashboardState(); }
class _DriverDashboardState extends State<DriverDashboard>{ bool online=false; Map<String,dynamic>? offer; String earnings='--'; Timer? gpsTimer;
@override void initState(){super.initState(); widget.api.connectSocket(userId:widget.user['id']?.toString(),role:'DRIVER',onRideOffer:(d){if(mounted)setState(()=>offer=d);},onRideNew:(d){if(mounted)setState(()=>offer=d);}); _wallet();}
Future<void> _wallet() async {try{final d=await widget.api.driverWallet();if(mounted)setState(()=>earnings=d.toString());}catch(_){}}
Future<void> _locationTick() async {try{final p=await Geolocator.getCurrentPosition();await widget.api.updateDriverLocation(p.latitude,p.longitude);}catch(_){}}
Future<void> toggle(bool value) async {try{await widget.api.setDriverStatus(value?'ONLINE':'OFFLINE'); if(value){await _locationTick();gpsTimer?.cancel();gpsTimer=Timer.periodic(const Duration(seconds:8),(_)=>_locationTick());}else{gpsTimer?.cancel();gpsTimer=null;} if(mounted)setState(()=>online=value);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
Future<void> accept() async {final id=(offer?['rideId']??offer?['id'])?.toString();if(id==null)return;try{await widget.api.acceptRide(id);widget.api.joinRide(id);await widget.api.rideStatus(id,'ACCEPTED');if(mounted)setState(()=>offer=null);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
@override void dispose(){gpsTimer?.cancel();super.dispose();}
@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Yobalema Driver')),body:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[SwitchListTile(value:online,onChanged:toggle,title:Text(online?'Vous êtes en ligne':'Vous êtes hors ligne'),subtitle:const Text('Recevez uniquement des courses moto Yobalema.')),Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('Mes gains : $earnings'))),const SizedBox(height:16),if(offer!=null)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Nouvelle course',style:TextStyle(fontWeight:FontWeight.bold)),Text(offer.toString()),const SizedBox(height:8),FilledButton(onPressed:accept,child:const Text('Accepter la course'))]))else const Expanded(child:Center(child:Text('En attente de demandes de courses'))),const Text('90 % chauffeur • 10 % plateforme',textAlign:TextAlign.center)])));
}
