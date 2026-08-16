import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ThesiPinakaApp());

class ThesiPinakaApp extends StatelessWidget {
  const ThesiPinakaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Θέση Πίνακα 1ΓΕ/2026',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF172033),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: const SearchPage(),
    );
  }
}

class Candidate {
  final int id;
  final String tableName;
  final int rank;
  final String am, surname, firstName, uniqueCode, score;
  Candidate(Map<String,Object?> m)
      : id=(m['id'] as int?) ?? 0,
        tableName='${m['table_name'] ?? ''}',
        rank=(m['rank'] as int?) ?? 0,
        am='${m['am'] ?? ''}',
        surname='${m['surname'] ?? ''}',
        firstName='${m['first_name'] ?? ''}',
        uniqueCode='${m['unique_code'] ?? ''}',
        score='${m['score'] ?? ''}';
}

class Db {
  static Database? _db;
  static Future<Database> open() async {
    if (_db != null) return _db!;
    final dir=await getDatabasesPath();
    final target=join(dir,'ige2026.db');
    if (!await File(target).exists()) {
      final data=await rootBundle.load('assets/db/ige2026.db');
      await File(target).writeAsBytes(data.buffer.asUint8List(),flush:true);
    }
    _db=await openDatabase(target,readOnly:true);
    return _db!;
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState()=>_SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final q=TextEditingController();
  List<String> tables=['Όλοι οι πίνακες'];
  String selected='Όλοι οι πίνακες';
  List<Candidate> results=[];
  bool busy=false;

  @override void initState(){super.initState(); loadTables();}

  Future<void> loadTables() async {
    final db=await Db.open();
    final rows=await db.rawQuery('SELECT table_name,COUNT(*) n FROM candidates GROUP BY table_name ORDER BY table_name');
    if(!mounted)return;
    setState(()=>tables=['Όλοι οι πίνακες',...rows.map((e)=>'${e['table_name']}')]);
  }

  Future<void> search() async {
    final term=q.text.trim();
    if(term.isEmpty)return;
    setState(()=>busy=true);
    final db=await Db.open();
    final like='%$term%';
    final List<Map<String,Object?>> rows;
    if(selected=='Όλοι οι πίνακες'){
      rows=await db.rawQuery(
        'SELECT id,table_name,rank,am,surname,first_name,unique_code,score FROM candidates '
        'WHERE am LIKE ? OR surname LIKE ? OR first_name LIKE ? OR unique_code LIKE ? '
        'ORDER BY table_name,rank LIMIT 30',[like,like,like,like]);
    }else{
      rows=await db.rawQuery(
        'SELECT id,table_name,rank,am,surname,first_name,unique_code,score FROM candidates '
        'WHERE table_name=? AND (am LIKE ? OR surname LIKE ? OR first_name LIKE ? OR unique_code LIKE ?) '
        'ORDER BY rank LIMIT 30',[selected,like,like,like,like]);
    }
    if(!mounted)return;
    setState(()=>results=rows.map(Candidate.new).toList(),busy=false);
  }

  Future<void> myPosition() async {
    final p=await SharedPreferences.getInstance();
    final id=p.getInt('candidate_id');
    if(id==null){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Δεν έχει αποθηκευτεί ακόμη η θέση σου.')));
      return;
    }
    final db=await Db.open();
    final rows=await db.query('candidates',where:'id=?',whereArgs:[id],limit:1);
    if(rows.isNotEmpty && mounted) showCandidate(Candidate(rows.first));
  }

  Future<void> showCandidate(Candidate c) async {
    final p=await SharedPreferences.getInstance();
    await p.setInt('candidate_id',c.id);
    if(!mounted)return;
    Navigator.push(context,MaterialPageRoute(builder:(_)=>CandidatePage(c:c)));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(
        backgroundColor:const Color(0xFF172033),
        foregroundColor:Colors.white,
        title:const Text('Θέση Πίνακα 1ΓΕ/2026'),
      ),
      body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('Προσωρινοί πίνακες ΑΣΕΠ',
          style:TextStyle(fontSize:14,color:Colors.black54)),
        const SizedBox(height:4),
        const Text('Βρες τη θέση σου',
          style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),
        const SizedBox(height:18),
        DropdownButtonFormField<String>(
          value:selected,
          isExpanded:true,
          items:tables.map((x)=>DropdownMenuItem(value:x,child:Text(x,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(x)=>setState(()=>selected=x!),
          decoration:const InputDecoration(labelText:'Πίνακας',border:OutlineInputBorder()),
        ),
        const SizedBox(height:12),
        TextField(
          controller:q,
          onSubmitted:(_)=>search(),
          decoration:const InputDecoration(
            labelText:'Α.Μ., επώνυμο, όνομα ή μοναδικός κωδικός',
            border:OutlineInputBorder(),prefixIcon:Icon(Icons.search)),
        ),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:busy?null:search,icon:const Icon(Icons.search),label:const Text('ΑΝΑΖΗΤΗΣΗ')),
        OutlinedButton.icon(onPressed:myPosition,icon:const Icon(Icons.person_pin_circle),label:const Text('Η ΘΕΣΗ ΜΟΥ')),
        const SizedBox(height:10),
        const Text('43 πίνακες • 38.051 εγγραφές • λειτουργία offline',
          style:TextStyle(fontSize:12,color:Colors.black54)),
        if(busy) const Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator())),
        ...results.map((c)=>Card(
          margin:const EdgeInsets.only(top:10),
          child:ListTile(
            onTap:()=>showCandidate(c),
            title:Text('${c.surname} ${c.firstName}',style:const TextStyle(fontWeight:FontWeight.bold)),
            subtitle:Text('Α.Μ. ${c.am}\n${c.tableName}'),
            trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
              Text('#${c.rank}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
              Text(c.score,style:const TextStyle(fontSize:12)),
            ]),
          ),
        )),
        if(!busy && q.text.trim().isNotEmpty && results.isEmpty)
          const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('Δεν βρέθηκε αποτέλεσμα.'))),
      ])),
    );
  }
}

class CandidatePage extends StatelessWidget {
  final Candidate c;
  const CandidatePage({super.key,required this.c});
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text('Η θέση μου')),
      body:ListView(padding:const EdgeInsets.all(18),children:[
        Text('${c.surname} ${c.firstName}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800)),
        Text(c.tableName,style:const TextStyle(color:Colors.black54)),
        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('ΘΕΣΗ',style:TextStyle(color:Colors.black54)),
            Text('#${c.rank}',style:const TextStyle(fontSize:42,fontWeight:FontWeight.w900)),
            const Divider(),
            Text('Προηγούνται: ${c.rank>0?c.rank-1:0}',style:const TextStyle(fontSize:18)),
            Text('Μόρια: ${c.score}',style:const TextStyle(fontSize:18)),
            Text('Α.Μ.: ${c.am}',style:const TextStyle(fontSize:18)),
            Text('Μοναδικός κωδικός: ${c.uniqueCode}',style:const TextStyle(fontSize:16)),
          ]))),
        const SizedBox(height:12),
        const Text('Η επιλογή αποθηκεύεται μόνο στη συσκευή σου.',
          style:TextStyle(fontSize:12,color:Colors.black54)),
      ]),
    );
  }
}
