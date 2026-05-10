import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '租屋整合系統',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RentHomePage(),
    );
  }
}

class RentHomePage extends StatefulWidget {
  const RentHomePage({super.key});

  @override
  State<RentHomePage> createState() => _RentHomePageState();
}

class _RentHomePageState extends State<RentHomePage> {
  List<Map<String, dynamic>> rentList = [
    {"title": "逢甲大學套房", "price": "6500", "location": "西屯區"},
    {"title": "近夜市雅房", "price": "5000", "location": "逢甲路"},
    {"title": "電梯大樓獨立套房", "price": "8500", "location": "河南路"},
  ];

  void refreshData() {
    setState(() {
      rentList.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("租屋整合系統"), centerTitle: true),

      body: ListView.builder(
        itemCount: rentList.length,

        itemBuilder: (context, index) {
          final rent = rentList[index];

          return Card(
            margin: const EdgeInsets.all(10),
            elevation: 5,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // 假圖片區塊
                Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[300],

                  child: const Center(
                    child: Icon(Icons.home, size: 80, color: Colors.grey),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(10),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        rent["title"],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "地點：${rent["location"]}",
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "租金：\$${rent["price"]} / 月",
                        style: const TextStyle(fontSize: 18, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: refreshData,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
