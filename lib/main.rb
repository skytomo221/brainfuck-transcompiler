# frozen_string_literal: true

require 'brainfuck_transcompiler'

bt = BrainfuckTranscompiler::Translator.new
bt.read('./sample/mandelbrot.bf').translate
puts 'π ζι©εε'
puts bt.to_c
File.write('a.c', bt.to_c)
bt.compression
puts 'π ζι©εεΎ'
puts bt.to_c
File.write('b.c', bt.to_c)
