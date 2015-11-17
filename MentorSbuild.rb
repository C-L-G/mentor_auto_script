###--@--Young--@--###
require "fileutils"
class MentorSbuild

    attr_reader :rtl_work_paths,:sim_work_paths,:ip_work_path,:rtl_module_files,:mentor_work_path,:ignore_files,:ignore_both,:ignore_directory

    def initialize (work_script_path=__FILE__)
        scriptpath=File::dirname(File::expand_path(work_script_path))
        curr_path=Dir::entries(scriptpath)-%w{.. . .git}
        @curr_script_path   = scriptpath
        def_rtl_work_path = File::join(File::dirname(scriptpath),'rtl')
        def_sim_work_path =  File::join(File::dirname(scriptpath),'sim')
        def_ip_work_path =  File::join(File::dirname(scriptpath),'ip_core')
        if curr_path.include? 'path_conf'
            File::open(File::join(scriptpath,'path_conf')) do |f|
                allword=f.read
                @rtl_work_paths = gen_work_paths(allword,/RTL:{(.+?)}/m,[def_rtl_work_path])
                @sim_work_paths = gen_work_paths(allword,/SIM:{(.+?)}/m,[def_sim_work_path])
                @ip_work_paths = gen_work_paths(allword,/IP_CORE:{(.+?)}/m,[def_ip_work_path])
                @mentor_work_path = gen_work_paths(allword,/Mentor_Path:{(.+?)}/m,[]).first
                gen_ignore_list allword,/ignore:{(.+?)}/m
            end
        else
            @rtl_work_paths = [def_rtl_work_path]
            @sim_work_paths = [def_sim_work_path]
            @ip_work_paths = [def_ip_work_path]
            def_mentor_work_path = Dir::entries(File::join(File::dirname(scriptpath),'mentor'))-%w{. ..}
            def_mentor_work_path = File::join(File::dirname(scriptpath),'mentor',def_mentor_work_path)
            @mentor_work_path = def_mentor_work_path
            gen_ignore_list nil,nil
        end
    end

    private #### PRIVATE MOTHOD

    def gen_work_paths(str,rep,def_path_array=[])
        md = rep.match str
        return def_path_array unless md
        path_array = md[1].strip.split("\n")
        return def_path_array if path_array.empty?
        real_path = path_array.select do |pa|
            File::exist?(pa) && File::directory?(pa)
        end
        if real_path.empty?
            return def_path_array
        else
            return real_path.uniq.map {|item| File::expand_path item}
        end
    end

    def gen_ignore_list(str,rep)
        md = rep.match str
        return nil unless md
        rep_str_list = md[1].chomp.strip.split("\n")
        file_str_list = rep_str_list.select {|item| /(^\/)|(^\\)/ =~ item}
        dire_str_list = rep_str_list.select {|item| /(\/$)|(\\$)/ =~ item}
        both_str_list = (rep_str_list - file_str_list) - dire_str_list
        @ignore_files = file_str_list.map {|item| str_to_rep item }
        @ignore_directory = dire_str_list.map {|item| str_to_rep item }
        @ignore_both = both_str_list.map {|item| str_to_rep item }
    end

    def str_to_rep (str)
        rep_slop = str.gsub("\\","/")
        rep_str = rep_slop.gsub(/(^\/)|(\/$)/,'').strip.chomp.strip
        rep_str = rep_str.gsub(".",'\.')
        rep_star_str = rep_str.gsub("*",".*").gsub("?",'\w')
        Regexp.new(rep_star_str)
    end



    def collect_path path,ptype,rep=/.+/,rep_filter=nil,block
        #return nil unless File::directory?(path)
        dir_c = []
        dir_list = Dir.entries(path)-%w{. .. .git}
        dir_list.each do |dir|
            type = File::ftype(File::join(path,dir))
            next if (type == "file" && rep !~ dir) || /^\./ =~ dir || dir =~ rep_filter
            dir_path = File::join(path,dir)
            return [] unless (@ignore_both.select {|item| item =~ dir_path}).empty?
            case type
            when 'file'
                return [] unless (@ignore_files.select {|item| item =~ dir_path}).empty?
                if  ptype == "file"
                    if block
                        #p  "BLOCK:#{block.call dir_path}"
                        dir_c   << dir_path if block.call dir_path
                        #p dir_path
                    else
                        dir_c   << dir_path
                    end
                end
            when 'directory'
                return [] unless (@ignore_directory.select {|item| item =~ dir_path}).empty?
                if ptype ==  "directory"
                    if block
                        dir_c   << dir_path if block.call dir_path
                    else
                        dir_c   << dir_path
                    end
                end
                dir_c   = dir_c | collect_path(dir_path,ptype,rep,rep_filter,block)
            else
                []
            end
        end
        dir_c
    end

    def module_and_files (paths,rep_filter=nil,block)
        module_and_files = []
        paths.each do |rp|
            rp_array = Dir.entries(rp) - %w(. .. .git)
            rp_array.reject! do |item|
                fp = File::join(rp,item)
                if File::file? fp
                    ifs = @ignore_files.select {|ig| ig =~ fp}
                    next true unless ifs.empty?
                elsif File::directory? fp
                    ids = @ignore_directory.select {|ig| ig =~ fp}
                    next true unless ids.empty?
                end
                ibs = @ignore_both.select{|ig| ig =~ fp}
                if ibs.empty?
                    next nil
                else
                    next true
                end
            end
            rp_array.each do |ra|
                dir_ra = File::join(rp,ra)
                next unless File::directory? dir_ra
                rp_paths = collect_path(dir_ra,'file',/\.(?i:(v|vhd|sv))$/,rep_filter,block)
                #p "#{ra}>>>>><<<<#{rep_filter}"
                #p "--->#{rep_filter}"
                module_and_files << [ra,rp_paths] unless rp_paths.empty?
            end
        end
        return module_and_files
    end

    def module_all_files(fname,updata_modufied_time=false,work_paths,rep_filter)
        if updata_modufied_time
            pf = File::open(fname,'w',0666)
            pblock = proc_file_mtime(pf)
        else
            pblock = nil
        end
        _module_all_files = module_and_files work_paths,rep_filter,pblock
        pf.close if updata_modufied_time
        #p "ppp #{work_paths} #{rep_filter}"
        return _module_all_files
    end

    def module_modified_files(fname,updata_modufied_time=false,work_paths,rep_filter)
        files_mtime_lines = []
        File::open(fname,'r'){|f| files_mtime_lines=f.readlines}
        #p rep_filter
        collect_module_modified_files = module_and_files work_paths,rep_filter,proc_mt_cmp(files_mtime_lines)
        #p collect_module_modified_files
        file_mt_ref(fname,files_mtime_lines,collect_module_modified_files) if updata_modufied_time
        return collect_module_modified_files
    end
    public
    def rtl_module_files(files_method,updata_modufied_time)
        files_method.call File::join(@curr_script_path,'.rtl_files_mtime.txt'),updata_modufied_time,@rtl_work_paths,/((_bb\.)|(tb_.+\.(v|sv)$)|(_tb\.(v|sv)$))/
    end

    def rtl_module_all_files(updata_modufied_time=false)
        @rtl_module_all_files = rtl_module_files(method(:module_all_files),updata_modufied_time)
    end

    def rtl_module_modified_files(updata_modufied_time=false)
        @rtl_module_modified_files = rtl_module_files(method(:module_modified_files),updata_modufied_time)
    end

    def sim_module_files(files_method,updata_modufied_time)
        files_method.call File::join(@curr_script_path,'.sim_files_mtime.txt'),updata_modufied_time,@sim_work_paths,nil
    end

    def sim_module_all_files(updata_modufied_time=false)
        @sim_module_all_files = sim_module_files(method(:module_all_files),updata_modufied_time)
    end

    def sim_module_modified_files(updata_modufied_time=false)
        @sim_module_modified_files=sim_module_files(method(:module_modified_files),updata_modufied_time)
    end

    def ip_module_files(files_method,updata_modufied_time)
        files_method.call File::join(@curr_script_path,'.ip_files_mtime.txt'),updata_modufied_time,@ip_work_paths,/(_bb\.)|(_inst\.)/
    end

    def ip_module_all_files(updata_modufied_time=false)
        @ip_module_all_files = ip_module_files(method(:module_all_files),updata_modufied_time)
    end

    def ip_module_modified_files(updata_modufied_time=false)
        @ip_module_modified_files = ip_module_files(method(:module_modified_files),updata_modufied_time)
    end

    def proc_file_mtime (of)
        return lambda do |f_path|
            of.puts "#{f_path} #{File::mtime(f_path)}"
            return true
        end
    end

    def proc_mt_cmp(tlines)
        return lambda do |f_path|
            mt = File::mtime(f_path).to_s
            f_rep = Regexp.new(f_path+"\s+(.+)\s*")
            rel = nil      #default: File has not be modified, It must not be collected
            choise_line =  tlines.reject{|item| item !~ f_rep}.pop
            if choise_line
                f_rep =~ choise_line
                if $1==mt # File has not be modified, It must not be collected
                    rel = nil
                else
                    rel = true
                end
            else
                rel = true  # File is new It must be collected
            end
            #p rel
            return rel
        end
    end

    def file_mt_ref(wfile,tlines,mfiles)
        old_lines = tlines
        #fmf =  Array.new(mfiles)
        fmf =mfiles.collect do |item|
            item.select  {|sitem| sitem.is_a?(Array)}
        end
        fmf = fmf.flatten
        #p old_lines
        fmf.each do |mitem|
            f_rep = Regexp.new(mitem)
            old_lines = old_lines.delete_if do |each_line|
                each_line =~ f_rep
            end
        end
        new_lines = fmf.map do |item|
            "#{item} #{File::mtime(item)}"
        end
        #p "OLD:#{old_lines}"
        #p "NEW:#{new_lines}"
        File::open(wfile,'w',0666) do |wf|
            (old_lines|new_lines).each do |item|
                wf.puts item
            end
        end
    end

## gen tcl ##

    def gen_tcl_head(name,number,atype,lib_path)
        return "
        ## module #{name}
        ## #{number} #{ if number == 1
                            'file'
                        else
                            'files'
                        end}
        ## +++++++++++++++++++++++++
        ## #{Time.new}
        ##=====================================
        proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }
        ensure_lib		./#{lib_path}/
        vmap #{lib_path} ./#{lib_path}/
        "
    end

    def gen_file_do(file_path,lib_path)
        verilog_rep = /\w+\.(v|sv)$/i
        vhdl_reg = /\w+\.vhd$/i
        if file_path =~ verilog_rep
            com = 'vlog'
        elsif file_path =~ vhdl_reg
            com = 'vcom'
        else
            com = nil
        end
        if com
            return "#{com} #{file_path} -work #{lib_path}"
        else
            return nil
        end
    end

    def gen_module_tcl(targer_path,module_and_files_array,atype=:rtl,filter_director=:if,&filter_block)
        Dir::mkdir(targer_path,0666) unless File::exist? targer_path
        module_do_array = []
        module_and_files_array.each do |mfa|
            module_name = mfa.first
            if filter_block
                rel = yield(module_name)
                if filter_director == :if
                    next unless rel
                else filter_director == :not
                    next if rel
                end
            end
            module_path = File::join(targer_path,module_name)
            lib_path = "prj_#{atype}_#{module_name}"
            collect_str = ''
            Dir::mkdir(module_path,0666) unless Dir::exist? module_path
            pkg_mfa = mfa[1].select{|item| /(?-i:pkg)|package/ =~ File::basename(item)}
            pkg_mfa.each do |file_path_item|
                collect_str = collect_str + "\n" + gen_file_do(file_path_item,lib_path)
            end
            (mfa[1]-pkg_mfa).each do |file_path_item|
                collect_str = collect_str + "\n" + gen_file_do(file_path_item,lib_path)
            end
            next if collect_str == ''
            collect_str = gen_tcl_head(module_name,mfa[1].size,atype,lib_path) + "\n" + collect_str
            curr_module_do_path = File::join(module_path,"#{module_name}.do")
            File.open(curr_module_do_path,'w',0666) do |module_do_file|
                module_do_file.puts collect_str
            end
            module_do_array << [lib_path,curr_module_do_path]
        end
        return module_do_array
    end

    def gen_do(range=:all,atype=:rlt,filter_director=:not,*filter_array)

        tcl_type = chk_in(atype,:rtl,:rtl,:ip,:sim)

        script_path = File::join(@curr_script_path,tcl_type.to_s)
        File::delete_dir(script_path)
        if range==:all
            #module_and_files_array = rtl_module_all_files(true)
            module_and_files_array = send("#{tcl_type.to_s}_module_all_files",true)
        elsif range==:modified
            #module_and_files_array = rtl_module_modified_files(true)
            module_and_files_array = send("#{tcl_type.to_s}_module_modified_files",true)
            #p module_and_files_array
        else
            module_and_files_array = nil
        end
        return nil unless module_and_files_array
        return gen_module_tcl(script_path,module_and_files_array,tcl_type,filter_director) { |module_name| filter_array.include? module_name}
    end

    def gen_dos(range=:all,gen_rtl_do=true,gen_sim_do=true,gen_ip_do=true)
        rtl_modules = gen_do range,:rtl if gen_rtl_do
        sim_modules = gen_do range,:sim if gen_sim_do
        ip_modules = gen_do range,:ip if gen_ip_do
        [[:sim,sim_modules],[:ip,ip_modules],[:rtl,rtl_modules]].delete_if {|item| item[1]==nil}
    end

    def collect_for_all_paths(*args)
        rep = Regexp::new(args.join('|'))
        all_paths = @rtl_work_paths|@sim_work_paths|@ip_work_paths
        rel = []
        #p @ip_work_paths.first
        #p collect_path(@ip_work_paths.first,'file',/\.v/,nil,nil)
        all_paths.each do |path_item|
            cp = collect_path(path_item,"file",rep,nil,nil)
            rel.concat cp if cp
        end
        return rel
    end


    def chk_in(chk_value,default_value=nil,*values)
        if values.include? chk_value
            chk_value
        else
            default_value
        end
    end

    def pural obj,str
        if obj >= 2
            str+'s'
        else
            str
        end
    end

    def product_lib (company='altera',product="cyclone iv e",lang="verilog")
        company.downcase!
        product.downcase!
        lang.downcase!
        if company == 'altera'
            libs = %w{220model altera_lnsim  altera_mf  altera}
            if product =~ /cyclone\s*iv\s*e/
                libs.concat %w{cycloneive}
            end

            if lang == 'verilog'
                libs.map! {|l| l+'_ver'}
            end
        end
    end


    public

    def copy_rom_init_file_to_mentor_path
        init_files = collect_for_all_paths "\\.hex","\\.mif","\\.iv","alt_mem_phy_defines.v"
        init_files.each do |item|
            mentor_path_item = File::join(@mentor_work_path,File::basename(item))
            File::delete mentor_path_item if File::exist? mentor_path_item
            FileUtils::cp item,mentor_path_item
        end
    end

    def gen_all_do(company='altera',product="cyclone iv e",lang="verilog")

        type_modules_dofiles = gen_dos :all
        prj_lib = []
        do_str = ''
        type_modules_dofiles.each do |item|
            modules_size = item[1].size
            do_str <<  "### -->>  #{item[0].to_s.upcase} #{modules_size} #{pural(modules_size,"module")} <<----\n"
            item[1].each do |do_item|
                do_str << "do #{do_item[1]}\n"
                prj_lib<<do_item[0]
            end
        end

        prd_lib = product_lib company,product,lang
        vsim_str = "vsim -L #{[prd_lib,prj_lib].join(' -L ')} -novopt"
        File::open(File::join(@curr_script_path,'all.do'),'w',0666) do |f|
            f.puts do_str+"\n"+vsim_str
        end
        copy_rom_init_file_to_mentor_path
    end

    def gen_modified_do
        type_modules_dofiles = gen_dos :modified
        do_str = ''
        type_modules_dofiles.each do |item|
            modules_size = item[1].size
            do_str <<  "### -->>  #{item[0].to_s.upcase} #{modules_size} #{pural(modules_size,"module")} <<----\n"
            item[1].each do |do_item|
                do_str << "do #{do_item[1]}\n"
            end
        end

        File::open(File::join(@curr_script_path,'modified.do'),'w',0666) do |f|
            f.puts do_str
        end
        copy_rom_init_file_to_mentor_path
    end

    def gen_mentor_tcl type=:all
        atype = chk_in(type,:all,:all,:modified)
        do_file = File::join(@mentor_work_path,"compile_#{atype}.do")
        bat_file = File::join(@mentor_work_path,"compile_#{atype}.bat")
        ruby_file = File::join(@curr_script_path,"MentorSbuild.rb")
        ruby_do_file = File::join(@curr_script_path,"#{atype}.do")
        File::open(do_file,'w') do |f|
            f.puts "echo #{'='*20}"
            f.puts "echo CREATED BY --@--Young--@--"
            f.puts "echo Have fun"
            f.puts "echo #{'='*20}"
            f.puts "exec #{bat_file}"
            f.puts "do #{ruby_do_file}"
        end
        File::open(bat_file,'w') do |f|
            #f.puts "## BAT处理文件"
            f.puts "C:\\Ruby22-x64\\bin\\ruby #{ruby_file.gsub('/','\\')} #{atype.to_s}"
            #f.puts "ruby #{ruby_file} #{atype.to_s}".encode("US-ASCII")
        end
    end

end

def File.delete_dir path
    return nil unless File::exist? path
    if File::file? path
        File::delete path
    elsif File::directory? path
        curr_files = Dir::entries(path) - %w{. ..}
        curr_files.each do |cf|
            cf_path = File::join(path,cf)
            if File::directory? cf_path
                File.delete_dir cf_path
            else
                File::delete cf_path
            end
        end
        Dir::rmdir path
    end
end

##### RUN SCRIPT #######
$: << File::dirname(File::expand_path(__FILE__))

begin

msb = MentorSbuild.new
if ARGV.empty?
    msb.gen_mentor_tcl :all
    msb.gen_mentor_tcl :modified
#    p msb.rtl_module_all_files
#    p msb.rtl_work_paths
#    gets
#    msb.gen_all_do
#    msb.gen_modified_do
elsif ARGV[0] == 'all'
    #msb.gen_mentor_tcl :all
    msb.gen_all_do
elsif ARGV[0] == "modified"
    #msb.gen_mentor_tcl :modified
    #p msb.gen_dos(:modified)
    msb.gen_modified_do
else
    msb.gen_mentor_tcl :all
    msb.gen_mentor_tcl :modified
    #msb.gen_all_do
end
end
