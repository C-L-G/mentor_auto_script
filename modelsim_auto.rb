
require "fileutils"
class HdlFile

    REP_TB_0 = /_tb\.(?:sv|v|vhd)$/i
    REP_TB_1 = /^tb_\w+\.(?:sv|v|vhd)$/i

    REP_TB = Regexp.union(REP_TB_0,REP_TB_1)

    REP_PKG_0 = /pkg\.(?:sv|vhd)$/i
    REP_PKG_1 = /^pkg\w*\.(?:sv|vhd)$/i
    REP_PKG_2 = /package\w*\.(?:sv|vhd)$/i

    REP_PKG = Regexp.union(REP_PKG_0,REP_PKG_1,REP_PKG_2)

    REP_IGNORE_0 = /_bb\.(?:sv|v|vhd)/i
    REP_IGNORE_1 = /_inst\.(?:sv|v|vhd)/i

    REP_IGNORE = Regexp.union(REP_IGNORE_0,REP_IGNORE_1)

    REP_INITL_ARRAY = ["\\.hex","\\.mif","\\.iv",'alt_mem_phy_defines\.v',"\\.vh"]
    REP_INITL = Regexp.new(REP_INITL_ARRAY.join('|'))

    attr_reader :typle,:mtime,:name,:hdl_typle,:full_name,:has_be_modified
    attr_accessor :sim_top
    @@pkg_files = []
    @@initial_files = []
    @@ignore_files = []
    @@ignore_paths = []
    @@pkg_lib = nil
    @@file_and_mtimes = []
    @@tb_tops = []
    REP_HDL = /\.(?:v|sv|hdl|vh|iv|hex|mif)$/i
    # REP_IGNORE = /(?:_bb\.(?:v|sv|hdl|vh))$/i

    def initialize(path_str)
        @full_name = path_str
        @sim_top = false
        @name = File::basename path_str
        if File.exist?(path_str) && File.file?(path_str)
            @mtime = File::mtime(path_str).to_s
            hdlfile_type
        end

        ## has be modifted
        pair = @@file_and_mtimes.assoc(@full_name)
        if pair
            unless pair[1].eql? @mtime  ## be modified
                @has_be_modified = true
                @@file_and_mtimes.delete(pair)
                @@file_and_mtimes << [@full_name,@mtime]
            else
                @has_be_modified = false
            end
        else
            @has_be_modified = true
            @@file_and_mtimes << [@full_name,@mtime]
        end

        ## @@file_and_mtimes.assoc(@full_name) = [@full_name,@mtime]
    end


    def hdlfile_type

        case @name
        when REP_TB
            @typle = :tb
        when REP_PKG
            @typle = :package
        when REP_IGNORE
            @typle = :ignore
        when REP_INITL
            @typle = :initial
        else
            @typle = :normal
        end

        case @name
        when /\.v$/i
            @hdl_typle = :verilog
        when /\.hdl$/i
            @hdl_typle = :vhdl
        when /\.sv$/i
            @hdl_typle = :systemverilog
        else
            @hdl_typle = :other
        end
    end

    def gen_do_script
        return nil unless @has_be_modified
        if @hdl_typle == :verilog || @hdl_typle == :systemverilog
            com = 'vlog'
        elsif @hdl_typle == :vhdl
            com = 'com'
        else
            return nil
        end
        if @typle != :package
            "#{com} -incr #{@full_name} #{@@pkg_lib? "-L #{@@pkg_lib}" : '' }"
        else
            "#{com} -incr #{@full_name} -work #{@@pkg_lib}"
        end
    end

    def cp_to_path(path)
        memtor_targer_item = File.join(path,name)
        if File.exist? memtor_targer_item
            if File.mtime(memtor_targer_item).to_s.eql?(@mtime)
                return
            else
                FileUtils::cp @full_name,memtor_targer_item
            end
        else
            FileUtils::cp @full_name,memtor_targer_item
        end
    end
    ## class method

    def self.hdl_file?(path_str)
        # rep_hdl = /\.(?:v|sv|hdl|vh|iv|hex|mif)$/i
        dir_path = File::dirname(path_str)
        # rep_ignore = /(?:_bb\.(?:v|sv|hdl|vh))$/i
        @@ignore_paths.each do |ip|
            if dir_path =~ ip
                return
            end
        end

        @@ignore_files.each do |ifile|
            if ifile =~ path_str
                return
            end
        end

        if REP_HDL =~ path_str && path_str !~ REP_IGNORE
            HdlFile.create(path_str)
        else
            nil
        end
    end

    def self.create(path_str)
        np = self.new(path_str)
        case np.typle
        when :package
            @@pkg_lib = 'prj_pkg'
            @@pkg_files << np
        when :initial
            @@initial_files << np
        else
            unless @@tb_tops.empty?
                if @@tb_tops.include? np.name.sub(/\.\w+$/,'')
                    np.sim_top = true
                end
            end
        end
        return np
    end

    def self.add_ignores(*str_args)
        args = str_args.map do |s|
            str_to_rep s
        end
    end

    def self.str_to_rep (str)
        rep_slop = str.gsub("\\","/")
        rep_slop = rep_slop.strip.chomp.strip

        if rep_slop[-1] == '/'
            path_file = true
        else
            path_file = false
        end

        rep_str = rep_slop.gsub(/(^\/)|(\/$)/,'')
        rep_star_str = rep_str.gsub('.','\.').gsub("*",".*").gsub("?",'\w')
        if path_file # path
            @@ignore_paths << Regexp.new(rep_star_str)
        else
            @@ignore_files << Regexp.new(rep_star_str)
        end
    end

    def self.pkg_lib
        @@pkg_lib
    end

    def self.pkg_files
        @@pkg_files
    end

    def self.mtimes
        @@file_and_mtimes
    end

    def self.gen_pkg_script
        rel = "##=============packages==================\n"
        rel += "## pkg_file: #{@@pkg_files.length} \n"
        rel += "##---------------------------------------\n"

        @@pkg_files.each do |pf|
            rel += pf.gen_do_script
        end
    end

    def self.mv_initial_files_to(path)
        @@initial_files.each { |inf| inf.cp_to_path(path) }
    end

    def self.read_mtimes(mfile)
        rep = /(?<path>\S+)\s+(?<mtime>.+)/
        files_mtime_lines = []
        file_mtime_pair = []
        if File::exist? mfile
            File.open(mfile,'r'){|f| files_mtime_lines = f.readlines}
        else
            puts "I have to create #{mfile}"
            dirname = File.dirname(mfile)
            Dir::mkdir(dirname) unless File::exist?(dirname)
            File.open(mfile,'w'){|f| f.puts ''}
        end
        files_mtime_lines.each do |l|
            mch = l.match(rep)
            if mch
                file_mtime_pair << [mch[:path],mch[:mtime].strip]
            end
        end
        @@file_and_mtimes = file_mtime_pair
        return file_mtime_pair
    end

    def self.write_mtimes(mfile)
        f = File.open(mfile,'w')
        @@file_and_mtimes.each do |pair|
            f.print pair[0]+'  '+pair[1].to_s+"\n"
        end
        f.close
    rescue
        f.close
        $LOG.puts "Can't write to file: #{mfile}"
    end

    def self.add_tb_top(*args)
        @@tb_tops.concat args
    end

end

class ModulesCollectPath
    attr_reader :root_path,:modules,:root_hdl_files

    def initialize(path_str)
        unless File::exist?(path_str) || File::directory?(path_str)
            puts "Faile path #{path_str}"
            return
        end
        @root_path = path_str
        dir_list = Dir::entries(path_str) - %w{. ..}
        dir_list.select! {|d| d !~ /^\./}
        dir_list.map! {|d| File::join(@root_path,d)}

        file_list = dir_list.select do |d|
            File::file? d
        end

        dir_list = dir_list - file_list

        @modules = dir_list.map {|d| ModulePath.new(d)}
        @root_hdl_files = file_list.map {|f| HdlFile.hdl_file? f }
        @root_hdl_files.compact!
    end

    def gen_do_script(re_do=false)
        rel = "\n##=============ROOT==================\n"
        rel += "## #{root_path} root_file: #{root_hdl_files.length} \n"
        rel += "##---------------------------------------\n"
        root_hdl_files.each do |rf|
            script = rf.gen_do_script
            if script
                rel += script + " -work work \n"
            end
        end
        modules.each do |m|
            rel += m.gen_do_script(re_do)
        end
        return rel
    end

end

class ModulePath
    attr_reader :root_path,:module_name,:hdl_files,:tb_hdl_files
    def initialize(path_str)
        unless File::exist?(path_str) || File::directory?(path_str)
            puts "Faile path #{path_str}"
            return
        end
        @root_path = path_str
        @module_name = File::basename(path_str)
        @hdl_files = search_files(@root_path)
    end

    def search_files(path_str)
        sub_path = path_str
        list = Dir::entries(path_str) - %w{. ..}

        list = list.select do |d|
            d !~ /^\./
        end

        list.map! do |d|
            File::join(sub_path,d)
        end

        file_list = list.select do |d|
            File::file? d
        end

        hdlfiles = file_list.map {|d| HdlFile.hdl_file?(d)}
        hdlfiles.compact!

        dir_list = list - file_list

        if dir_list==nil || dir_list.empty?
            return hdlfiles
        end
        sub_list = []
        dir_list.each do |d|
            sub_list.concat(search_files(d))
        end

        return hdlfiles.concat(sub_list)
    end


    def gen_do_script(re_do=false)
        rel = "##=============#{module_name}==================\n"
        rel += "## #{module_name} file: #{@hdl_files.length} \n"
        unless re_do
            rel += "ensure_lib		./prj_#{module_name}/\n" +
                    "vmap prj_#{module_name} ./prj_#{module_name}/\n\n"
        end

        @hdl_files.each do |hf|
            if hf.typle != :package
                hf_script = hf.gen_do_script
                if hf_script
                    unless hf.sim_top
                        rel += hf_script + " -work prj_#{module_name} \n"
                    else
                        rel += hf_script + "  \n"
                    end
                end
            end
        end
        return rel
    end

    def has_any_tb
        @tb_hdl_files = @hdl_files.select do |hf|
            hf.typle == :tb
        end
        return @tb_hdl_files
    end

    # def gen_tb_top_for_sim(*args)
    #     args.each do |a|
    #         @hdl_files.each do |hf|
    #             hf.sim_top
end


class GenDo
    attr_accessor :company,:product,:language

    def initialize(*path_args)

        @paths = path_args.select do |pp|
            File::exist?(pp) && File.directory?(pp)
        end

        @root_paths = []

        @paths.each do |pp|
            @root_paths << ModulesCollectPath.new(pp)
        end
        @root_paths.compact!
        @company = nil
        @product = nil
        @language = 'verilog'
    end

    def company=(str)
        @company = str.downcase if str
    end

    def product=(str)
        @product = str.downcase if str
    end

    def language=(str)
        @language = str.downcase if str
    end

    private

    def head_sign
        rel =
        "## +++++++++++++++++++++++++\n"+
        "## #{Time.new} \n" +
        "## +++++++++++++++++++++++++\n" +
        "proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }\n"
    end


    def gen_lib_script # just for run sim
        rel = "#{(HdlFile.pkg_lib)? "-L #{HdlFile.pkg_lib}" : '' } "
        @root_paths.map do |rp|
            rp.modules.map {|subm| rel += ' -L prj_'+subm.module_name+' ' }
        end
        return rel
    end

    def gen_pkg_script
        pkg_files = HdlFile.pkg_files
        rel = "##=============packages==================\n"
        rel += "## pkg_file: #{pkg_files.length} \n"
        rel += "ensure_lib		./prj_pkg/\nvmap prj_pkg ./prj_pkg/\n"

        pkg_files.each do |pf|
            rel += pf.gen_do_script.to_s
        end
        return rel+"\n"
    end

    def gen_company_lib_script # just for run sim
        libs = []
        if @company == 'altera'
            libs = %w{220model altera_lnsim  altera_mf  altera}

            case @product
            when /cyclone\s*iv\s*e/
                libs.concat %w{cycloneive cycloneiii}
            when /strix\s*iv/
                libs.concat %w{strixive }
            else
                libs
            end

            if @language == 'verilog'
                libs.map! {|l| l+'_ver'}
            end

        elsif @company == 'xilinx'

            if @language == 'verilog'
                libs = %w{secureip unisims_ver unimacro_ver unifast_ver simprims_ver }
            elsif @language == 'vhdl'
                libs = %w{secureip unisims unimacro unifast  }
            end
        end
        if libs.empty?
            return ""
        else
            return ' -L '+libs.join(" -L ")
        end
    end

    def run_sim_script(*tb_modules)
        hrel = "\n##==========================\n"
        hrel += "###   vsim script\n"
        rel = ''
        # tb_modules.each do |tbm|
        #     @root_paths.each do |rp|
        #         rp.modules.each do |subm|
        #             tb_names = subm.has_any_tb().map{|hf| hf.name.sub(/\.\w+?$/,'') }
        #             if tb_names.include? tbm
        #                 rel += " prj_#{subm.module_name}.#{tbm} "
        #             end
        #         end
        #
        #         tb_names = rp.root_hdl_files.map {|hf| hf.name.sub(/\.\w+?$/,'') }
        #         if tb_names.include? tbm
        #             rel += " work.#{tbm} "
        #         end
        #     end
        # end

        tb_modules.each do |tbm|
            rel += " work.#{tbm} "
        end

        hrel + "vsim #{gen_lib_script} #{gen_company_lib_script} -novopt #{rel}"

    end

    public

    def gen_complie_script(re_do=false)
        rel = head_sign
        rel += gen_pkg_script
        @root_paths.each do |rp|
            rel += rp.gen_do_script(re_do)
        end
        return rel
    end

    def mix_in_sim_script(*tb_modules)
        rel = gen_complie_script
        rel += run_sim_script(*tb_modules)
        return rel
    end


end

class ParseConf
    attr_reader :code_paths,:modelsim_path,:conf_name,:ignore_items,:sim_modules,:target_do_path,:company,:language,:product
    def initialize(path_str)
        if File::exist?(path_str) && File::file?(path_str)

        else
            return nil
        end
        all_str = nil
        File.open(path_str) {|f| all_str = f.read.gsub(/#.+\n/,"\n") }
        parse_prj_conf(all_str)
        parse_configure(all_str)
        parse_code_paths
        parse_modelsim_path
        parse_ignore
        parse_top_sim_modules
        parse_company
        parse_product
        parse_language
        @target_do_path = File.join(File.dirname(File.expand_path(__FILE__)),'/.do_files')
        Dir::mkdir @target_do_path unless File::exist? @target_do_path
    end

    private

    def parse_code_paths
        return unless @conf_block

        rep = /CODE_PATHS:{(.+?)}/m
        mch = @conf_block.match(rep)
        return nil unless mch
        path_array = mch[1].strip.split("\n")
        return def_path_array if path_array.empty?
        real_path = path_array.select do |pa|
            File::exist?(pa) && File::directory?(pa)
        end
        @code_paths =  real_path.map {|item| item.gsub("\\",'/') }
    end

    def parse_prj_conf(str)
        rep = /USE_CONFIGURE\s*:\s*(?<prj_name>\w+)/
        str.match(rep)
        if $~
            @conf_name = $1
        else
            $LOG.puts "Can't Find >'USE_CONFIGURE:XXXXX' in cong file"
        end
    end

    def parse_configure(all_str)
        rep = Regexp.new("CONF\\s*:\\s*#{conf_name}(.+?)ENDCONF\\s*:\\s*#{conf_name}",Regexp::MULTILINE)
        all_str.match(rep)
        $LOG.unexpect($~,"Can't get configure : #{conf_name}")
        @conf_block =  $1
    end

    def parse_modelsim_path
        return unless @conf_block

        rep = /Modelsim_PATH\s*:\s*(.+)/
        @conf_block.match(rep)
        $LOG.unexpect($~,"Can't get Modelsim_PATH : #{@conf_block}")
        if $~
            path = $1.strip
            $LOG.unexpect(File::exist?(path) && File::directory?(path),"Modelsim_PATH : #{path} is error !!!")
            @modelsim_path = path.gsub("\\",'/')
        end
    end

    def parse_ignore
        return unless @conf_block

        rep = /IGNORE\s*:\s*{(.+?)}/m
        @conf_block.match(rep)
        if $~
            str_lines = $1.strip.split("\n").map{|item| item.strip.gsub("\\",'/')}
            @ignore_items = str_lines
        end
    end

    def parse_top_sim_modules
        return unless @conf_block

        rep = /SIM_TOP_MODULES\s*:\s*{(.+?)}/m
        @conf_block.match(rep)
        if $~
            str_lines = $1.strip.split("\n").map{|item| item.strip.gsub("\\",'/')}
            @sim_modules = str_lines
        end
    end

    def self.define_parse_method(name,&block)
        define_method name do
            return unless @conf_block
            yield
        end
        private name
    end

    def parse_company
        rep = /COMPANY\s*:\s*(\w+)/
        @conf_block.match(rep)
        if $~
            str = $1.strip
            @company = str
        end
    end

    def parse_language
        rep = /LANGUAGE\s*:\s*(\w+)/
        @conf_block.match(rep)
        if $~
            str = $1.strip
            @language = str
        end
    end

    def parse_product
        rep = /PRODUCT\s*:\s*(.+)/
        @conf_block.match(rep)
        if $~
            str = $1.strip
            @product = str
        end
    end


end

class ShellFile

    def initialize(conf_file)
        @pconf = ParseConf.new(conf_file)
        @mt_path = File::join(@pconf.modelsim_path,'/.mt_log/.mtimes.txt')
        HdlFile.add_ignores(*@pconf.ignore_items)
        HdlFile.read_mtimes(@mt_path)
        HdlFile.add_tb_top(*@pconf.sim_modules)
        @gd    = GenDo.new(*@pconf.code_paths)
        @gd.company = @pconf.company
        @gd.product = @pconf.product
        @gd.language = @pconf.language
        @curr_sys = nil
    end

    def gen_modelsim_do_script
        do_file = File::join(@pconf.modelsim_path,'all_run.do')
        f = File.open(do_file,'w')
        f.puts @gd.mix_in_sim_script *@pconf.sim_modules
        f.close
        # HdlFile.write_mtimes(@mt_path)
        HdlFile.mv_initial_files_to(@pconf.modelsim_path)
    rescue
        f.close
        raise
    end

    def update_mtime_file
        HdlFile.write_mtimes(@mt_path)
    end

    def create_sh_file_compile
        sh_file = gen_sh_file("compile")
        f = File.open(sh_file,'w')
        f.puts "ruby #{File.expand_path(__FILE__)} compile "
        f.close
        return sh_file
    end

    def create_sh_file_recompile
        sh_file = gen_sh_file("recompile")
        f = File.open(sh_file,'w')
        f.puts "ruby #{File.expand_path(__FILE__)} recompile "
        f.close
        return sh_file
    end

    def create_sh_file_update_mtime
        sh_file = gen_sh_file("update_mtime")
        f = File.open(sh_file,'w')
        f.puts "ruby #{File.expand_path(__FILE__)} update_mtime "
        f.close
        return sh_file
    end

    def create_compile_do_script
        file_name = File.join(@pconf.target_do_path,'compile.do')
        f = File.open(file_name,'w')
        f.puts @gd.mix_in_sim_script *@pconf.sim_modules
        f.close
        # HdlFile.write_mtimes(@mt_path)
        HdlFile.mv_initial_files_to(@pconf.modelsim_path)
        return file_name
    # rescue
    #     f.close
    #     raise
    end

    def create_recompile_do_script
        file_name = File.join(@pconf.target_do_path,'recompile.do')
        f = File.open(file_name,'w')
        f.puts @gd.gen_complie_script(re_do=true)
        f.close
        # HdlFile.write_mtimes(@mt_path)
        HdlFile.mv_initial_files_to(@pconf.modelsim_path)
        return file_name
    rescue
        f.close
        raise
    end


    def gen_sh_file(name)
        if ENV["_system_type"]
            curr_sys = ENV["_system_type"].downcase
        else
            curr_sys = 'windows'
        end

        if curr_sys == "linux"
            file_name = "#{name}.sh"
        elsif curr_sys == "windows"
            file_name = "#{name}.bat"
        else
            file_name = "#{name}.e"
        end
        file_name = File.join(@pconf.target_do_path,file_name)
    end

    def gen_do_compile
        file_name = File.join(@pconf.modelsim_path,'compile.do')
        f = File.open(file_name,'w')
        f.puts "echo #{'='*20}"
        f.puts "echo CREATED BY --@--Young--@--"
        f.puts "echo Have fun"
        f.puts "echo #{'='*20}"
        f.puts "exec #{create_sh_file_compile}"
        f.puts "do #{create_compile_do_script}"
        f.puts "exec #{create_sh_file_update_mtime}"
        f.close
    end

    def gen_do_recompile
        file_name = File.join(@pconf.modelsim_path,'recompile.do')
        f = File.open(file_name,'w')
        f.puts "echo #{'='*20}"
        f.puts "echo CREATED BY --@--Young--@--"
        f.puts "echo Have fun"
        f.puts "echo #{'='*20}"
        f.puts "exec #{create_sh_file_recompile}"
        f.puts "do #{create_recompile_do_script}"
        f.puts "exec #{create_sh_file_update_mtime}"
        f.close
    end

    def gen_do_test
        file_name = File.join(@pconf.modelsim_path,'test.do')
        f = File.open(file_name,'w')
        f.puts "echo #{'='*20}"
        f.puts "echo CREATED BY --@--Young--@--"
        f.puts "echo Have fun"
        f.puts "echo #{'='*20}"
        #f.puts "exec #{create_sh_file_recompile}"
        f.close
    end



    def self.update_mtime_file(conf_file)
        pconf = ParseConf.new(conf_file)
        mt_path = File::join(pconf.modelsim_path,'/.mt_log/.mtimes.txt')
        HdlFile.read_mtimes(mt_path)
        HdlFile.add_ignores(*pconf.ignore_items)
        #HdlFile.read_mtimes(@mt_path)
        pconf.code_paths.each {|pp| ModulesCollectPath.new(pp) }
        HdlFile.write_mtimes(mt_path)
    end


end

### test ###

class TestHdlFile

    def test_hdl_paths
        root_path_str = "/home/young/work/ruby/"

        mcp = ModulesCollectPath.new(root_path_str)
        puts mcp.root_path
        mcp.modules.each do |m|
            puts m.module_name
            m.hdl_files.each do |f|
                print f.typle.to_s+" -->> "
                puts f.name
            end
        end
        puts "======root files ======="
        mcp.root_hdl_files.each do |f|ignore_items
            print f.typle.to_s+" -->> "
            puts f.name
        end
    end

    def test_gen_do_script
        rel = ''
        gd = GenDo.new("E:/work/newboard_sensor_ISP_1113/rtl")
        rel += gd.mix_in_sim_script "image_file_package_tb"
    end

    def test_parse_conf
        pc = ParseConf.new('auto_conf')
        puts "====current configure===="
        puts pc.conf_name
        puts "==== code paths ========="
        puts pc.code_paths
        puts "==== modelsim path ======"
        puts pc.modelsim_path
        puts "==== ignore ============="
        puts pc.ignore_items
    end

    def test_mtimes
        root_path_str = "/home/young/work/ruby/file-class-package"
        mcp = ModulesCollectPath.new(root_path_str)
        puts "=====MTIMES====="
        HdlFile.write_mtimes("mtime.txt")
    end

    def test_gen_modelsim_do
        ShellFile.new('auto_conf').gen_modelsim_do_script
    end

    def test_update_mtime_file
        ShellFile.test_update_mtime_file('auto_conf')
    end

    def test_gen_do_compile
        ShellFile.new('auto_conf').gen_do_compile
        ShellFile.new('auto_conf').gen_do_recompile
    end
end



# nt = TestHdlFile.new

# puts HdlFile.hdl_file?("D:/Documents/GitHub/cordic/cordic/sin-cos/sin_cos_tb.sv")
# File.open('log.txt','w') do |f|
#     f.puts nt.test_gen_do_script
# end

# nt.test_parse_conf
# nt.test_mtimes
# nt.test_gen_modelsim_do

# nt.test_gen_do_compile

#### RUN SCRIPT #######
spath = File::dirname(File::expand_path(__FILE__))
$: << spath
$conf_file = File.join(spath,'auto_conf')

$LOG = File.open(File.join(spath,'log.txt'),'w')
$LOG.puts "========#{Time.new}========="
END {
    $LOG.close
}

def $LOG.unexpect(cond,str)
    unless cond
        $LOG.puts str
    end
end

if ARGV.empty?
    sf = ShellFile.new($conf_file)
    sf.gen_do_compile        #generate memtor_path:{compile.do} .do_files_path:{compile.do complie.sh update_mtime.sh}
    sf.gen_do_recompile      #generate memtor_path:{recompile.do} .do_files_path:{recompile.do recomplie.sh update_mtime.sh}
    # sf.gen_do_test
elsif ARGV[0] == "compile"
    $LOG.puts "run compile"
    sf = ShellFile.new($conf_file)
    sf.create_compile_do_script #generate .do_files_path:{compile.do}
    #sf.update_mtime_file
elsif ARGV[0] == "recompile"
    $LOG.puts "run recompile"
    sf = ShellFile.new($conf_file)
    sf.create_recompile_do_script #generate .do_files_path:{recompile.do}
    #sf.update_mtime_file
elsif ARGV[0] == "update_mtime"
    $LOG.puts "run update_mtime"
    ShellFile.update_mtime_file $conf_file
end
