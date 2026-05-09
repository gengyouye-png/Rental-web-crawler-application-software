import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '租屋查詢系統',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RentHomePage(),
    );
  }
}

class RentHomePage extends StatefulWidget {
  @override
  _RentHomePageState createState() => _RentHomePageState();
}

class _RentHomePageState extends State<RentHomePage> {

  List<Map<String, dynamic>> rentList = [
    {
      "title": "逢甲大學套房",
      "price": "6500",
      "location": "西屯區",
      "image":
          "https://picsum.photos/300/200"
    },
    {
      "title": "近夜市雅房",
      "price": "5000",
      "location": "逢甲路",
      "image":
          "https://picsum.photos/301/200"
    },
    {
      "title": "電梯大樓獨立套房",
      "price": "8500",
      "location": "河南路",
      "image":
          "https://picsum.photos/302/200"
    },
  ];

  void refreshData() {
    setState(() {
      rentList.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("租屋整合系統"),
        centerTitle: true,
      ),

      body: ListView.builder(
        itemCount: rentList.length,
        itemBuilder: (context, index) {

          final rent = rentList[index];

          return Card(
            margin: EdgeInsets.all(10),
            elevation: 5,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Image.network(
                  rent["image"],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),

                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        rent["title"],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 10),

                      Text(
                        "地點：${rent["location"]}",
                        style: TextStyle(fontSize: 16),
                      ),

                      SizedBox(height: 5),

                      Text(
                        "租金：\$${rent["price"]} / 月",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: refreshData,
        child: Icon(Icons.refresh),
      ),
    );
  }
}