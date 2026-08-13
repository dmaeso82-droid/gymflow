
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/section_title.dart';

class ClientGoalsUserPanel extends StatelessWidget {
  final String gymId;
  final String userEmail;

  const ClientGoalsUserPanel({super.key, required this.gymId, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('goals').where('clientEmail', isEqualTo: userEmail.toLowerCase()).snapshots(),
      builder:(context,snapshot){
        final goals=snapshot.data?.docs??[];
        final completed=goals.where((g)=>g.data()['completed']==true).length;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
            SectionTitle(icon: Icons.flag,title:'Mis objetivos'),
            SizedBox(height:12),
            Wrap(spacing:8,runSpacing:8,children:[
              InfoChip(text:'${goals.length} objetivos'),
              InfoChip(text:'$completed completados'),
            ]),
            SizedBox(height:12),
            if(goals.isEmpty)
              Text('Tu entrenador todavía no ha definido objetivos.',style: TextStyle(color: Colors.white70))
            else
              ...goals.map((g){
                final d=g.data();
                final done=d['completed']==true;
                return ListTile(
                  leading: Icon(done?Icons.check_circle:Icons.radio_button_unchecked,color: done?Colors.greenAccent:Colors.white54),
                  title: Text(d['title']?.toString()??'Objetivo',style: TextStyle(decoration: done?TextDecoration.lineThrough:null)),
                  subtitle: Wrap(spacing:6,children:[
                    if((d['targetValue']??'').toString().isNotEmpty) InfoChip(text:'Meta: ${d['targetValue']}'),
                    InfoChip(text: done?'Completado':'Pendiente'),
                  ]),
                );
              })
          ]),
        );
      }
    );
  }
}



