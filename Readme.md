# msglogger

		github上有若干用于纪录objc_msgSend消息的仓库，然而均存在一定问题
		1.使用dyld_insertlibrary方式启动，不适用于ios app
		2.使用substrate框架是常理，然而在new_objc_msgSend回调中做了太多事情以致效率很低(这包括Snoop-it)
		3.将new_objc_msgSend回调实现在.m/.mm文件中，导致递归(因为编译器会生成局部变量构造析构代码，里面也调用的objc_msgSend)(这包括InspectiveC)，而实现在c/cpp中则不会有递归问题
		4.未能解析objc_msgSend参数
		对于此问题，提供的解决方案：
		1.使用cydia substrate框架实现msgsend hook以及Cydia提供的MobileLoader自动加载dylib模块（注意ios设备上存在的substrate头文件是最全的）
		2.new_objc_msgSend回调做成异步任务式，检查selector的地址空间是否位于该模块，这样比匹配id和selector快得多
		3.在.c/.cpp中实现new_objc_msgSend回调
		4.从signature解析出参数类型（由于匹配要class+selector，开启该功能则不可避免的耗时）
		
		msglogger使用方式：
		./utilityserver --app_inject "com.?"
		/tmp/msglog.txt查看结果
		
		存在的问题：
		对于大的可执行文件由于msgSend相当频繁，因此不推荐hook msgSend方式，可以考虑使用frida或cycript hook某些selector
		