

class HdlFile
    attr_reader :typle,:mtime,:name,:hdl_typle,:full_name
    @@pgk_files = []
    @@initial_files = []
    @@ignore_files = []
    @@ignore_paths = []
    @@pkg_lib = nil
    @@file_and_mtimes = []

    def initialize(path_str)
        if File.exist?(path_str) && File.file?(path_str)
            @mtime = File::mtime(path_str)
            hdlfile_type
        end
        @full_name = path_str
        @name = File::basename path_str


        if @typle == :package
            @@pkg_lib = 'prj_pgk'
            @@pgk_files << self
        end
        @@initial_files << self if @typle == :initial

        ## has be modifted
        pair = @@file_and_mtimes.assoc(@full_name)
        if pair
            if pair[1] != @mtime  ## be modified
                @has_be_modified = true
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
        rep_tb_0 = /_tb\.(?:sv|v|vhd)$/i
        rep_tb_1 = /^tb_\w+\.(?:sv|v|vhd)$/i

        rep_tb = Regexp.union(rep_tb_0,rep_tb_1)

        rep_pkg_0 = /pkg\.(?:sv|vhd)$/i
        rep_pkg_1 = /^pkg\w*\.(?:sv|vhd)$/i
        rep_pkg_2 = /package\w*\.(?:sv|vhd)$/i

        rep_pkg = Regexp.union(rep_pkg_0,rep_pkg_1,rep_pkg_2)

        rep_ignore_0 = /_bb\.(?:sv|v|vhd)/i
        rep_ignore_1 = /_inst\.(?:sv|v|vhd)/i

        rep_ignore = Regexp.union(rep_ignore_0,rep_ignore_1)

        rep_initl_array = ["\\.hex","\\.mif","\\.iv",'alt_mem_phy_defines\.v']
        rep_initl = Regexp.new(rep_initl_array.join('|'))

        case @name
        when rep_tb
            @typle = :tb
        when rep_pkg
            @typle = :package
        when rep_ignore
            @typle = :ignore
        when rep_initl
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

    def self.hdl_file?(path_str)
        rep_hdl = /\.(?:v|sv|hdl|vh|iv|hex|mif)$/i
        dir_path = File::dirname(path_str)

        @@ignore_paths.each do |ip|
            if dir_path ~= ip
                return
            end
        end

        @@ignore_files.each do |ifile|
            if ifile ~= path_str
                return
            end
        end

        if rep_hdl =~ path_str
            HdlFile.new(path_str)
        else
            nil
        end
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

    def self.prj_pgk
        @@prj_pgk
    end

    def gen_do_script
        return '' unless @has_be_modified
        if @hdl_typle == :verilog || @hdl_typle == :systemverilog
            com = 'vlog'
        elsif @hdl_typle == :vhdl
            com = 'com'
        else
            return ''
        end

        if @typle != :package
            "#{com} -incr #{@full_name} #{@@pkg_lib? "-L #{@@pkg_lib}" : '' }"
        else
            "#{com} -incr #{@full_name} -work #{@@pkg_lib}"
        end
    end

    def self.gen_pkg_script
        rel = "##=============packages==================\n"
        rel += "## pkg_file: #{@@pkg_files.length} \n"

        @@pgk_files.each do |pf|
            rel += pf.gen_do_script
        end
    end

    def self.read_mtimes(mfile)
        rep = /(?<path>\S+)\s+(?<mtime>\S+)/
        files_mtime_lines = []
        file_mtime_pair = []
        if File::exist? mfile
            File.open(mfile,'r'){|f| files_mtime_lines.readlines}
        else
            File.open(mfile,'w'){|f| f.puts ''}
        end
        files_mtime_lines.each do |l|
            mch = l.match(rep)
            if mch
                file_mtime_pair << [mch[:path],mch[mtime]]
            end
        end
        @@file_and_mtimes = file_mtime_pair
        return file_mtime_pair
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

    def gen_do_script
        rel = "##=============ROOT==================\n"
        rel += "## #{module_name} root_file: #{@hdl_files.length} \n"
        root_hdl_files.each do |rf|
            rel += rf.gen_do_script + " -work work \n"
        end
        modules.each do |m|
            rel += m.gen_do_script
        end
        return rel
    end

end

class ModulePath
    attr_reader :root_path,:module_name,:hdl_files
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

    def hdl_file?(path_str)
        rep_hdl = /\.(?:v|sv|hdl|vh|iv|hex|mif)$/i
        if rep_hdl =~ path_str
            HdlFile.new(path_str)
        else
            nil
        end
    end

    def gen_do_script
        rel = "##===============================\n"
        rel += "## #{module_name} file: #{@hdl_files.length} \n"
        rel += "proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }
                ensure_lib		./prj_#{module_name}/
                vmap prj_#{module_name} ./prj_#{module_name}/
        "
        @hdl_files.each do |hf|
            rel += hf.gen_do_script + " -work prj_#{module_name} \n"
        end
        return rel
    end

end


class GenDo

    def initialize(*path_args)

        @paths = path_args.select do |pp|
            File::exist?(pp) && File.directory?(pp)
        end

        @root_paths = []

        @paths.each do |pp|
            ModulesCollectPath.new(pp)
            @root_paths.concat ModulesCollectPath.new(pp)
        end
    end

    def gen_do_script
        rel = "
               ## +++++++++++++++++++++++++
               ## #{Time.new}
               ## +++++++++++++++++++++++++"
        @root_paths.each do |rp|
            rel += rp.gen_do_script
        end
        return rel
    end

    def gen_lib_script
        rel = "#{HdlFile.pkg_lib? "-L #{HdlFile.pkg_lib}" : '' } "
        @root_paths.map do |rp|
            rp.modules.map {|subm| rel += '-L prj_'+subm.module_name }
        end
        return rel
    end

    def gen_company_script(company='altera')
        cmp = company.downcase
        libs = %w{220model altera_lnsim  altera_mf  altera}


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
        mcp.root_hdl_files.each do |f|
            print f.typle.to_s+" -->> "
            puts f.name
        end
    end
end
