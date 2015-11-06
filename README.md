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

	MentorSbuild.rb	关键脚本

	path_conf  路径配置脚本

	MentorSbuild.rb	KEY, Mentor	Script Builder

	path_conf  configure for environment


使用说明:

	1、配置path_conf 文件，分别是RTL代码路径，SIM代码路径，IP_CORE代码路径，modelsim工程路径,每一行就是一个完整的路径

	   支持 正斜杠和反斜杠，也就是说 win 和 UNIX的 路径方式都是可以的

	   不可用’space‘ 分号，分隔。

	   例如：
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

