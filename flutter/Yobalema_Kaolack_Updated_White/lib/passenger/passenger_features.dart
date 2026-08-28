import 'package:flutter/material.dart';
import '../api.dart';

class PassengerFeatureApp extends StatefulWidget {
  const PassengerFeatureApp({super.key});
  @override
  State<PassengerFeatureApp> createState() => _PassengerFeatureAppState();
}

class _PassengerFeatureAppState extends State<PassengerFeatureApp> {
  final api = YobalemaApi();
  @override
  void dispose() { api.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Yobalema Passenger',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFFFCC00)),
    home: PassengerAuthScreen(api: api),
  );
}

class PassengerAuthScreen extends StatefulWidget {
  final YobalemaApi api;
  const PassengerAuthScreen({super.key, required this.api});
  @override
  State<PassengerAuthScreen> createState() => _PassengerAuthScreenState();
}

class _PassengerAuthScreenState extends State<PassengerAuthScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool loading = false;
  Future<void> submit() async {
    setState(() => loading = true);
    try {
      Map<String,dynamic> data;
      try { data = await widget.api.login(phone.text.trim(), password.text); }
      catch (_) { data = await widget.api.register(phone: phone.text.trim(), password: password.text, name: name.text.trim().isEmpty ? 'Passager Yobalema' : name.text.trim(), role: 'PASSENGER'); }
      final user = Map<String,dynamic>.from(data['user'] ?? {});
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PassengerRideScreen(api: widget.api, user: user)));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override void dispose(){ phone.dispose(); password.dispose(); name.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children:[
    const Icon(Icons.person_pin_circle, size:72), const SizedBox(height:12), const Text('Yobalema Passenger', style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
    const Text('Commander une moto dans la région de Kaolack.'), const SizedBox(height:20),
    TextField(controller:name, decoration:const InputDecoration(labelText:'Nom',border:OutlineInputBorder())), const SizedBox(height:10),
    TextField(controller:phone, decoration:const InputDecoration(labelText:'Téléphone',border:OutlineInputBorder())), const SizedBox(height:10),
    TextField(controller:password, obscureText:true, decoration:const InputDecoration(labelText:'Mot de passe',border:OutlineInputBorder())), const SizedBox(height:16),
    FilledButton(onPressed:loading?null:submit, child:Text(loading?'Connexion...':'Continuer')),
  ]))));
}

class PassengerRideScreen extends StatefulWidget {
  final YobalemaApi api; final Map<String,dynamic> user;
  const PassengerRideScreen({super.key, required this.api, required this.user});
  @override State<PassengerRideScreen> createState()=>_PassengerRideScreenState();
}
class _PassengerRideScreenState extends State<PassengerRideScreen> {
  final from = TextEditingController(); final to = TextEditingController(); String payment='CASH'; String status='Prêt';
  @override void initState(){ super.initState(); widget.api.connectSocket(userId: widget.user['id']?.toString(), role:'PASSENGER', onRideAccepted:(d)=>setState(()=>status='Chauffeur trouvé'), onRideStatus:(d)=>setState(()=>status=d['status']?.toString() ?? status), onRideLocation:(d)=>setState(()=>status='Chauffeur en approche')); }
  Future<void> requestRide() async {
    try {
      final ride=await widget.api.createRide(fromName:from.text,toName:to.text,fromLat:14.1510,fromLng:-16.0726,toLat:14.1560,toLng:-16.0400,fromZone:'CITY',toZone:'PERIURBAN',trafficLevel:0,night:false,shareTrip:false,paymentMethod:payment);
      final id=ride['id']?.toString(); if(id!=null) widget.api.joinRide(id);
      setState(()=>status='Course demandée');
      if(payment!='CASH' && id!=null) await widget.api.startPayment(id);
    } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); }
  }
  @override void dispose(){from.dispose();to.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Yobalema Passenger')),body:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text('Statut : $status'), const SizedBox(height:16), TextField(controller:from,decoration:const InputDecoration(labelText:'Départ',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:to,decoration:const InputDecoration(labelText:'Destination',border:OutlineInputBorder())),const SizedBox(height:12),DropdownButtonFormField(value:payment,items:const [DropdownMenuItem(value:'CASH',child:Text('Espèces')),DropdownMenuItem(value:'WAVE',child:Text('Wave')),DropdownMenuItem(value:'ORANGE_MONEY',child:Text('Orange Money'))],onChanged:(v)=>setState(()=>payment=v!),decoration:const InputDecoration(labelText:'Paiement',border:OutlineInputBorder())),const Spacer(),FilledButton.icon(onPressed:requestRide,icon:const Icon(Icons.two_wheeler),label:const Text('Commander une moto')),
  ])));
}
