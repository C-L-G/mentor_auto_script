# mentor_auto_script

auto_generate  script of TCL for modelsim 

自动生成 modelsim 仿真脚本

Auto generate script for moodelsim

代码实现的背景:(需求分析）

Why	do I code it：

	每次用Modelsim仿真，都必须要做许多前期的重复的工作。编译文件，添加库... 不同的工程又需要不同的文件

	当然，网上虽然也有现成的do脚本，但是离我想要的还太远

	我需要一个任何工程 ”都是而且仅是运行相同的东西“

	我需要一个智能地去编译修改的文件，而不是每次都要全部编译，当你有上千个文件的时候，将会大大提高工作效率

	It make	me crazy when I	simulate HDL with modelsim。‘Compile’，‘add lib’，’config‘	again and again.I can hold nothing from	pre_project

	You	can	find some 'tcl script' for modelsim	in Internet. But I do not think	they are good enough.

	I want this	script is compatible for more and more projects	of modelsim

	It will	be better if it	can	only compile few files that	have be	modified , rether that all.	Now	maybe I	can't take a coffee	at 'compiling......' 
	


文件说明：

FILE DESCRIPTION:

	modelsim_auto.rb    Ruby 脚本

	auto_conf  配置脚本

	modelsim_auto.rb    Ruby script

	auto_conf  configure for env


使用说明:

	1、配置auto_conf 文件:
	
	   CONF:配置block
	
	   CODE_PATHS 代码路径 
	   
	   Modelsim_PATH modelsim 工程路径
	   
	   IGNORE  忽略的路径和文件
	   
	   SIM_TOP_MODULES 仿真top文件，支持多个

	   支持 正斜杠和反斜杠，也就是说 win 和 UNIX的 路径方式都是可以的

	   例如：
	   
		CONF: PRJ_0  	# PRJ_0 配置 ，一个文件可以有多个 CONF
		
		CODE_PATHS:{    # 代码路径，大括号内可以有多个路径，每个路径占用一行
		
		#E:\work\newboard\rtl  # 支持 ‘#’ 注释 一个#注释一行 类似 C语言的 //
		
		/home/young/work/ruby/cordic
		
		/home/young/work/ruby/general-cordic-rotaion
		
		/home/young/work/ruby/file-class-package
		
		}
		
		IGNORE:{ # 忽略文件夹和文件
		
		ISP  #忽略带有 ‘ISP’的 文件或文件夹
		
		？KK # 支持？ 的通配符号 匹配一个有效alpha字符
		 
		.JJ # 支持. 通配符号 匹配任意字符
		
		*ww # 支持* 通配符号 匹配任意个任意字符
		
		work/ #忽略 带有work的文件夹
		
		}
		
		Modelsim_PATH:/home/young/work/mentor  # modelsim 工程路径
		
		SIM_TOP_MODULES:{ # 顶层模块，支持多个模块
		
		image_file_package_tb
		
		X_Y_to_angle_tb
		
		}
		
		ENDCONF:PRJ_0  # CONG结束 关键词 CONG ENDCONG是一对。冒号后必须跟 配置名
		
		USE_CONFIGURE: PRJ_0 # 当前使用配置

	   路径下是按文件夹来分模块的。

	   例如:

			E:\RTL\.

				   module_A\

							rtl_file

				   module_B\

							rtl_file

		2、运行MentorSbuid.rb，	会在modelsim工程文件夹下生成 

			compile_all.do

			compile_modified.do

			compile_all.bat

			compile_modified.bat

		3、	在modesim状态下

			 do		compile_all.do		#编译所有文件

			 do		compile_modified.do	#只编译修改的文件


How	It work:

		1、configure	file path_conf,each	line is	a directory

		   / and \ both	work

		Example:

			RTL:{

			E:\RTL

			}

			SIM:{

			E:/SIM	

			}
				
			IP_CORE:{

			E:\IP_CORE	

			}
				
			Mentor_Path:{E:/modelsim_prj}

		and	directory like this:

			E:\RTL\.

				   module_A\

							rtl_file

				   module_B\

							rtl_file

		 2、Run MentorSbuid.rb .	if you work	in MS, just	double chick

			It will	create 4 files in dir of project of	Mentor

			compile_all.do

			compile_modified.do

			compile_all.bat

			compile_modified.bat

		 3、show	time 

			 do		compile_all.do		#if	you	want compile all 

			 do		compile_modified.do	#if	you	want complie few files that	have be	modified


还有一些功能我还想加入，以后会慢慢完善。

It will	be better. But development would spend many	time. I	try	my best.
	
Good 4 U 

--@--Young--@--

