import 'package:flutter/material.dart';
import 'package:scrollview_observer/scrollview_observer.dart';


class HomeTest extends StatefulWidget {
  const HomeTest({Key? key}) : super(key: key);

  @override
  State<HomeTest> createState() => _HomeTestState();
}

/// Scroll to index 3 in middle of screen, click button to see errors
/// if in screen have 3 items with index 2, 3, 4, you will see item at index 3 scroll down although I lock scroll to relative index (in case is 2)

class _HomeTestState extends State<HomeTest> {
  List<String> list = List.generate(20, (index) => index.toString());

  late ScrollController controller;
  late ListObserverController observerController;
  late ChatScrollObserver chatScrollObserver;

  double heightForMid = 200;
  double heightNormal = 300;
  int lastRelativeIndex = 1;

  @override
  void initState() {
    super.initState();

    controller = ScrollController();
    observerController = ListObserverController(controller: controller)..cacheJumpIndexOffset = false;
    chatScrollObserver = ChatScrollObserver(observerController);
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Test Lock Scroll"),
      ),
      body: ListViewObserver(
        controller: observerController,
        onObserve: (result) {
          lastRelativeIndex = result.displayingChildIndexList.length - 1;
        },
        child: ListView.builder(
          itemCount: list.length,
          physics: ChatObserverClampingScrollPhysics(observer: chatScrollObserver),
          controller: controller,
          itemBuilder: (context, index) {
            return Container(
              height: index == 3 ? heightForMid : heightNormal,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue)
              ),
              child: Center(
                child: Text(list[index]),
              )
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print('lastRelativeIndex:$lastRelativeIndex');
          chatScrollObserver.fixedPositionOffset = -1;
          chatScrollObserver.standby(
            mode: ChatScrollObserverHandleMode.specified,
            refItemRelativeIndex: lastRelativeIndex,
            refItemRelativeIndexAfterUpdate: lastRelativeIndex,
          );
          setState(() {
            heightForMid += 50;
          });
        },
        child: Icon(Icons.add)
      ),
    );
  }
}