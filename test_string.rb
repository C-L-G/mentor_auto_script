
class String
    alias_method :old_new ,:new
    attr_reader :dirname

    def new_new(&args)
        old_new(&args)
        if File.exist?(self) && File.file?(self)
            @dirname = File::dirname self
        else
            @dirname = ''
        end
    end

    alias_method :new,:new_new
end

str = "/home/Young/tmp.txt"

puts str
